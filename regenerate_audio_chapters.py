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

# Add current directory to path to import from dynamic_summary_pipeline
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dynamic_summary_pipeline import (
    load_env_file,
    get_firestore_document,
    set_firestore_document,
    upload_file_to_storage,
    chunk_text,
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

def run_regeneration():
    parser = argparse.ArgumentParser(description="Regenerate audio narration for specific chapters of a book summary in Firestore.")
    parser.add_argument("--book_id", default=None, help="Firestore Book Document ID (e.g. deep_work)")
    parser.add_argument("--lang", default=None, help="Language code (en or ar or ku)")
    parser.add_argument("--voice", default=None, help="Narrator voice name (e.g. Charon)")
    parser.add_argument("--chapters", default=None, help="Comma-separated chapter indexes (e.g. 0,7,8)")
    
    args = parser.parse_args()

    # Fallback to interactive prompts if not provided
    book_id = args.book_id
    if not book_id:
        book_id = input("Enter Book Document ID [default: deep_work]: ").strip() or "deep_work"
        
    lang_code = args.lang
    if not lang_code:
        lang_code = input("Enter Language (en/ar/ku) [default: en]: ").strip().lower() or "en"
        
    voice_name = args.voice
    if not voice_name:
        voice_name = input("Enter Voice Name (e.g. Charon, Kore, Despina) [default: Charon]: ").strip() or "Charon"
        
    chap_input = args.chapters
    if not chap_input:
        chap_input = input("Enter chapter indexes to regenerate (comma-separated, e.g. 0,7,8): ").strip()
        
    if not chap_input:
        print("[!] No chapter indexes provided. Exiting.")
        sys.exit(0)
        
    try:
        chap_indexes = [int(x.strip()) for x in chap_input.split(",") if x.strip()]
    except ValueError:
        print("[!] Invalid chapter indexes. Must be comma-separated integers.")
        sys.exit(1)

    # Initialize client manager with API key rotation support
    client = GeminiClientManager()

    print(f"\n[*] Fetching document '{book_id}' from Firestore...")
    book_doc = get_firestore_document("books", book_id)
    if not book_doc:
        print(f"[!] Document '{book_id}' not found in Firestore books collection.")
        sys.exit(1)

    # Resolve summaries for the language
    chapter_summaries = book_doc.get("chapterSummaries", {})
    if lang_code not in chapter_summaries:
        print(f"[!] Language '{lang_code}' not found in chapterSummaries of document '{book_id}'.")
        sys.exit(1)

    chapters = chapter_summaries[lang_code]
    print(f"[✓] Found {len(chapters)} chapters in '{lang_code}' translation.")

    # Create temp directory for local audio
    local_audio_dir = "temp_pipeline_audio"
    os.makedirs(local_audio_dir, exist_ok=True)
    
    if lang_code == "ar":
        tts_lang_code = "ar-XA"
    elif lang_code == "ku":
        tts_lang_code = "ckb-IQ"
    else:
        tts_lang_code = "en-US"
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
    timestamp = int(time.time())

    for idx in chap_indexes:
        if idx < 0 or idx >= len(chapters):
            print(f"[!] Chapter index {idx} out of range (0 to {len(chapters)-1}). Skipping.")
            continue

        chap = chapters[idx]
        print(f"\n[*] Regenerating Chapter {idx}: '{chap.get('title', 'Untitled')}' ({len(chap.get('content', ''))} characters)...")

        chunks = chunk_text(chap.get("content", ""), max_chars=800)
        print(f"    Splitting chapter into {len(chunks)} chunks for stable synthesis...")

        chapter_audio_bytes = b""
        chunk_success = True

        for chunk_idx, chunk in enumerate(chunks, 1):
            print(f"      Chunk {chunk_idx}/{len(chunks)} ({len(chunk)} characters)...")
            
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
                    print(f"        [!] Attempt {attempt}/{max_retries} failed using {model_to_use}: {e}")
                    
                    # If we get a 429 quota exhaustion error, de-prioritize this model
                    err_str = str(e).lower()
                    if "429" in err_str or "quota" in err_str or "exhausted" in err_str:
                        if model_to_use in tts_models_list:
                            tts_models_list.remove(model_to_use)
                            tts_models_list.append(model_to_use)
                            print(f"        [*] Exhausted {model_to_use}. Shifted to the end of preferred list: {tts_models_list}")
                    
                    if attempt < max_retries:
                        # Parse short RPM retryDelay if returned by Google QuotaFailure
                        parsed_delay = None
                        try:
                            match = re.search(r"retryDelay':\s*'(\d+(?:\.\d+)?)s'", str(e))
                            if match:
                                parsed_delay = float(match.group(1)) + 2.0 # 2s safety buffer
                        except:
                            pass
                        
                        sleep_time = parsed_delay if (parsed_delay and parsed_delay <= 120) else retry_delay
                        print(f"        [*] Rate limited. Sleeping for {sleep_time}s before retrying...")
                        time.sleep(sleep_time)
                        retry_delay *= 2

            if audio_bytes:
                chapter_audio_bytes += audio_bytes
            else:
                print(f"      [!] Failed to synthesize chunk {chunk_idx} after {max_retries} retries.")
                chunk_success = False
                break

        if chunk_success and chapter_audio_bytes:
            try:
                # 24kHz PCM duration calculation
                duration_sec = int(len(chapter_audio_bytes) / 48000)
                
                # Write local WAV file temporarily
                local_wav_path = os.path.join(local_audio_dir, f"chap_regen_{timestamp}_{idx}.wav")
                with wave.open(local_wav_path, "wb") as wav_file:
                    wav_file.setnchannels(1)
                    wav_file.setsampwidth(2)
                    wav_file.setframerate(24000)
                    wav_file.writeframes(chapter_audio_bytes)

                # Upload to storage
                storage_path = f"audio/chapter_{timestamp}_{idx}.wav"
                print(f"    Uploading Chapter {idx} audio to Firebase Storage...")
                remote_audio_url = upload_file_to_storage(local_wav_path, storage_path, "audio/wav")
                
                # Clean up local WAV
                if os.path.exists(local_wav_path):
                    os.remove(local_wav_path)

                # Update in local memory structure
                chap["audioUrl"] = remote_audio_url
                chap["duration"] = duration_sec
                print(f"    [✓] Chapter {idx} audio successfully updated: {remote_audio_url} ({duration_sec}s)")
                
                # Incrementally save to Firestore so progress is never lost if the script is interrupted/hung
                print("    [*] Saving progress to Firestore...")
                try:
                    total_duration = sum(c.get("duration", 0) for c in chapters)
                    book_doc["duration"] = total_duration
                    set_firestore_document("books", book_id, book_doc)
                    print("    [✓] Firestore document updated successfully.")
                except Exception as db_ex:
                    print(f"    [!] Failed to save incremental progress to Firestore: {db_ex}")
            except Exception as fe:
                print(f"    [!] Failed to finalize audio file for Chapter {idx}: {fe}")
        else:
            print(f"    [!] Audio synthesis failed for Chapter {idx}. Document NOT updated.")

    # Recalculate total duration of the book for that language
    total_duration = sum(c.get("duration", 0) for c in chapters)
    book_doc["duration"] = total_duration

    # Update document in Firestore
    print(f"\n[*] Updating Firestore document '{book_id}'...")
    try:
        set_firestore_document("books", book_id, book_doc)
        print(f"[✓] Document '{book_id}' successfully updated in Firestore!")
        print(f"    Total Narration Duration: {round(total_duration / 60)} minutes")
    except Exception as se:
        print(f"[!] Failed to save updated document to Firestore: {se}")

if __name__ == "__main__":
    run_regeneration()
