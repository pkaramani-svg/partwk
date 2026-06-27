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
import difflib

# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dynamic_summary_pipeline import (
    load_env_file,
    get_firestore_document,
    set_firestore_document,
    upload_file_to_storage,
    chunk_text,
    FIREBASE_PROJECT_ID,
    FIREBASE_BUCKET,
    GeminiClientManager,
    from_firestore_doc
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

def list_firestore_documents(collection: str) -> list:
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

def detect_voice(audio_url: str, client: GeminiClientManager) -> str:
    """Downloads first 10s of audio and detects which prebuilt voice was used."""
    local_path = "temp_voice_detect.wav"
    try:
        # Download file
        urllib.request.urlretrieve(audio_url, local_path)
        with open(local_path, "rb") as f:
            audio_data = f.read()
        
        # Trim to 10 seconds (24kHz, 16bit, mono = 48000 bytes/sec)
        # Header is 44 bytes.
        trimmed_data = audio_data[:44 + 48000 * 10]
        
        prompt = (
            "You are an expert audio analyst. Listen to the provided audio file. "
            "Identify which of the following 12 prebuilt voices is speaking in this audio file:\n"
            "  - Male Voices: 'Charon', 'Puck', 'Zephyr', 'Fenrir', 'Orus', 'Umbriel'\n"
            "  - Female Voices: 'Kore', 'Aoede', 'Leda', 'Autonoe', 'Callirrhoe', 'Despina'\n\n"
            "Respond with ONLY the voice name (e.g. 'Charon' or 'Kore'), and absolutely nothing else."
        )
        
        resp = client.generate_content(
            model="gemini-2.5-flash",
            contents=[
                types.Part.from_bytes(data=trimmed_data, mime_type="audio/wav"),
                prompt
            ]
        )
        voice = resp.text.strip()
        # Sanitize voice output
        for valid in ["Charon", "Puck", "Zephyr", "Fenrir", "Orus", "Umbriel", "Kore", "Aoede", "Leda", "Autonoe", "Callirrhoe", "Despina"]:
            if valid.lower() in voice.lower():
                return valid
        print(f"      [!] Unexpected voice returned: '{voice}'. Defaulting to 'Charon'.")
        return "Charon"
    except Exception as e:
        print(f"      [!] Failed to detect voice: {e}. Defaulting to 'Charon'.")
        return "Charon"
    finally:
        if os.path.exists(local_path):
            os.remove(local_path)

def has_duplicate_greeting(content: str, prefix: str, lang: str) -> bool:
    """Helper to check if a duplicate welcome sentence exists after the prefix."""
    content_clean = content.strip()
    if not content_clean.startswith(prefix.strip()):
        # Check if it has a welcoming sentence in the first paragraph anyway
        paragraphs = [p.strip() for p in re.split(r'\r?\n\r?\n', content_clean) if p.strip()]
        if not paragraphs:
            return False
        first_p = paragraphs[0]
    else:
        # Get the text after the prefix
        first_p = content_clean[len(prefix.strip()):].strip()
        
    if not first_p:
        return False
        
    # Analyze the first 50 chars of the text following the prefix
    first_few = first_p[:50].lower().strip()
    
    if lang == "en":
        # Check for English welcoming words
        return (first_few.startswith("welcome") or 
                first_few.startswith("welcome to") or 
                first_few.startswith("welcome, dear") or
                first_few.startswith("welcome, listener") or
                first_few.startswith("welcome. in this summary") or
                first_few.startswith("hello and welcome"))
    else:
        # Check for Arabic welcoming words
        return (first_few.startswith("أهلاً") or 
                first_few.startswith("اهلاً") or 
                first_few.startswith("مرحباً") or 
                first_few.startswith("مرحبا") or
                first_few.startswith("أهلاً بك") or
                first_few.startswith("أهلاً بكم") or
                first_few.startswith("اهلاً بك") or
                first_few.startswith("اهلاً بكم") or
                first_few.startswith("مرحباً بك") or
                first_few.startswith("مرحباً بكم") or
                first_few.startswith("مرحبا بك") or
                first_few.startswith("مرحبا بكم"))

