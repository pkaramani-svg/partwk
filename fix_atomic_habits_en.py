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

# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dynamic_summary_pipeline import (
    load_env_file,
    get_firestore_document,
    set_firestore_document,
    upload_file_to_storage,
    chunk_text,
    FIREBASE_PROJECT_ID,
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
    sys.exit(1)

def main():
    socket.setdefaulttimeout(60.0)
    client = GeminiClientManager()
    
    book_id = "atomic_habits"
    print(f"[*] Fetching book '{book_id}' from Firestore...")
    book = get_firestore_document("books", book_id)
    if not book:
        print(f"[!] Error: Book '{book_id}' not found.")
        sys.exit(1)
        
    chapter_summaries = book.get("chapterSummaries", {})
    if "en" not in chapter_summaries:
        print("[!] Error: English ('en') summaries not found.")
        sys.exit(1)
        
    chapters = chapter_summaries["en"]
    intro_chap = chapters[0]
    content = intro_chap.get("content", "").strip()
    voice_name = "Charon" # Voice used for atomic_habits English
    
    print(f"[*] Regenerating English intro audio using voice '{voice_name}'...")
    print("Content to synthesize:")
    print(content)
    
    paragraphs = [p.strip() for p in re.split(r'\r?\n\r?\n', content) if p.strip()]
    if not paragraphs:
        paragraphs = [p.strip() for p in content.split("\n") if p.strip()]
        
    print(f"[*] Synthesizing {len(paragraphs)} paragraphs...")
    
    tts_config = types.GenerateContentConfig(
        response_modalities=["AUDIO"],
        speech_config=types.SpeechConfig(
            language_code="en-US",
            voice_config=types.VoiceConfig(
                prebuilt_voice_config=types.PrebuiltVoiceConfig(
                    voice_name=voice_name
                )
            )
        )
    )
    
    chapter_audio_bytes = b""
    chunk_success = True
    segments = []
    current_time = 0.0
    tts_models_list = ["gemini-2.5-flash-preview-tts", "gemini-2.5-pro-preview-tts"]
    
    for p_idx, paragraph in enumerate(paragraphs):
        print(f"  Synthesizing Paragraph {p_idx + 1}/{len(paragraphs)} ({len(paragraph)} chars)...")
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
                    print(f"    [!] Attempt {attempt}/{max_retries} failed: {e}")
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
            
            if p_idx < len(paragraphs) - 1:
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
            local_wav_path = "temp_atomic_intro_en.wav"
            with wave.open(local_wav_path, "wb") as wav_file:
                wav_file.setnchannels(1)
                wav_file.setsampwidth(2)
                wav_file.setframerate(24000)
                wav_file.writeframes(chapter_audio_bytes)
                
            storage_path = f"audio/chapter_clean_atomic_habits_en_0.wav"
            print("[*] Uploading correct audio track to Firebase Storage...")
            remote_audio_url = upload_file_to_storage(local_wav_path, storage_path, "audio/wav")
            
            if os.path.exists(local_wav_path):
                os.remove(local_wav_path)
                
            # Update intro chapter properties
            intro_chap["audioUrl"] = remote_audio_url
            intro_chap["duration"] = duration_sec
            intro_chap["segments"] = segments
            
            # Recalculate book duration
            total_duration = 0
            for l in ["en", "ar"]:
                if l in chapter_summaries:
                    total_duration += sum(c.get("duration", 0) for c in chapter_summaries[l])
            book["duration"] = total_duration
            
            # Save book to Firestore
            print("[*] Saving updated book to Firestore...")
            to_save = {k: v for k, v in book.items() if k != "id"}
            set_firestore_document("books", book_id, to_save)
            print(f"[✓] English intro audio regenerated and saved successfully! Duration: {duration_sec}s")
            
        except Exception as e:
            print(f"[!] Error finalizing regeneration: {e}")
    else:
        print("[!] Audio synthesis failed.")

if __name__ == "__main__":
    main()
