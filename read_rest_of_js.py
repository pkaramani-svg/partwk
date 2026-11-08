def main():
    with open("lexSearch.js", "r", encoding="utf-8") as f:
        content = f.read()
    
    print(f"Total size: {len(content)}")
    # Find functions containing search, auto, select, etc.
    # Print from character index 2000 to the end
    print(content[2000:])

if __name__ == "__main__":
    main()
