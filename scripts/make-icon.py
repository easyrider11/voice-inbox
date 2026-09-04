#!/usr/bin/env python3
"""Generate the app icon set: day (orange ground, white mic) and the iOS 18
dark-appearance variant (black ground, yellow mic). Writes straight into the
asset catalog. Requires Pillow.

    python3 scripts/make-icon.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "ios/VoiceInbox/Assets.xcassets/AppIcon.appiconset"
SIZE = 1024

ORANGE = (255, 140, 26)
YELLOW = (255, 214, 10)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)


def draw_mic(draw: ImageDraw.ImageDraw, color: tuple[int, int, int]) -> None:
    cx = SIZE // 2
    stroke = 58
    # Capsule
    draw.rounded_rectangle((cx - 110, 250, cx + 110, 600), radius=110, fill=color)
    # Cradle arc (bottom half of a circle around the capsule)
    draw.arc((cx - 205, 300, cx + 205, 710), start=0, end=180, fill=color, width=stroke)
    for x in (cx - 205 + stroke // 2, cx + 205 - stroke // 2):
        draw.ellipse((x - stroke // 2, 505 - stroke // 2, x + stroke // 2, 505 + stroke // 2), fill=color)
    # Stem + base
    draw.line((cx, 700, cx, 790), fill=color, width=stroke)
    draw.line((cx - 120, 790, cx + 120, 790), fill=color, width=stroke)
    for x in (cx - 120, cx + 120):
        draw.ellipse((x - stroke // 2, 790 - stroke // 2, x + stroke // 2, 790 + stroke // 2), fill=color)


def render(ground: tuple[int, int, int], glyph: tuple[int, int, int], name: str) -> None:
    image = Image.new("RGB", (SIZE, SIZE), ground)
    draw_mic(ImageDraw.Draw(image), glyph)
    image.save(ICONSET / name, "PNG")


def main() -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    render(ORANGE, WHITE, "AppIcon.png")
    render(BLACK, YELLOW, "AppIcon-Dark.png")
    contents = {
        "images": [
            {"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "filename": "AppIcon-Dark.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (ICONSET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"wrote AppIcon.png + AppIcon-Dark.png to {ICONSET}")


if __name__ == "__main__":
    main()
