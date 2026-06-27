import sys
import os
import urllib.request
import json

sys.path.append("/Users/peshrawkaramani/Desktop/Partwk")
from dynamic_summary_pipeline import load_env_file, FIREBASE_PROJECT_ID, from_firestore_doc

load_env_file()

def inspect_users():
    url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/users"
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
            docs = data.get("documents", [])
            print(f"Found {len(docs)} users.")
            for doc in docs:
                name = doc.get("name", "")
                fields = from_firestore_doc(doc)
                print(f"\nUser: {fields.get('name')} ({fields.get('email')})")
                print("  completedBooks:", fields.get("completedBooks"))
                print("  savedBooks:", fields.get("savedBooks"))
                print("  listeningProgress:", fields.get("listeningProgress"))
                print("  readingProgress:", fields.get("readingProgress"))
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    inspect_users()
