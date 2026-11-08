#!/usr/bin/env python3
"""Generate Partwk branding assets from the supplied PNG without redrawing it."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'assets/images/partwk_new_source.png'
OUT = ROOT / 'assets/images'
PREVIEW = ROOT / 'scratch/branding_previews'
PREVIEW.mkdir(parents=True, exist_ok=True)

source = Image.open(SOURCE).convert('RGBA')
bounds = source.getchannel('A').getbbox()
if not bounds:
    raise ValueError('The supplied image is fully transparent')
emblem = source.crop(bounds)
emblem.save(OUT / 'partwk_emblem.png', optimize=True)
emblem.save(ROOT / 'admin_panel/public/email_logo.png', optimize=True)

def canvas(size, width_fraction, background):
    result = Image.new('RGBA', (size, size), background)
    width = round(size * width_fraction)
    height = round(width * emblem.height / emblem.width)
    logo = emblem.resize((width, height), Image.Resampling.LANCZOS)
    result.alpha_composite(logo, ((size - width) // 2, (size - height) // 2))
    return result

# The supplied emblem's visible pixels fit inside Android's 66/108 safe circle.
foreground = canvas(1024, .52, (0, 0, 0, 0))
foreground.save(OUT / 'app_icon_foreground.png', optimize=True)
ios = canvas(1024, .73, (255, 255, 255, 255)).convert('RGB')
ios.save(OUT / 'app_icon_ios.png', optimize=True)
ios.resize((512, 512), Image.Resampling.LANCZOS).save(PREVIEW / 'ios-square-preview.png')

# Android displays a masked central 72/108 viewport of the 108dp layer.
composite = Image.new('RGBA', (1024, 1024), 'white')
composite.alpha_composite(foreground)
viewport = composite.crop((171, 171, 853, 853)).resize((512, 512), Image.Resampling.LANCZOS)
for shape in ('circle', 'squircle', 'rounded_square', 'square'):
    mask = Image.new('L', (512, 512), 0)
    draw = ImageDraw.Draw(mask)
    if shape == 'circle':
        draw.ellipse((0, 0, 511, 511), fill=255)
    elif shape == 'squircle':
        # Superellipse is an approximation; launcher implementations may vary.
        pixels = mask.load()
        for y in range(512):
            for x in range(512):
                if abs((x - 255.5) / 255.5) ** 4 + abs((y - 255.5) / 255.5) ** 4 <= 1:
                    pixels[x, y] = 255
    elif shape == 'rounded_square':
        draw.rounded_rectangle((0, 0, 511, 511), radius=110, fill=255)
    else:
        draw.rectangle((0, 0, 511, 511), fill=255)
    result = viewport.copy()
    result.putalpha(mask)
    result.save(PREVIEW / f'android-{shape}-preview.png')

print(f'Source {source.size}; visible bounds {bounds}; emblem {emblem.size}')
