import os
import sys
import re
import base64
import wave
import argparse
from typing import List

# Try to import google-genai. Print friendly error if not installed.
try:
    from google import genai
    from google.genai import types
except ImportError:
    print("\n[!] Error: The 'google-genai' SDK is not installed.")
    print("    Please install it by running: pip install google-genai\n")
    sys.exit(1)


def load_env_file(filepath: str = ".env"):
    """
    Parses a local .env file and loads variables into os.environ.
    This avoids external dependencies like python-dotenv.
    """
    if os.path.exists(filepath):
        print(f"[*] Found .env file, loading environment variables...")
        with open(filepath, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    parts = line.split("=", 1)
                    if len(parts) == 2:
                        key, val = parts[0].strip(), parts[1].strip()
                        # Strip optional quotes
                        if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                            val = val[1:-1]
                        os.environ[key] = val


def split_text_into_chunks(text: str, max_chars: int = 3000) -> List[str]:
    """
    Intelligently splits text into smaller chunks under max_chars.
    Prioritizes splitting on paragraph breaks, then sentence endings (., ?, !, ؟, ،),
    and falls back to word boundaries if a single block is too long.
    """
    if len(text) <= max_chars:
        return [text]

    chunks = []
    # Split first by paragraphs
    paragraphs = text.split('\n\n')
    current_chunk = ""

    for paragraph in paragraphs:
        # If adding this paragraph exceeds limit
        if len(current_chunk) + len(paragraph) + 2 > max_chars:
            # Save current accumulated chunk if it has content
            if current_chunk:
                chunks.append(current_chunk.strip())
                current_chunk = ""
            
            # If the paragraph itself exceeds the limit, split by sentences
            if len(paragraph) > max_chars:
                # Matches sentence endings in English (.?!) and Arabic (؟،!.) followed by whitespace
                sentences = re.split(r'(?<=[.?!؟،])\s+', paragraph)
                for sentence in sentences:
                    if len(current_chunk) + len(sentence) + 1 > max_chars:
                        if current_chunk:
                            chunks.append(current_chunk.strip())
                            current_chunk = ""
                        # If a single sentence exceeds the limit, split by words
                        if len(sentence) > max_chars:
                            words = sentence.split(' ')
                            for word in words:
                                if len(current_chunk) + len(word) + 1 > max_chars:
                                    if current_chunk:
                                        chunks.append(current_chunk.strip())
                                        current_chunk = ""
                                current_chunk = (current_chunk + " " + word).strip()
                        else:
                            current_chunk = sentence
                    else:
                        current_chunk = (current_chunk + " " + sentence).strip()
            else:
                current_chunk = paragraph
        else:
            if current_chunk:
                current_chunk += "\n\n" + paragraph
            else:
                current_chunk = paragraph
                
    if current_chunk:
        chunks.append(current_chunk.strip())
        
    return chunks


def main():
    parser = argparse.ArgumentParser(
        description="Premium Audio Narration Pipeline using Google GenAI SDK (gemini-2.5-flash-preview-tts)."
    )
    parser.add_argument(
        "-i", "--input", 
        help="Path to the input text file to read. If not provided, --text must be specified."
    )
    parser.add_argument(
        "-t", "--text", 
        help="Direct text string to narrate if input file is not used."
    )
    parser.add_argument(
        "-o", "--output", 
        default="narrated_book.wav",
        help="Name of the output WAV audio file (default: narrated_book.wav)."
    )
    parser.add_argument(
        "-d", "--dir", 
        default="output_audio",
        help="Local directory to save the output files (default: output_audio)."
    )
    parser.add_argument(
        "-l", "--lang", 
        default="en",
        choices=["en", "ar", "ku"],
        help="Language of narration: 'en' (English), 'ar' (Arabic), or 'ku' (Kurdish Sorani)."
    )
    parser.add_argument(
        "-v", "--voice", 
        default="Kore",
        help="Warm, natural voice selector. Common choices: Kore, Puck, Zephyr, Leda, Fenrir (default: Kore)."
    )
    parser.add_argument(
        "--api-key", 
        help="Google Gemini API key. If not specified, the script reads GEMINI_API_KEY from environment or .env."
    )
    parser.add_argument(
        "--model", 
        default="gemini-2.5-flash-preview-tts",
        help="Model to use for TTS (default: gemini-2.5-flash-preview-tts)."
    )
    parser.add_argument(
        "--max-chunk", 
        type=int, 
        default=3000,
        help="Max character limit per API request chunk to prevent truncation and maintain premium quality (default: 3000)."
    )
    
    args = parser.parse_args()

    # Load environment variables from .env
    load_env_file()

    # Determine API key
    api_key = args.api_key or os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("[!] Warning: GEMINI_API_KEY not found in environment, arguments, or .env.")
        print("    The SDK will attempt to use default system/gcloud credentials.")
        print("    To resolve, set GEMINI_API_KEY in your shell or .env file.")

    # Determine input text
    text_content = ""
    if args.input:
        if not os.path.exists(args.input):
            print(f"[!] Error: Input file not found at '{args.input}'")
            sys.exit(1)
        with open(args.input, "r", encoding="utf-8") as f:
            text_content = f.read()
    elif args.text:
        text_content = args.text
    else:
        print("[!] Error: You must provide either an input file (-i/--input) or direct text (-t/--text).")
        sys.exit(1)

    text_content = text_content.strip()
    if not text_content:
        print("[!] Error: Text content is empty.")
        sys.exit(1)

    # Setup language configuration
    if args.lang == "ar":
        lang_code = "ar-XA"
        system_instruction = (
            "أنت معلق صوتي محترف. اقرأ النص العربي التالي بصوت دافئ، واضح، ونبرة طبيعية تناسب "
            "ملخص كتاب صوتي مميز. حافظ على وتيرة قراءة متزنة وسلسة مع مراعاة الحركات ومخارج الحروف الصحيحة. "
            "لا تضف أي مقدمات أو هوامش، واقرأ فقط النص المكتوب."
        )
    elif args.lang == "ku":
        lang_code = "ckb-IQ"
        system_instruction = (
            "تۆ پێشکەشکارێکی دەنگی لێهاتووی. ئەم دەقە کوردییە (بە شێوەزاری سۆرانی) بە دەنگێکی گەرم، ڕوون، "
            "و بە شێوازێکی سروشتی بخوێنەرەوە کە گونجاو بێت بۆ کورتەکراوەی کتێبی دەنگی بەرز. "
            "خێرایییەکی لەسەرخۆ و ڕەوان بپارێزە. هیچ دەقێک یان سەرنجێکی زیادە لە خۆتەوە زیاد مەکە، "
            "تەنها دەقە نووسراوەکە بخوێنەرەوە."
        )
    else:
        lang_code = "en-US"
        system_instruction = (
            "You are a professional voice narrator. Read the following English text aloud with a warm, "
            "engaging, and natural tone suitable for a premium audiobook summary. Maintain a steady, "
            "fluent pace. Do not add introductory or concluding remarks; speak only the provided text."
        )

    # Initialize client
    client = genai.Client(api_key=api_key) if api_key else genai.Client()

    # Chunk the text to maintain audio quality and prevent character-limit errors
    chunks = split_text_into_chunks(text_content, max_chars=args.max_chunk)
    print(f"[*] Text length: {len(text_content)} characters. Split into {len(chunks)} chunks.")

    # Ensure output directory exists
    os.makedirs(args.dir, exist_ok=True)
    output_path = os.path.join(args.dir, args.output)

    # WAV generation properties (Gemini output is raw PCM 24000Hz, 16-bit, Mono)
    channels = 1
    sampwidth = 2  # 16-bit = 2 bytes
    framerate = 24000

    print(f"[*] Starting premium narration pipeline using model: '{args.model}' and voice: '{args.voice}'")
    
    # Store aggregated audio data
    all_audio_bytes = bytearray()

    for idx, chunk in enumerate(chunks, 1):
        print(f"[*] Narrating chunk {idx}/{len(chunks)} ({len(chunk)} characters)...")
        
        # Configure Generation Content
        config = types.GenerateContentConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(
                language_code=lang_code,
                voice_config=types.VoiceConfig(
                    prebuilt_voice_config=types.PrebuiltVoiceConfig(
                        voice_name=args.voice
                    )
                )
            )
        )

        try:
            response = client.models.generate_content(
                model=args.model,
                contents=chunk,
                config=config
            )

            # Retrieve inline audio bytes
            part = response.candidates[0].content.parts[0]
            if not part.inline_data or not part.inline_data.data:
                print(f"[!] Warning: No audio returned for chunk {idx}.")
                continue
            
            raw_data = part.inline_data.data
            
            # Convert base64 if returned as string, otherwise write bytes directly
            if isinstance(raw_data, str):
                pcm_chunk = base64.b64decode(raw_data)
            else:
                pcm_chunk = raw_data

            all_audio_bytes.extend(pcm_chunk)
            
        except Exception as e:
            print(f"[!] Error generating audio for chunk {idx}: {e}")
            print("Please ensure your API Key is valid and your prompt conforms to Google safety guidelines.")
            sys.exit(1)

    if not all_audio_bytes:
        print("[!] Error: No audio was successfully generated.")
        sys.exit(1)

    # Write combined audio to a WAV file
    print(f"[*] Writing aggregated audio to '{output_path}'...")
    try:
        with wave.open(output_path, "wb") as wav_file:
            wav_file.setnchannels(channels)
            wav_file.setsampwidth(sampwidth)
            wav_file.setframerate(framerate)
            wav_file.writeframes(all_audio_bytes)
            
        print(f"[✓] Narration pipeline complete! Premium audio saved to: {output_path}")
        
    except Exception as e:
        print(f"[!] Error writing WAV file: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
