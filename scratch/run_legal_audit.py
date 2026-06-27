import sys
import os
import urllib.request
import json
import re
import math

sys.path.append("/Users/peshrawkaramani/Desktop/Partwk")
from dynamic_summary_pipeline import load_env_file, FIREBASE_PROJECT_ID, from_firestore_doc

load_env_file()

def fetch_all_books():
    books = []
    url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/books?pageSize=100"
    while url:
        req = urllib.request.Request(url, method="GET")
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode())
                docs = data.get("documents", [])
                books.extend(docs)
                page_token = data.get("nextPageToken")
                if page_token:
                    url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/books?pageSize=100&pageToken={page_token}"
                else:
                    url = None
        except Exception as e:
            print(f"Error fetching page: {e}")
            break
    return [from_firestore_doc(doc) for doc in books]

def calculate_copyscape_cost(word_count):
    if word_count == 0:
        return 0.0
    if word_count <= 200:
        return 0.03
    else:
        additional_words = word_count - 200
        additional_hundreds = math.ceil(additional_words / 100.0)
        return 0.03 + (additional_hundreds * 0.01)

def run_audit():
    books = fetch_all_books()
    if not books:
        print("No books found to audit.")
        return

    findings = []
    total_copyscape_cost = 0.0
    total_word_count = 0
    all_compliant = True

    # Zero Quotes: checking for double quotes in text
    quote_pattern = re.compile(r'["“”“»«]')

    for book in books:
        title_map = book.get("title", {})
        author_map = book.get("author", {})
        chapter_summaries = book.get("chapterSummaries", {})

        book_id = book.get("title", {}).get("en", "Unknown Book")

        for lang in ["en", "ar", "ku"]:
            if lang not in chapter_summaries:
                continue

            chapters = chapter_summaries[lang]
            lang_title = title_map.get(lang, book_id)
            lang_name = "English" if lang == "en" else ("Arabic" if lang == "ar" else "Kurdish")

            # Check each chapter
            for idx, chap in enumerate(chapters):
                chap_title = chap.get("title", "")
                chap_content = chap.get("content", "")
                word_count = len(chap_content.split())
                
                # Only check Copyscape API cost statistics for English language
                if lang == "en":
                    total_word_count += word_count
                    cost = calculate_copyscape_cost(word_count)
                    total_copyscape_cost += cost

                remediations = []
                status = "COMPLIANT"

                # Check for quotes
                has_quotes = quote_pattern.search(chap_content) is not None
                if has_quotes:
                    remediations.append("Contains quotation marks / raw text quotes; must strip or rewrite into indirect speech.")
                    status = "NON-COMPLIANT"
                    all_compliant = False

                if not remediations:
                    status = "COMPLIANT"
                else:
                    status = "NON-COMPLIANT"

                findings.append({
                    "lang_book": f"{lang_name} / {lang_title}",
                    "component": f"Chapter {idx+1}: {chap_title}",
                    "status": status,
                    "remediations": "; ".join(remediations) if remediations else "None (Transformed educational breakdown)"
                })

    # Print results
    print(f"Audit completed across {len(books)} books.")
    print(f"Total English words: {total_word_count}")
    print(f"Total Copyscape API Cost (English only): ${total_copyscape_cost:.2f} USD")

    # Generate Markdown Table
    print("\n| Language / Book Title | Asset Component | Verification Status | Required Remediations & Rewrites |")
    print("| :--- | :--- | :--- | :--- |")
    for f in findings:
        print(f"| {f['lang_book']} | {f['component']} | {f['status']} | {f['remediations']} |")

    if all_compliant:
        print("\nALL SYSTEMS COMPLIANT")
    else:
        print("\nAUDIT FAILED - REMEDIATIONS REQUIRED")

if __name__ == "__main__":
    run_audit()
