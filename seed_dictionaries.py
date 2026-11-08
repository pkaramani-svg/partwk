import os
import sys
import json
import urllib.request
import urllib.parse
from typing import Dict, Any

# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dynamic_summary_pipeline import (
    load_env_file,
    set_firestore_document,
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

WORDS_TO_SEED = [
    "focus", "habit", "system", "clarity", "environment", "success", "leadership", "mind",
    "logic", "business", "progress", "growth", "energy", "strategy", "time", "productivity",
    "choice", "mindset", "effort", "action", "outcome", "grit", "power", "goal", "learning",
    "knowledge", "memory", "reading", "speed", "wisdom", "finance", "wealth", "leverage",
    "asset", "debt", "negotiation", "influence", "connection", "communication", "prompt",
    "intelligence", "dream", "failure", "risk", "reward", "courage", "fear", "happiness",
    "stoic", "discipline"
]

def generate_definition(client_manager: GeminiClientManager, word: str, lang: str) -> str:
    prompt = ""
    if lang == "en":
        prompt = f"Provide a brief, clear dictionary definition for the English word '{word}' in English. Keep it under 2 sentences."
    elif lang == "ku":
        prompt = f"Provide a brief, clear dictionary definition for the English word '{word}' in Kurdish Sorani. Do not translate the word literally as a title, just write the definition in Kurdish Sorani script. Keep it under 2 sentences."
    elif lang == "ar":
        prompt = f"Provide a brief, clear dictionary definition for the English word '{word}' in Arabic. Do not translate the word literally as a title, just write the definition in Arabic script. Keep it under 2 sentences."

    try:
        response = client_manager.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )
        return response.text.strip()
    except Exception as e:
        print(f"[!] Error generating definition for '{word}' in {lang}: {e}")
        return ""

def main():
    print("[*] Initializing Gemini Client...")
    client_manager = GeminiClientManager()

    print(f"[*] Starting dictionary seeding for {len(WORDS_TO_SEED)} words...")
    success_count = 0

    for idx, word in enumerate(WORDS_TO_SEED):
        print(f"\n[{idx+1}/{len(WORDS_TO_SEED)}] Processing word: {word}")
        
        # 1. English
        def_en = generate_definition(client_manager, word, "en")
        if def_en:
            doc_id = f"en_{word}"
            try:
                set_firestore_document("dictionaries", doc_id, {
                    "word": word,
                    "language": "en",
                    "definition": def_en
                })
                print(f"  [✓] Seeded English: {doc_id}")
            except Exception as e:
                print(f"  [!] Failed to set English Firestore doc: {e}")

        # 2. Kurdish
        def_ku = generate_definition(client_manager, word, "ku")
        if def_ku:
            prompt_word_ku = f"Translate the single English word '{word}' to its most common Kurdish Sorani translation (just the word, no extra text)."
            word_ku = client_manager.generate_content("gemini-2.5-flash", prompt_word_ku).text.strip().lower()
            if word_ku:
                for k in [word, word_ku]:
                    doc_id = f"ku_{k}"
                    try:
                        set_firestore_document("dictionaries", doc_id, {
                            "word": k,
                            "language": "ku",
                            "definition": def_ku
                        })
                        print(f"  [✓] Seeded Kurdish: {doc_id}")
                    except Exception as e:
                        print(f"  [!] Failed to set Kurdish Firestore doc: {e}")

        # 3. Arabic
        def_ar = generate_definition(client_manager, word, "ar")
        if def_ar:
            prompt_word_ar = f"Translate the single English word '{word}' to its most common Arabic translation (just the word, no extra text)."
            word_ar = client_manager.generate_content("gemini-2.5-flash", prompt_word_ar).text.strip().lower()
            if word_ar:
                for k in [word, word_ar]:
                    doc_id = f"ar_{k}"
                    try:
                        set_firestore_document("dictionaries", doc_id, {
                            "word": k,
                            "language": "ar",
                            "definition": def_ar
                        })
                        print(f"  [✓] Seeded Arabic: {doc_id}")
                    except Exception as e:
                        print(f"  [!] Failed to set Arabic Firestore doc: {e}")

        success_count += 1

    print(f"\n[✓] Finished dictionary seeding. Processed {success_count} words.")

if __name__ == "__main__":
    main()
