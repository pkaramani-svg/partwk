import base64
from PIL import Image

img = Image.open('../assets/images/partwk_logo_transparent.png')
# Resize to 200px width, keeping aspect ratio
wpercent = (200 / float(img.size[0]))
hsize = int((float(img.size[1]) * float(wpercent)))
img = img.resize((200, hsize), Image.Resampling.LANCZOS)
img.save('logo_small.png')

with open("logo_small.png", "rb") as image_file:
    encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
    with open("logo_base64.txt", "w") as f:
        f.write(encoded_string)
