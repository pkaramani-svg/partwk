import os
import sys
import json
import urllib.request
import urllib.parse
import re
import time

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dynamic_summary_pipeline import (
    load_env_file,
    set_firestore_document
)

# Load environment variables
load_env_file()

WORD_TRANSLATIONS = {
    "focus": "سەرنج",
    "habit": "خوو",
    "system": "سیستەم",
    "clarity": "ڕوونی",
    "environment": "ژینگە",
    "success": "سەرکەوتن",
    "leadership": "سەرکردایەتی",
    "mind": "مێشک",
    "logic": "لۆژیک",
    "business": "بازرگانی",
    "progress": "پێشکەوتن",
    "growth": "گەشە",
    "energy": "وزە",
    "strategy": "ستراتیژی",
    "time": "کات",
    "productivity": "بەرهەمهێنان",
    "choice": "هەڵبژاردن",
    "mindset": "بیرکردنەوە",
    "effort": "هەوڵ",
    "action": "کردار",
    "outcome": "دەرئەنجام",
    "grit": "خۆڕاگری",
    "power": "هێز",
    "goal": "ئامانج",
    "learning": "فێربوون",
    "knowledge": "زانین",
    "memory": "بیرەوەری",
    "reading": "خوێندنەوە",
    "speed": "خێرایی",
    "wisdom": "دانایی",
    "finance": "دارایی",
    "wealth": "سەروەت",
    "leverage": "دەستکەوت",
    "asset": "سەرمایە",
    "debt": "قەرز",
    "negotiation": "گفتوگۆ",
    "influence": "کاریگەری",
    "connection": "پەیوەندی",
    "communication": "پەیوەندی",
    "prompt": "هاندان",
    "intelligence": "زیرەکی",
    "dream": "خەون",
    "failure": "شکست",
    "risk": "ڕیسک",
    "reward": "پاداش",
    "courage": "ئازایەتی",
    "fear": "ترس",
    "happiness": "خۆشحاڵی",
    "stoic": "خۆڕاگر",
    "discipline": "دیسپلین",
    "attention": "سەرنج",
    "boundary": "سنوور",
    "silence": "بێدەنگی",
    "routine": "ڕۆتین",
    "muscle": "ماسولکە",
    "practice": "ڕاهێنان",
    "target": "ئامانج",
    "schedule": "بەرنامە",
    "achievement": "دەسکەوت",
    "temperance": "میانەڕەوی",
    "justice": "دادپەروەری",
    "nature": "سروشت",
    "stress": "فشار",
    "meditation": "تێڕامان",
    "reaction": "کاردانەوە",
    "perception": "تێگەیشتن",
    "obstacle": "کۆسپ",
    "control": "کۆنتڕۆڵ",
    "willpower": "ئیرادە",
    "peace": "ئاشتی",
    "tranquility": "ئارامی",
    "ego": "خۆبەزلزانین",
    "humbleness": "خاکەڕایی",
    "reflection": "ڕەنگدانەوە",
    "distraction": "سەرقاڵی"
}

def clean_html(raw_html: str) -> str:
    # 1. Replace list items and block elements with readable layout
    text = raw_html.replace('<li>', ' – ').replace('</li>', '\n')
    text = text.replace('<div>', '').replace('</div>', '\n')
    text = text.replace('<ol>', '').replace('</ol>', '')
    text = text.replace('<ul>', '').replace('</ul>', '')
    text = text.replace('<p>', '').replace('</p>', '\n')
    
    # 2. Strip all remaining HTML tags
    text = re.sub(r'<[^>]*>', '', text)
    
    # 3. Clean up leading/trailing line spacing
    lines = [line.strip() for line in text.split('\n') if line.strip()]
    return '\n'.join(lines)

def extract_synonyms(word: str, def_text: str) -> list:
    first_line = def_text.split('\n')[0] if def_text else ""
    separators = ['،', ',', '؛', ';']
    syns = []
    for sep in separators:
        if sep in first_line:
            parts = [p.strip() for p in first_line.split(sep) if p.strip()]
            for p in parts:
                clean_p = re.sub(r'[\(\[\{].*?[\)\]\}]', '', p).strip()
                if clean_p and clean_p != word and len(clean_p) < 15:
                    syns.append(clean_p)
            break
    return list(set(syns))

def guess_part_of_speech(word: str) -> str:
    verb_endings = ["کردن", "بوون", "دان", "چوون", "کەوتن", "هێنان", "بردن", "گواستنەوە", "گرتن", "نووسین", "خوێندنەوە", "زانین", "فێربوون"]
    for ending in verb_endings:
        if word.endswith(ending):
            return "verb"
    return "noun"

