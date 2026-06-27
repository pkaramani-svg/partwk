import os
import sys
import time
import wave
import struct
import math
import re
import urllib.request
import urllib.parse
import json
import argparse
import socket

# Set default socket timeout
socket.setdefaulttimeout(60.0)

# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dynamic_summary_pipeline import (
    load_env_file,
    get_firestore_document,
    set_firestore_document,
    from_firestore_doc,
    FIREBASE_PROJECT_ID
)

# Load env variables
load_env_file()

def list_firestore_documents(collection: str) -> list:
    """Lists all documents in a collection from Firestore REST API."""
    url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/{collection}"
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
            documents = data.get("documents", [])
            results = []
            for doc in documents:
                doc_name = doc.get("name", "")
                doc_id = doc_name.split("/")[-1]
                decoded = from_firestore_doc(doc)
                decoded["id"] = doc_id
                results.append(decoded)
            return results
    except Exception as e:
        print(f"[!] Error listing collection {collection}: {e}")
        return []

def find_silent_intervals(local_path, threshold_pct, min_silence_ms, window_ms=50):
    """Parses a WAV file and returns continuous silent intervals above min_silence_ms."""
    try:
        with wave.open(local_path, "rb") as w:
            channels = w.getnchannels()
            sample_width = w.getsampwidth()
            framerate = w.getframerate()
            n_frames = w.getnframes()
            
            if channels != 1 or sample_width != 2:
                # Fallback / unsupported specs
                return []
                
            raw_data = w.readframes(n_frames)
            num_samples = len(raw_data) // 2
            samples = struct.unpack(f"<{num_samples}h", raw_data)
            
            samples_per_window = int(framerate * (window_ms / 1000.0))
            num_windows = len(samples) // samples_per_window
            
            energies = []
            for i in range(num_windows):
                start_idx = i * samples_per_window
                end_idx = start_idx + samples_per_window
                window_samples = samples[start_idx:end_idx]
                if not window_samples:
                    energies.append(0)
                else:
                    energies.append(sum(abs(s) for s in window_samples) / len(window_samples))
            
            max_energy = max(energies) if energies else 1.0
            threshold = max_energy * (threshold_pct / 100.0)
            
            is_silent = [e < threshold for e in energies]
            silent_intervals = []
            in_silence = False
            silence_start = 0
            
            for idx, silent in enumerate(is_silent):
                if silent and not in_silence:
                    in_silence = True
                    silence_start = idx
                elif not silent and in_silence:
                    in_silence = False
                    silence_end = idx
                    duration_ms = (silence_end - silence_start) * window_ms
                    if duration_ms >= min_silence_ms:
                        start_sec = (silence_start * window_ms) / 1000.0
                        end_sec = (silence_end * window_ms) / 1000.0
                        silent_intervals.append((start_sec, end_sec, duration_ms / 1000.0))
            
            if in_silence:
                silence_end = len(is_silent)
                duration_ms = (silence_end - silence_start) * window_ms
                if duration_ms >= min_silence_ms:
                    start_sec = (silence_start * window_ms) / 1000.0
                    end_sec = (silence_end * window_ms) / 1000.0
                    silent_intervals.append((start_sec, end_sec, duration_ms / 1000.0))
                    
            return silent_intervals
    except Exception as e:
        print(f"      [!] Error reading WAV file: {e}")
        return []

def align_chapter_paragraphs(content, local_path, total_duration):
    """Aligns content paragraphs with silent pauses in the WAV audio file."""
    paragraphs = [p.strip() for p in re.split(r'\r?\n\r?\n', content) if p.strip()]
    if not paragraphs:
        paragraphs = [p.strip() for p in content.split("\n") if p.strip()]
        
    N = len(paragraphs)
    if N == 0:
        return []
    if N == 1:
        return [{"startTime": 0.0, "endTime": total_duration, "text": paragraphs[0]}]
        
    # Expected break times based on character length ratio
    p_lengths = [len(p) for p in paragraphs]
    total_chars = sum(p_lengths)
    
    expected_breaks = []
    cum_chars = 0
    for idx in range(N - 1):
        cum_chars += p_lengths[idx]
        ratio = cum_chars / total_chars
        expected_breaks.append(ratio * total_duration)
        
    # Parameter grid search to find silence pauses
    intervals = []
    found_intervals = False
    
    # Try different thresholds and pause durations to find natural gaps
    for threshold_pct in [2.5, 2.0, 3.0, 1.5, 4.0]:
        intervals = find_silent_intervals(local_path, threshold_pct, min_silence_ms=300)
        if len(intervals) >= N - 1:
            found_intervals = True
            break
            
    # Proximity scoring to match expected breaks with detected pauses
    if not intervals:
        print("      [!] No silence pauses detected. Using character ratio splits.")
        midpoints = expected_breaks
    else:
        selected_midpoints = []
        for eb in expected_breaks:
            best_score = -99999.0
            best_midpoint = eb
            
            for start, end, dur in intervals:
                midpoint = (start + end) / 2.0
                score = dur - 0.15 * abs(midpoint - eb)
                if score > best_score:
                    best_score = score
                    best_midpoint = midpoint
            selected_midpoints.append(best_midpoint)
            
        selected_midpoints.sort()
        
        # Post-process to ensure chronological consistency
        sanitized_midpoints = []
        for idx, m in enumerate(selected_midpoints):
            m = max(1.0, min(m, total_duration - 1.0))
            if idx > 0 and m <= sanitized_midpoints[-1] + 2.0:
                m = sanitized_midpoints[-1] + 2.0
            sanitized_midpoints.append(m)
        midpoints = sanitized_midpoints

    # Construct segments structure
    boundaries = [0.0] + midpoints + [total_duration]
    segments = []
    for idx, p_text in enumerate(paragraphs):
        segments.append({
            "startTime": round(boundaries[idx], 2),
            "endTime": round(boundaries[idx+1], 2),
            "text": p_text
        })
    return segments

