import os
import sys
import time
import base64
import wave
import json
import urllib.request
import urllib.parse
import re
import socket

socket.setdefaulttimeout(60.0)

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dynamic_summary_pipeline import (
    load_env_file,
    get_firestore_document,
    set_firestore_document,
    upload_file_to_storage,
    chunk_text,
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

def main():
    print("[*] Initializing Gemini Client for English audio regeneration of 'atomic_habits'...")
    client = GeminiClientManager()
    
    book_id = "atomic_habits"
    book = get_firestore_document("books", book_id)
    if not book:
        print(f"[!] Error: Book '{book_id}' not found in Firestore.")
        sys.exit(1)
        
    chapter_summaries = book.get("chapterSummaries", {})
    if "en" not in chapter_summaries:
        print("[!] Error: English ('en') translation not found in chapterSummaries.")
        sys.exit(1)
        
    chapters = chapter_summaries["en"]
    voice_name = "Charon"
    tts_lang_code = "en-US"
    
    print(f"[✓] Found book 'atomic_habits'. Regenerating {len(chapters)} English chapters...")
    
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
    
    tts_models_list = ["gemini-2.5-flash-preview-tts", "gemini-2.5-pro-preview-tts"]
    local_audio_dir = "temp_regen_atomic_en"
    os.makedirs(local_audio_dir, exist_ok=True)
    
    doc_changed = False
    
    for c_idx, chap in enumerate(chapters):
        title = chap.get("title", f"Chapter {c_idx + 1}")
        content = chap.get("content", "").strip()
        
        if not content:
            print(f"  [-] Chapter {c_idx} '{title}' has no content. Skipping.")
            continue
            
        print(f"\n  [*] Synthesizing Chapter {c_idx} '{title}'...")
        
        paragraphs_list = [p.strip() for p in re.split(r'\r?\n\r?\n', content) if p.strip()]
        if not paragraphs_list:
            paragraphs_list = [p.strip() for p in content.split("\n") if p.strip()]
            
        print(f"    - Splitting into {len(paragraphs_list)} paragraphs...")
        
        chapter_audio_bytes = b""
        chunk_success = True
        segments = []
        current_time = 0.0
        
        for p_idx, paragraph in enumerate(paragraphs_list):
            print(f"      Paragraph {p_idx + 1}/{len(paragraphs_list)} ({len(paragraph)} chars)...")
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
                        
                        if attempt < max_retries:
                            time.sleep(retry_delay)
                            retry_delay *= 2
                            
                if audio_bytes:
                    p_audio_bytes += audio_bytes
                else:
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
                local_wav_path = os.path.join(local_audio_dir, f"atomic_en_{c_idx}.wav")
                with wave.open(local_wav_path, "wb") as wav_file:
                    wav_file.setnchannels(1)
                    wav_file.setsampwidth(2)
                    wav_file.setframerate(24000)
                    wav_file.writeframes(chapter_audio_bytes)
                    
                # Upload to storage with a distinct path
                storage_path = f"audio/chapter_atomic_habits_en_{c_idx}.wav"
                print(f"    Uploading audio to Firebase Storage...")
                remote_audio_url = upload_file_to_storage(local_wav_path, storage_path, "audio/wav")
                
                if os.path.exists(local_wav_path):
                    os.remove(local_wav_path)
                    
                chap["audioUrl"] = remote_audio_url
                chap["duration"] = duration_sec
                chap["segments"] = segments
                doc_changed = True
                
                print(f"    [✓] Chapter {c_idx} audio successfully updated: {remote_audio_url} ({duration_sec}s)")
            except Exception as fe:
                print(f"    [!] Failed to finalize Chapter {c_idx}: {fe}")
        else:
            print(f"    [!] Audio synthesis failed for Chapter {c_idx}.")
            
    if doc_changed:
        print("\n[*] Updating Firestore 'atomic_habits' book document...")
        try:
            to_save = {k: v for k, v in book.items() if k != "id"}
            set_firestore_document("books", book_id, to_save)
            print("[✓] Book document updated successfully in Firestore!")
        except Exception as se:
            print(f"[!] Failed to save updated book document: {se}")
            
    try:
        if os.path.exists(local_audio_dir):
            os.rmdir(local_audio_dir)
    except:
        pass
        
    print("\n[✓] Regeneration completed!")

if __name__ == "__main__":
    main()