def normalize_kurdish(text: str) -> str:
    normalized = text.strip()
    replacements = {
        'ك': 'ک',
        'ي': 'ی',
        'ى': 'ی'
    }
    for orig, rep in replacements.items():
        normalized = normalized.replace(orig, rep)
    return normalized

def scrape_from_vejin(word: str) -> tuple:
    encoded_word = urllib.parse.quote(word)
    
    # 1. First try specifically in "فەرهەنگی شێخانی" (d=15)
    url_shexani = f"https://lex.vejin.net/ck/search?t={encoded_word}&d=15"
    req_shexani = urllib.request.Request(url_shexani, headers={"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"})
    try:
        with urllib.request.urlopen(req_shexani, timeout=10) as resp:
            html = resp.read().decode("utf-8")
            res_def, syns, src = parse_vejin_html(html, word, "فەرهەنگی شێخانی")
            if res_def:
                return res_def, syns, src
    except Exception as e:
        print(f"  [!] Shexani scrape error for '{word}': {e}")

    # 2. Fall back to search all dictionaries to match Xal or Henbane Borine
    url_all = f"https://lex.vejin.net/ck/search?t={encoded_word}"
    req_all = urllib.request.Request(url_all, headers={"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"})
    try:
        with urllib.request.urlopen(req_all, timeout=10) as resp:
            html = resp.read().decode("utf-8")
            # Try فەرهەنگی خاڵ
            res_def, syns, src = parse_vejin_html(html, word, "فەرهەنگی خاڵ")
            if res_def:
                return res_def, syns, src
            
            # Try هەنبانە بۆرینە
            res_def, syns, src = parse_vejin_html(html, word, "هەنبانە بۆرینە")
            if res_def:
                return res_def, syns, src
    except Exception as e:
        print(f"  [!] Fallback search scrape error for '{word}': {e}")
        
    return None, [], None

def parse_vejin_html(html: str, word: str, target_dict_name: str) -> tuple:
    if '<div class="result">' not in html:
        return None, [], None
    
    parts = html.split('<div class="result">')[1:]
    for part in parts:
        source_match = re.search(r'<span class="fromDict">(.*?)</span>', part)
        if not source_match:
            continue
        source = source_match.group(1).strip()
        
        if target_dict_name not in source:
            continue
            
        def_match = re.search(r'<div class="resultDef\s+rtl"\s*>(.*?)</div>\s*</div>', part, re.DOTALL)
        if not def_match:
            def_match = re.search(r'<div class="resultDef\s+ltr"\s*>(.*?)</div>\s*</div>', part, re.DOTALL)
            
        if def_match:
            def_html = def_match.group(1)
            def_text = clean_html(def_html)
            syns = extract_synonyms(word, def_text)
            return def_text, syns, source
            
    return None, [], None

def main():
    print("Starting Kurdish Monolingual Dictionary Sourcing & Seeding...")
    success_count = 0
    
    for english_word, kurdish_word in WORD_TRANSLATIONS.items():
        print(f"\nProcessing '{english_word}' -> '{kurdish_word}'...")
        
        # Scrape definition
        def_ckb, synonyms, source_dict = scrape_from_vejin(kurdish_word)
        
        if not def_ckb:
            print(f"  [!] No definition found for '{kurdish_word}' on VejinLex. Skipping.")
            continue
            
        print(f"  [✓] Found in dictionary: '{source_dict}'")
        
        normalized_word = normalize_kurdish(kurdish_word)
        pos = guess_part_of_speech(normalized_word)
        
        # Build target schema
        doc_data = {
            "word": normalized_word,
            "dialect_tag": "Sorani",
            "part_of_speech": pos,
            "definition_ckb": def_ckb,
            "synonyms": synonyms,
            "search_vector": f"{normalized_word}, {english_word}, {kurdish_word}",
            # Backwards compatibility key
            "language": "ku",
            "definition": def_ckb
        }
        
        # Seed both under english word and kurdish word IDs
        for key in [english_word, normalized_word]:
            doc_id = f"ku_{key}"
            try:
                set_firestore_document("dictionaries", doc_id, doc_data)
                print(f"  [✓] Seeded document: {doc_id}")
            except Exception as e:
                print(f"  [!] Firestore seeding failed for {doc_id}: {e}")
                
        success_count += 1
        time.sleep(1) # Polite scraping delay
        
    print(f"\n[✓] Finished seeding. Seeded {success_count} words in Firestore dictionaries.")

if __name__ == "__main__":
    main()
