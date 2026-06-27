import os
import re

directory = '/Users/peshrawkaramani/Desktop/Partwk/lib'

count = 0
for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()
            
            # Use regex to match the exact word 'Locator'
            new_content = re.sub(r'\bLocator\b', 'AppLocator', content)
            
            if new_content != content:
                with open(filepath, 'w') as f:
                    f.write(new_content)
                count += 1
                print(f"Updated {filepath}")

print(f"Finished updating {count} files.")
