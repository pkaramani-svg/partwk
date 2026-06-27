import os
import sys
import time
import base64
import wave
import json
import urllib.request
import urllib.parse
import argparse
import re
import socket

# Set default timeout for all network sockets to prevent hanging indefinitely
socket.setdefaulttimeout(60.0)

# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dynamic_summary_pipeline import (
    load_env_file,
    get_firestore_document,
    set_firestore_document,
    upload_file_to_storage,
    chunk_text,
    from_firestore_doc,
    FIREBASE_PROJECT_ID,
    FIREBASE_BUCKET,
    GeminiClientManager
)

# Load env variables (contains GEMINI_API_KEY)
load_env_file()

# Import google-genai
try:
    from google import genai
    from google.genai import types
except ImportError:
    print("[!] Error: The 'google-genai' SDK is not installed.")
    print("    Please install it by running: pip install google-genai\n")
    sys.exit(1)

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

def main():
    parser = argparse.ArgumentParser(description="Regenerate audio narration and exact paragraph timestamps (segments) for books in Firestore.")
    parser.add_argument("--book_id", default=None, help="Firestore Book Document ID (e.g. deep_work). If 'all', processes all books.")
    parser.add_argument("--lang", default=None, help="Language code (en or ar or ku or all)")
    parser.add_argument("--voice_en", default="Charon", help="Narrator voice for English (default: Charon)")
    parser.add_argument("--voice_ar", default="Kore", help="Narrator voice for Arabic (default: Kore)")
    parser.add_argument("--voice_ku", default="Zephyr", help="Narrator voice for Kurdish (default: Zephyr)")
    
    args = parser.parse_args()
    
    book_id = args.book_id
    if not book_id:
        book_id = input("Enter Book Document ID (or 'all' for all books) [default: all]: ").strip() or "all"
        
    lang_code = args.lang
    if not lang_code:
        lang_code = input("Enter Language (en, ar, or 'all') [default: all]: ").strip().lower() or "all"

    # Initialize client manager with API key rotation support
    client = GeminiClientManager()

    # Determine books to process
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

    # Create temp directory for local audio
    local_audio_dir = "temp_pipeline_audio"
    os.makedirs(local_audio_dir, exist_ok=True)
    
    timestamp = int(time.time())

    for book_idx, book in enumerate(books_to_process, 1):
        b_id = book["id"]
        b_title = book.get("title", {}).get("en") or book.get("title", {}).get("ar") or "Untitled"
        print(f"\n=======================================================")
        print(f"[*] Processing Book {book_idx}/{len(books_to_process)}: '{b_title}' (ID: {b_id})")
        print(f"=======================================================")

        # Languages to process
        langs = ["en", "ar", "ku"] if lang_code == "all" else [lang_code]
        chapter_summaries = book.get("chapterSummaries", {})
        
        doc_changed = False

        for lang in langs:
            if lang not in chapter_summaries:
                print(f"[-] Language '{lang}' not found in chapterSummaries. Skipping.")
                continue

            chapters = chapter_summaries[lang]
            if lang == "ar":
                voice_name = args.voice_ar
                tts_lang_code = "ar-XA"
            elif lang == "ku":
                voice_name = args.voice_ku
                tts_lang_code = "ckb-IQ"
            else:
                voice_name = args.voice_en
                tts_lang_code = "en-US"
            
            print(f"\n  [*] Narrating '{lang}' translation using voice '{voice_name}' ({len(chapters)} chapters)...")
            
            tts_config = types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=types.SpeechConfig(
                    language_code=tts_lang_code,
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name=voice_name
                        )
                    )
                )
            )
            
            # Preferred models list
            tts_models_list = ["gemini-2.5-flash-preview-tts", "gemini-2.5-pro-preview-tts"]
            
            for c_idx, chap in enumerate(chapters):
                title = chap.get("title", f"Chapter {c_idx + 1}")
                content = chap.get("content", "").strip()
                
                if not content:
                    print(f"    [!] Chapter {c_idx} has no content. Skipping audio.")
                    continue

                # Prepare paragraphs
                paragraphs_list = [p.strip() for p in re.split(r'\r?\n\r?\n', content) if p.strip()]
                if not paragraphs_list:
                    paragraphs_list = [p.strip() for p in content.split("\n") if p.strip()]

                # Skip if segments already exist and match paragraphs count
                if chap.get("segments") and len(chap["segments"]) == len(paragraphs_list):
                    print(f"    [-] Chapter {c_idx} '{title}' already has exact timestamps. Skipping.")
                    continue

                print(f"    [*] Chapter {c_idx} '{title}': splits into {len(paragraphs_list)} paragraphs.")
                
                chapter_audio_bytes = b""
                chunk_success = True
                segments = []
                current_time = 0.0

                for p_idx, paragraph in enumerate(paragraphs_list):
                    print(f"      Paragraph {p_idx + 1}/{len(paragraphs_list)} ({len(paragraph)} characters)...")
                    p_chunks = chunk_text(paragraph, max_chars=800)
                    p_audio_bytes = b""
                    p_success = True

                    for chunk_idx, chunk in enumerate(p_chunks, 1):
                        audio_bytes = None
                        max_retries = 3
                        retry_delay = 3
                        
                        for attempt in range(1, max_retries + 1):
                            model_to_use = tts_models_list[0]
                            try:
                                tts_resp = client.generate_content(
                                    model=model_to_use,
                                    contents=chunk,
                                    config=tts_config
                                )

                                part = tts_resp.candidates[0].content.parts[0]
                                raw_audio = part.inline_data.data
                                
                                if isinstance(raw_audio, str):
                                    chunk_bytes = base64.b64decode(raw_audio)
                                else:
                                    chunk_bytes = raw_audio
                                
                                if chunk_bytes:
                                    audio_bytes = chunk_bytes
                                    break
                            except Exception as e:
                                print(f"          [!] Attempt {attempt}/{max_retries} failed using {model_to_use}: {e}")
                                
                                err_str = str(e).lower()
                                if "429" in err_str or "quota" in err_str or "exhausted" in err_str:
                                    if model_to_use in tts_models_list:
                                        tts_models_list.remove(model_to_use)
                                        tts_models_list.append(model_to_use)
                                        print(f"          [*] Exhausted {model_to_use}. Shifted to the end of preferred list: {tts_models_list}")
                                
                                if attempt < max_retries:
                                    parsed_delay = None
                                    try:
                                        match = re.search(r"retryDelay':\s*'(\d+(?:\.\d+)?)s'", str(e))
                                        if match:
                                            parsed_delay = float(match.group(1)) + 2.0
                                    except:
                                        pass
                                    
                                    sleep_time = parsed_delay if (parsed_delay and parsed_delay <= 120) else retry_delay
                                    print(f"          [*] Rate limited. Sleeping for {sleep_time}s before retrying...")
                                    time.sleep(sleep_time)
                                    retry_delay *= 2

                        if audio_bytes:
                            p_audio_bytes += audio_bytes
                        else:
                            print(f"        [!] Failed to synthesize chunk {chunk_idx} of Paragraph {p_idx + 1}.")
                            p_success = False
                            break

                    if p_success and p_audio_bytes:
                        p_duration = len(p_audio_bytes) / 48000.0
                        start_time = current_time
                        end_time = current_time + p_duration
                        
                        segments.append({
                            "startTime": start_time,
                            "endTime": end_time,
                            "text": paragraph
                        })
                        
                        chapter_audio_bytes += p_audio_bytes
                        
                        # Add 1.5 seconds silent pause between paragraphs (except after the last one)
                        if p_idx < len(paragraphs_list) - 1:
                            silence_duration = 1.5
                            silence_bytes = b"\x00" * int(silence_duration * 48000)
                            chapter_audio_bytes += silence_bytes
                            current_time = end_time + silence_duration
                        else:
                            current_time = end_time
                    else:
                        chunk_success = False
                        break

                if chunk_success and chapter_audio_bytes:
                    try:
                        duration_sec = int(len(chapter_audio_bytes) / 48000)
                        
                        # Write local WAV file temporarily
                        local_wav_path = os.path.join(local_audio_dir, f"chap_regen_{timestamp}_{c_idx}.wav")
                        with wave.open(local_wav_path, "wb") as wav_file:
                            wav_file.setnchannels(1)
                            wav_file.setsampwidth(2)
                            wav_file.setframerate(24000)
                            wav_file.writeframes(chapter_audio_bytes)

                        # Upload to storage
                        storage_path = f"audio/chapter_{timestamp}_{c_idx}.wav"
                        print(f"    Uploading Chapter {c_idx} audio to Firebase Storage...")
                        remote_audio_url = upload_file_to_storage(local_wav_path, storage_path, "audio/wav")
                        
                        # Clean up local WAV
                        if os.path.exists(local_wav_path):
                            os.remove(local_wav_path)

                        # Update structure
                        chap["audioUrl"] = remote_audio_url
                        chap["duration"] = duration_sec
                        chap["segments"] = segments
                        
                        doc_changed = True
                        print(f"    [✓] Chapter {c_idx} audio successfully updated: {remote_audio_url} ({duration_sec}s)")
                        print(f"        Exact segments generated: {len(segments)}")
                    except Exception as fe:
                        print(f"    [!] Failed to finalize audio file for Chapter {c_idx}: {fe}")
                else:
                    print(f"    [!] Audio synthesis failed for Chapter {c_idx}. Chapter not updated.")

        if doc_changed:
            # Recalculate total duration
            default_lang = "en" if "en" in chapter_summaries else list(chapter_summaries.keys())[0]
            total_duration = sum(c.get("duration", 0) for c in chapter_summaries[default_lang])
            book["duration"] = total_duration

            # Update document in Firestore
            print(f"[*] Updating Firestore book document '{b_id}'...")
            try:
                # Remove extra 'id' field we injected
                to_save = {k: v for k, v in book.items() if k != "id"}
                set_firestore_document("books", b_id, to_save)
                print(f"[✓] Book document '{b_id}' updated successfully in Firestore!")
            except Exception as se:
                print(f"[!] Failed to save updated book document to Firestore: {se}")

    # Remove local temp directory
    try:
        if os.path.exists(local_audio_dir):
            os.rmdir(local_audio_dir)
    except:
        pass

    print("\n[✓] Audio and exact segment timestamps regeneration pipeline completed!")

if __name__ == "__main__":
    main()
