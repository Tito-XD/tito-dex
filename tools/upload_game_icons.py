#!/usr/bin/env python3
"""Build and upload game edition icons.

For editions with an official HOME-style icon in
flutter/assets/game_icons/{icon_slug}.png, that asset is uploaded directly.
For older editions without an official icon, a styled fallback badge is
rendered from the edition's theme color and generation/abbreviation label.
"""

from __future__ import annotations

import io
import subprocess
import sys
from pathlib import Path
from typing import cast

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_dex_bundle import GAME_EDITIONS, GameEdition, optimize_png  # noqa: E402

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

# Cleaner fallback labels for editions without official icons.
FALLBACK_LABELS: dict[str, str] = {
    "red-blue": "I",
    "yellow": "Y",
    "gold-silver": "II",
    "crystal": "C",
    "ruby-sapphire": "III",
    "emerald": "E",
    "firered-leafgreen": "FRLG",
    "diamond-pearl": "IV",
    "platinum": "Pt",
    "heartgold-soulsilver": "HGSS",
    "black-white": "V",
    "black-2-white-2": "B2W2",
}


def _find_bold_font() -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    """Return a good-looking bold font, falling back to the default bitmap font."""
    candidates = [
        ("/System/Library/Fonts/Helvetica.ttc", 0),
        ("/System/Library/Fonts/HelveticaNeue.ttc", 0),
        ("/Library/Fonts/Arial Bold.ttf", None),
        ("/Library/Fonts/Arial.ttf", None),
        ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", None),
    ]
    for path, index in candidates:
        file_path = Path(path)
        if not file_path.exists():
            continue
        try:
            if index is not None and file_path.suffix.lower() == ".ttc":
                return ImageFont.truetype(path, 16, index=index)
            return ImageFont.truetype(path, 16)
        except OSError:
            continue
    return ImageFont.load_default()


_BOLD_FONT = _find_bold_font()


def _hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def _lerp_channel(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def _adjust_brightness(hex_color: str, factor: float) -> str:
    """Lighten (factor > 0) or darken (factor < 0) a hex color."""
    r, g, b = _hex_to_rgb(hex_color)
    if factor > 0:
        r = _lerp_channel(r, 255, factor)
        g = _lerp_channel(g, 255, factor)
        b = _lerp_channel(b, 255, factor)
    else:
        t = -factor
        r = _lerp_channel(r, 0, t)
        g = _lerp_channel(g, 0, t)
        b = _lerp_channel(b, 0, t)
    return f"#{r:02x}{g:02x}{b:02x}"


def _draw_rounded_gradient(
    draw: ImageDraw.ImageDraw,
    image: Image.Image,
    bounds: tuple[int, int, int, int],
    radius: int,
    top_color: str,
    bottom_color: str,
) -> None:
    """Draw a vertical gradient inside a rounded rectangle via mask."""
    width = bounds[2] - bounds[0]
    height = bounds[3] - bounds[1]
    gradient = Image.new("RGBA", (width, height))
    for y in range(height):
        t = y / max(height - 1, 1)
        tr, tg, tb = _hex_to_rgb(top_color)
        br, bg, bb = _hex_to_rgb(bottom_color)
        r = _lerp_channel(tr, br, t)
        g = _lerp_channel(tg, bg, t)
        b = _lerp_channel(tb, bb, t)
        for x in range(width):
            gradient.putpixel((x, y), (r, g, b, 255))
    mask = Image.new("L", (width, height), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    image.paste(gradient, bounds, mask)


def _make_fallback_icon(edition: GameEdition) -> bytes:
    size = 64
    pad = 4
    radius = 12
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    color = ICON_COLORS.get(edition.icon_slug, "#607D8B")
    top_color = _adjust_brightness(color, 0.18)
    bottom_color = _adjust_brightness(color, -0.15)
    shadow_color = (0, 0, 0, 55)
    border_color = (255, 255, 255, 55)
    highlight_color = (255, 255, 255, 35)

    # Soft shadow.
    draw.rounded_rectangle(
        (pad + 2, pad + 2, size - pad + 2, size - pad + 2),
        radius=radius,
        fill=shadow_color,
    )

    # Gradient body.
    _draw_rounded_gradient(
        draw,
        image,
        (pad, pad, size - pad, size - pad),
        radius,
        top_color,
        bottom_color,
    )

    # Inset border.
    draw.rounded_rectangle(
        (pad + 1, pad + 1, size - pad - 1, size - pad - 1),
        radius=radius - 1,
        outline=border_color,
        width=2,
    )

    # Top edge highlight.
    draw.rounded_rectangle(
        (pad + 3, pad + 2, size - pad - 3, pad + 5),
        radius=3,
        fill=highlight_color,
    )

    text = FALLBACK_LABELS.get(edition.icon_slug, edition.icon_slug.split("-")[0][:3].upper())
    font_size = 26 if len(text) <= 2 else (18 if len(text) == 3 else 14)
    try:
        if isinstance(_BOLD_FONT, ImageFont.FreeTypeFont):
            font = ImageFont.truetype(cast(str, _BOLD_FONT.path), font_size)
        else:
            font = _BOLD_FONT
    except OSError:
        font = _BOLD_FONT

    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(
        ((size - tw) / 2, (size - th) / 2 - 1),
        text,
        fill=(255, 255, 255, 245),
        font=font,
        stroke_width=1,
        stroke_fill=(0, 0, 0, 90),
    )

    buf = io.BytesIO()
    image.save(buf, format="PNG", optimize=True)
    return optimize_png(buf.getvalue(), max_width=64)


def _build_icon(edition: GameEdition) -> bytes:
    asset_path = ROOT / "flutter" / "assets" / "game_icons" / f"{edition.icon_slug}.png"
    if asset_path.exists():
        return optimize_png(asset_path.read_bytes(), max_width=64)
    return _make_fallback_icon(edition)


def main() -> None:
    out_dir = ROOT / "dist" / "dex-v9" / "upload" / "v5" / "game_icons"
    out_dir.mkdir(parents=True, exist_ok=True)
    for edition in GAME_EDITIONS:
        png = _build_icon(edition)
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
