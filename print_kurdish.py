import urllib.request
import json
from dynamic_summary_pipeline import load_env_file, FIREBASE_PROJECT_ID

load_env_file()

def main():
    url = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents/dictionaries"
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            documents = data.get("documents", [])
            for d in documents:
                name = d.get("name", "").split("/")[-1]
                if name.startswith("ku_"):
                    fields = d.get("fields", {})
                    word = fields.get("word", {}).get("stringValue", "")
                    definition = fields.get("definition", {}).get("stringValue", "")
                    print(f"Key: {name} | Word: {word}")
                    print(f"Definition: {definition}")
                    print("-" * 40)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
