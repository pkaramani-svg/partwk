from PIL import Image
import sys

def process_image(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    data = img.load()
    width, height = img.size

    visited = set()
    stack = [(0,0), (width-1,0), (0,height-1), (width-1,height-1)]

    def is_white(r, g, b):
        return r > 240 and g > 240 and b > 240

    while stack:
        x, y = stack.pop()
        if (x, y) in visited:
            continue
        visited.add((x, y))

        r, g, b, a = data[x, y]
        if is_white(r, g, b):
            data[x, y] = (255, 255, 255, 0)
            
            for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < width and 0 <= ny < height:
                    stack.append((nx, ny))

    img.save(output_path, "PNG")
    print(f"Saved processed image to {output_path}")

process_image(sys.argv[1], sys.argv[2])
