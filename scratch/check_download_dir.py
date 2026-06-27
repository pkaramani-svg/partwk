import os
import glob

def find_books_dirs():
    pattern = "/Users/peshrawkaramani/Library/Developer/CoreSimulator/Devices/**/data/Containers/Data/Application/**/Documents/books"
    dirs = glob.glob(pattern, recursive=True)
    if not dirs:
        # Also check other potential paths, like Android emulator or other directories
        pattern_android = "/Users/peshrawkaramani/.android/**/*books"
        dirs = glob.glob(pattern_android, recursive=True)
    return dirs

def inspect_downloaded_files():
    dirs = find_books_dirs()
    if not dirs:
        print("No simulated books directory found. Checking local Desktop or build folders...")
        return
        
    print(f"Found {len(dirs)} books directory paths:")
    for d in dirs:
        print(f"\nDirectory: {d}")
        for root, subdirs, files in os.walk(d):
            for f in files:
                full_path = os.path.join(root, f)
                size_kb = os.path.getsize(full_path) / 1024.0
                rel_path = os.path.relpath(full_path, d)
                print(f"  - {rel_path} ({size_kb:.2f} KB)")

if __name__ == "__main__":
    inspect_downloaded_files()
