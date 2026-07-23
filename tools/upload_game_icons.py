#!/usr/bin/env python3
"""Build and upload game edition icons when PokeAPI /version/ sprites are absent."""

from __future__ import annotations

import io
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_dex_bundle import GAME_EDITIONS, optimize_png  # noqa: E402

ICON_COLORS = {
    "red-blue": "#E3350D",
    "yellow": "#FFCB05",
    "gold-silver": "#C0A000",
    "crystal": "#4FC3F7",
    "ruby-sapphire": "#C62828",
    "emerald": "#2E7D32",
    "firered-leafgreen": "#D84315",
    "diamond-pearl": "#5C6BC0",
    "platinum": "#78909C",
    "heartgold-soulsilver": "#FFB300",
    "black-white": "#424242",
    "black-2-white-2": "#616161",
    "x-y": "#1565C0",
    "omega-ruby-alpha-sapphire": "#AD1457",
    "sun-moon": "#F57C00",
    "ultra-sun-ultra-moon": "#EF6C00",
    "lets-go-pikachu-lets-go-eevee": "#FBC02D",
    "sword-shield": "#283593",
    "brilliant-diamond-shining-pearl": "#26A69A",
    "legends-arceus": "#6D4C41",
    "scarlet-violet": "#7B1FA2",
    "lza": "#9E9E9E",
    "champions": "#455A64",
}


def make_icon(slug: str, label: str) -> bytes:
    size = 64
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    color = ICON_COLORS.get(slug, "#607D8B")
    draw.rounded_rectangle((4, 4, size - 4, size - 4), radius=10, fill=color)
    text = slug.split("-")[0][:3].upper()
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((size - tw) / 2, (size - th) / 2 - 2), text, fill="white", font=font)
    buf = io.BytesIO()
    image.save(buf, format="PNG", optimize=True)
    return optimize_png(buf.getvalue(), max_width=64)


def main() -> None:
    out_dir = ROOT / "dist" / "dex-v7" / "upload" / "v5" / "game_icons"
    out_dir.mkdir(parents=True, exist_ok=True)
    for edition in GAME_EDITIONS:
        png = make_icon(edition.icon_slug, edition.label_zh)
        path = out_dir / f"{edition.icon_slug}.png"
        path.write_bytes(png)
        key = f"v5/game_icons/{edition.icon_slug}.png"
        subprocess.run(
            [
                "npx",
                "wrangler",
                "r2",
                "object",
                "put",
                f"titodex-dex/{key}",
                f"--file={path}",
                "--remote",
                "--content-type=image/png",
            ],
            check=True,
            cwd=ROOT / "cloudflare" / "dex-cdn",
        )
        print(f"→ {key}")


if __name__ == "__main__":
    main()