def clean_text_with_gemini(original_content: str, prefix: str, lang: str, client: GeminiClientManager) -> str:
    """Asks Gemini to rewrite the first paragraph to remove duplicate welcoming greetings."""
    lang_name = "English" if lang == "en" else "Arabic"
    prompt = (
        f"You are a precise text-cleaning editor. You are given the first chapter (Introduction) of a book summary in {lang_name}.\n"
        f"The text starts with the system welcoming prefix:\n"
        f"\"{prefix}\"\n"
        f"Directly following this prefix, there is a redundant welcoming sentence generated by the AI model (such as 'Welcome to this summary...', 'Welcome to a deep dive...', 'Welcome, dear listener...', 'أهلاً بك في ملخص كتاب...', 'مرحباً بكم في ملخصنا الشامل...', or similar welcoming/greeting sentences).\n"
        f"Please rewrite the text to remove this redundant welcoming sentence. Ensure that the prefix is preserved EXACTLY as-is at the very beginning of the paragraph, and the text flows naturally into the actual introduction content. Keep all other paragraphs, sentences, and layout exactly unchanged. Do not add any new words, explanations, or commentary. Respond with ONLY the edited chapter text.\n\n"
        f"Original Introduction Text:\n"
        f"{original_content}"
    )
    try:
        resp = client.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )
        cleaned = resp.text.strip()
        # Clean any markdown block enclosures if returned
        if cleaned.startswith("```"):
            cleaned = re.sub(r"^```[a-zA-Z]*\n", "", cleaned)
            cleaned = re.sub(r"\n```$", "", cleaned)
            cleaned = cleaned.strip()
            
        # Hard check: must start with prefix. If not, prepended prefix might have been mangled
        if not cleaned.startswith(prefix.strip()):
            paragraphs = [p.strip() for p in re.split(r'\r?\n\r?\n', cleaned) if p.strip()]
            if paragraphs:
                cleaned = prefix + cleaned
        
        return cleaned
    except Exception as e:
        print(f"      [!] Failed to clean text: {e}")
        return original_content

