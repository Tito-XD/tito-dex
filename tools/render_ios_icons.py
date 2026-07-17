#!/usr/bin/env python3
"""Render TitoDex iOS AppIcon set + launch placeholders from the Android
adaptive-icon vector geometry (single source of truth:
flutter/android/app/src/main/res/drawable/ic_launcher_foreground.xml).

Usage: python3 tools/render_ios_icons.py   (run from repo root, needs Pillow)

The 108x108 viewport: top half #4A90E2, bottom half #2C313A, white band
y50-58, white circle r13 + blue circle r8 centered at (54,54). iOS icons are
full-bleed squares (no alpha); the system applies the rounded mask.
"""
from pathlib import Path

from PIL import Image, ImageDraw

BLUE = (74, 144, 226)  # #4A90E2
DARK = (44, 49, 58)  # #2C313A
WHITE = (245, 247, 250)  # #F5F7FA

REPO = Path(__file__).resolve().parent.parent
APPICON_DIR = REPO / "flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset"
LAUNCH_DIR = REPO / "flutter/ios/Runner/Assets.xcassets/LaunchImage.imageset"


def render(size: int) -> Image.Image:
    ss = 4  # supersample for crisp edges
    big = size * ss
    u = big / 108.0
    img = Image.new("RGB", (big, big))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, big, 54 * u], fill=BLUE)
    d.rectangle([0, 54 * u, big, big], fill=DARK)
    d.rectangle([0, 50 * u, big, 58 * u], fill=WHITE)
    c = 54 * u
    r_outer, r_inner = 13 * u, 8 * u
    d.ellipse([c - r_outer, c - r_outer, c + r_outer, c + r_outer], fill=WHITE)
    d.ellipse([c - r_inner, c - r_inner, c + r_inner, c + r_inner], fill=BLUE)
    return img.resize((size, size), Image.LANCZOS)


ICON_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def main() -> None:
    for name, px in ICON_SIZES.items():
        render(px).save(APPICON_DIR / name)
        print(f"wrote {name} ({px}px)")
    # Launch images: transparent placeholders; LaunchScreen.storyboard paints
    # the solid deep-blue background (matches Android launch_background).
    for name in ("LaunchImage.png", "LaunchImage@2x.png", "LaunchImage@3x.png"):
        Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(LAUNCH_DIR / name)
        print(f"wrote {name} (transparent)")


if __name__ == "__main__":
    main()
