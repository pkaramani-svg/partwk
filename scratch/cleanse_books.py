import sys
import os
import urllib.request
import json
import re

sys.path.append("/Users/peshrawkaramani/Desktop/Partwk")
from dynamic_summary_pipeline import load_env_file, FIREBASE_PROJECT_ID, from_firestore_doc, set_firestore_document

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
    return books

def cleanse_text(text):
    if not text:
        return text
    cleaned = text
    cleaned = cleaned.replace('"', '')
    cleaned = cleaned.replace('“', '')
    cleaned = cleaned.replace('”', '')
    cleaned = cleaned.replace('«', '')
    cleaned = cleaned.replace('»', '')
    return cleaned

def clean_books():
    docs = fetch_all_books()
    if not docs:
        print("No books found to cleanse.")
        return

    print(f"Fetched {len(docs)} books total for cleansing.")
    cleansed_count = 0
    for doc in docs:
        name = doc.get("name", "")
        doc_id = name.split("/")[-1]
        fields = from_firestore_doc(doc)
        
        chapter_summaries = fields.get("chapterSummaries", {})
        changed = False

        for lang in list(chapter_summaries.keys()):
            chapters = chapter_summaries[lang]
            for chap in chapters:
                content = chap.get("content", "")
                title = chap.get("title", "")
                
                # Check if there are quotation marks
                if any(q in content for q in ['"', '“', '”', '«', '»']):
                    new_content = cleanse_text(content)
                    chap["content"] = new_content
                    changed = True

                # Cleanse chapter title if it tracks original chapter layouts or contains quotes
                if any(q in title for q in ['"', '“', '”', '«', '»']):
                    chap["title"] = cleanse_text(title)
                    changed = True

        if changed:
            set_firestore_document("books", doc_id, fields)
            print(f"[✓] Cleansed and synchronized book ID: {doc_id}")
            cleansed_count += 1

    print(f"Cleansing completed. Updated {cleansed_count} books in Firestore.")

if __name__ == "__main__":
    clean_books()
