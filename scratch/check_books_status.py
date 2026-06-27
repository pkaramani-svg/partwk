import sys
import os
import urllib.request
import json

sys.path.append("/Users/peshrawkaramani/Desktop/Partwk")
from dynamic_summary_pipeline import load_env_file, FIREBASE_PROJECT_ID, from_firestore_doc

load_env_file()

def inspect_books():
    url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/books"
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
            docs = data.get("documents", [])
            print(f"Found {len(docs)} books in Firestore.")
            for doc in docs:
                name = doc.get("name", "")
                fields = from_firestore_doc(doc)
                
                # Get titles
                title_map = fields.get("title", {})
                title_str = ", ".join([f"{k}: {v}" for k, v in title_map.items()])
                
                # Get chapters structure
                ch_map = fields.get("chapterSummaries", {})
                ch_counts = ", ".join([f"{k}: {len(v)} ch" for k, v in ch_map.items()])
                
                print(f"\nBook ID: {name.split('/')[-1]}")
                print(f"  Title: {title_str}")
                print(f"  Chapters: {ch_counts}")
                print(f"  Updated At: {fields.get('updatedAt')}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    inspect_books()