def main():
    parser = argparse.ArgumentParser(description="Align paragraph segments for existing books in Firestore.")
    parser.add_argument("--book_id", default=None, help="Firestore Book Document ID (e.g. deep_work). If 'all', processes all books.")
    parser.add_argument("--lang", default=None, help="Language code (en or ar or all)")
    args = parser.parse_args()
    
    book_id = args.book_id
    if not book_id:
        book_id = input("Enter Book Document ID (or 'all' for all books) [default: all]: ").strip() or "all"
        
    lang_code = args.lang
    if not lang_code:
        lang_code = input("Enter Language (en, ar, or 'all') [default: all]: ").strip().lower() or "all"
        
    # Fetch books to align
    books_to_process = []
    if book_id == "all":
        print("[*] Fetching all books from Firestore...")
        books_to_process = list_firestore_documents("books")
        print(f"[✓] Found {len(books_to_process)} books in the database.")
    else:
        doc = get_firestore_document("books", book_id)
        if doc:
            doc["id"] = book_id
            books_to_process = [doc]
            print(f"[✓] Found book '{book_id}' in Firestore.")
        else:
            print(f"[!] Book '{book_id}' not found.")
            sys.exit(1)
            
    if not books_to_process:
        print("[!] No books to process. Exiting.")
        sys.exit(0)
        
    local_temp_dir = "temp_alignment_audio"
    os.makedirs(local_temp_dir, exist_ok=True)
    
    for b_idx, book in enumerate(books_to_process, 1):
        b_id = book["id"]
        b_title = book.get("title", {}).get("en") or book.get("title", {}).get("ar") or "Untitled"
        print(f"\n=======================================================")
        print(f"[*] Processing Book {b_idx}/{len(books_to_process)}: '{b_title}' (ID: {b_id})")
        print(f"=======================================================")
        
        chapter_summaries = book.get("chapterSummaries", {})
        langs = ["en", "ar"] if lang_code == "all" else [lang_code]
        doc_changed = False
        
        for lang in langs:
            if lang not in chapter_summaries:
                continue
                
            chapters = chapter_summaries[lang]
            print(f"  [*] Processing language '{lang}' ({len(chapters)} chapters)...")
            
            for c_idx, chap in enumerate(chapters):
                title = chap.get("title", f"Chapter {c_idx + 1}")
                audio_url = chap.get("audioUrl", "")
                content = chap.get("content", "").strip()
                duration = float(chap.get("duration", 0))
                
                if not content:
                    print(f"    [-] Chapter {c_idx} '{title}' has no text content. Skipping.")
                    continue
                    
                if not audio_url:
                    print(f"    [-] Chapter {c_idx} '{title}' has no audio URL. Skipping.")
                    continue
                    
                print(f"    [*] Chapter {c_idx} '{title}' (Duration: {duration}s, Text len: {len(content)})...")
                
                # Check paragraphs count
                paragraphs = [p.strip() for p in re.split(r'\r?\n\r?\n', content) if p.strip()]
                if not paragraphs:
                    paragraphs = [p.strip() for p in content.split("\n") if p.strip()]
                
                # Download audio file locally
                local_path = os.path.join(local_temp_dir, f"{b_id}_{lang}_{c_idx}.wav")
                try:
                    print(f"      Downloading audio track...")
                    urllib.request.urlretrieve(audio_url, local_path)
                    
                    # Compute segments
                    segments = align_chapter_paragraphs(content, local_path, duration)
                    
                    if segments:
                        chap["segments"] = segments
                        doc_changed = True
                        print(f"      [✓] Aligned {len(segments)} segments successfully.")
                    else:
                        print(f"      [!] Failed to generate segments.")
                except Exception as e:
                    print(f"      [!] Error processing chapter {c_idx}: {e}")
                finally:
                    if os.path.exists(local_path):
                        os.remove(local_path)
                        
        if doc_changed:
            print(f"[*] Updating Firestore book document '{b_id}'...")
            try:
                # Remove extra 'id' field we injected
                to_save = {k: v for k, v in book.items() if k != "id"}
                set_firestore_document("books", b_id, to_save)
                print(f"[✓] Book document '{b_id}' updated successfully in Firestore!")
            except Exception as se:
                print(f"[!] Failed to save updated book document: {se}")
                
    # Remove local temp directory
    try:
        if os.path.exists(local_temp_dir):
            os.rmdir(local_temp_dir)
    except:
        pass
        
    print("\n[✓] Alignment pipeline completed successfully!")

if __name__ == "__main__":
    main()