def main():
    socket.setdefaulttimeout(60.0)
    client = GeminiClientManager()
    
    print("[*] Listing books in Firestore...")
    books = list_firestore_documents("books")
    print(f"[✓] Found {len(books)} books.")
    
    local_temp_dir = "temp_cleanup_audio"
    os.makedirs(local_temp_dir, exist_ok=True)
    
    for b_idx, book in enumerate(books, 1):
        b_id = book["id"]
        b_title = book.get("title", {}).get("en") or book.get("title", {}).get("ar") or "Untitled"
        print(f"\n======================================================================")
        print(f"[*] Book {b_idx}/{len(books)}: '{b_title}' (ID: {b_id})")
        print(f"======================================================================")
        
        chapter_summaries = book.get("chapterSummaries", {})
        book_changed = False
        
        for lang in ["en", "ar"]:
            if lang not in chapter_summaries:
                continue
                
            chapters = chapter_summaries[lang]
            if not chapters:
                continue
                
            intro_chap = chapters[0]
            original_content = intro_chap.get("content", "").strip()
            audio_url = intro_chap.get("audioUrl", "")
            
            if not original_content:
                continue
                
            book_title_lang = book.get("title", {}).get(lang) or book.get("title", {}).get("en")
            author_lang = book.get("author", {}).get(lang) or book.get("author", {}).get("en")
            
            if lang == "en":
                prefix = f"Introduction, welcome to this audio summary of {book_title_lang}, by {author_lang}. "
            else:
                prefix = f"المقدمة، مرحباً بكم في هذا الملخص الصوتي لكتاب {book_title_lang}، بقلم {author_lang}. "
            
            # PRE-CHECK: only clean if there is actually a duplicate welcoming greeting!
            if not has_duplicate_greeting(original_content, prefix, lang):
                print(f"  [{lang}] Skipping '{intro_chap.get('title')}' (No duplicate greeting found).")
                continue
                
            # 1. Clean the text using Gemini
            print(f"  [{lang}] Cleaning text for '{intro_chap.get('title')}'...")
            cleaned_content = clean_text_with_gemini(original_content, prefix, lang, client)
            
            # Print diff if any changes
            if cleaned_content != original_content:
                print("    - Changes detected:")
                diff = list(difflib.unified_diff(
                    original_content.splitlines(),
                    cleaned_content.splitlines(),
                    fromfile="original",
                    tofile="cleaned",
                    lineterm=""
                ))
                for line in diff[:10]: # Print first 10 lines of diff
                    print(f"      {line}")
                if len(diff) > 10:
                    print(f"      ... and {len(diff) - 10} more lines of diff.")
            else:
                print("    - No changes needed (already clean).")
                continue
            
            # 2. Narration Regeneration (only if original audioUrl exists)
            if not audio_url:
                print("    - No audio URL exists. Updating text content only.")
                intro_chap["content"] = cleaned_content
                book_changed = True
                continue
                
            print(f"    - Detecting original narrator voice from audio...")
            voice_name = detect_voice(audio_url, client)
            print(f"    - Detected narrator voice: '{voice_name}'")
            
            # Re-synthesize audio paragraph by paragraph
            paragraphs = [p.strip() for p in re.split(r'\r?\n\r?\n', cleaned_content) if p.strip()]
            if not paragraphs:
                paragraphs = [p.strip() for p in cleaned_content.split("\n") if p.strip()]
                
            print(f"    - Synthesizing {len(paragraphs)} paragraphs...")
            tts_lang_code = "ar-XA" if lang == "ar" else "en-US"
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
            
            chapter_audio_bytes = b""
            chunk_success = True
            segments = []
            current_time = 0.0
            tts_models_list = ["gemini-2.5-flash-preview-tts", "gemini-2.5-pro-preview-tts"]
            
            for p_idx, paragraph in enumerate(paragraphs):
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
                            print(f"        [!] Attempt {attempt}/{max_retries} failed: {e}")
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
                    
                    # Add 1.5 seconds silent pause between paragraphs (except after the last one)
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
                    local_wav_path = os.path.join(local_temp_dir, f"intro_{b_id}_{lang}.wav")
                    with wave.open(local_wav_path, "wb") as wav_file:
                        wav_file.setnchannels(1)
                        wav_file.setsampwidth(2)
                        wav_file.setframerate(24000)
                        wav_file.writeframes(chapter_audio_bytes)
                        
                    storage_path = f"audio/chapter_clean_{b_id}_{lang}_0.wav"
                    print("    - Uploading new audio track to Firebase Storage...")
                    remote_audio_url = upload_file_to_storage(local_wav_path, storage_path, "audio/wav")
                    
                    if os.path.exists(local_wav_path):
                        os.remove(local_wav_path)
                        
                    # Update chapter properties
                    intro_chap["content"] = cleaned_content
                    intro_chap["audioUrl"] = remote_audio_url
                    intro_chap["duration"] = duration_sec
                    intro_chap["segments"] = segments
                    book_changed = True
                    print(f"    [✓] Intro chapter updated successfully: {remote_audio_url} ({duration_sec}s)")
                except Exception as ex:
                    print(f"    [!] Error finalizing audio upload: {ex}")
            else:
                print(f"    [!] Failed to synthesize audio for Chapter 1. Text changes not applied.")
                
        if book_changed:
            # Recompute total duration
            total_duration = 0
            for l in ["en", "ar"]:
                if l in chapter_summaries:
                    total_duration += sum(c.get("duration", 0) for c in chapter_summaries[l])
            
            book["duration"] = total_duration
            
            print(f"[*] Updating document '{b_id}' in Firestore...")
            try:
                to_save = {k: v for k, v in book.items() if k != "id"}
                set_firestore_document("books", b_id, to_save)
                print(f"[✓] Firestore updated successfully for '{b_id}'!")
            except Exception as se:
                print(f"[!] Failed to save updated book to Firestore: {se}")
                
    try:
        if os.path.exists(local_temp_dir):
            os.rmdir(local_temp_dir)
    except:
        pass
    print("\n[✓] Cleanup process completed successfully!")

if __name__ == "__main__":
    main()
