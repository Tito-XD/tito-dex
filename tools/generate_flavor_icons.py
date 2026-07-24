#!/usr/bin/env python3
"""Generate per-flavor game icons for editions with multiple versions.

For the primary flavor we reuse the existing bundled official icon (e.g.
xy.png -> x.png). For secondary flavors we render a matching badge so
X/Y, Sword/Shield, etc. show distinct art in the flavor picker.
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

ASSET_DIR = ROOT / "flutter" / "assets" / "game_icons"
UPLOAD_DIR = ROOT / "dist" / "dex-v9" / "upload" / "v5" / "game_icons"

FLAVOR_LABELS: dict[str, str] = {
    "y": "Y",
    "alpha-sapphire": "α",
    "moon": "M",
    "ultra-moon": "UM",
    "lets-go-eevee": "E",
    "shield": "Sh",
    "shining-pearl": "SP",
    "violet": "V",
    "mega-dimension": "MD",
}

FLAVOR_COLORS: dict[str, str] = {
    "y": "#C2185B",
    "alpha-sapphire": "#1565C0",
    "moon": "#6A1B9A",
    "ultra-moon": "#4A148C",
    "lets-go-eevee": "#8D6E63",
    "shield": "#C62828",
    "shining-pearl": "#D81B60",
    "violet": "#7B1FA2",
    "mega-dimension": "#455A64",
}


def _find_bold_font() -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
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
    image: Image.Image,
    bounds: tuple[int, int, int, int],
    radius: int,
    top_color: str,
    bottom_color: str,
) -> None:
    width = bounds[2] - bounds[0]
    height = bounds[3] - bounds[1]
    gradient = Image.new("RGBA", (width, height))
    tr, tg, tb = _hex_to_rgb(top_color)
    br, bg, bb = _hex_to_rgb(bottom_color)
    for y in range(height):
        t = y / max(height - 1, 1)
        r = _lerp_channel(tr, br, t)
        g = _lerp_channel(tg, bg, t)
        b = _lerp_channel(tb, bb, t)
        for x in range(width):
            gradient.putpixel((x, y), (r, g, b, 255))
    mask = Image.new("L", (width, height), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    image.paste(gradient, bounds, mask)


def _make_badge(flavor: str) -> bytes:
    size = 64
    pad = 4
    radius = 12
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    color = FLAVOR_COLORS.get(flavor, "#607D8B")
    top_color = _adjust_brightness(color, 0.18)
    bottom_color = _adjust_brightness(color, -0.15)
    shadow_color = (0, 0, 0, 55)
    border_color = (255, 255, 255, 55)
    highlight_color = (255, 255, 255, 35)

    draw.rounded_rectangle(
        (pad + 2, pad + 2, size - pad + 2, size - pad + 2),
        radius=radius,
        fill=shadow_color,
    )
    _draw_rounded_gradient(
        image,
        (pad, pad, size - pad, size - pad),
        radius,
        top_color,
        bottom_color,
    )
    draw.rounded_rectangle(
        (pad + 1, pad + 1, size - pad - 1, size - pad - 1),
        radius=radius - 1,
        outline=border_color,
        width=2,
    )
    draw.rounded_rectangle(
        (pad + 3, pad + 2, size - pad - 3, pad + 5),
        radius=3,
        fill=highlight_color,
    )

    text = FLAVOR_LABELS.get(flavor, flavor[:2].upper())
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


def _build_flavor_icon(edition: GameEdition, flavor: str) -> bytes:
    flavors = list(edition.flavor_versions)
    if flavors and flavors[0] == flavor:
        # Primary flavor: reuse the bundled official merged icon.
        source = ASSET_DIR / f"{edition.slug}.png"
        if source.exists():
            return optimize_png(source.read_bytes(), max_width=64)
    # Secondary flavor: generate a badge.
    return _make_badge(flavor)


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

    generated: list[tuple[str, bytes]] = []
    for edition in GAME_EDITIONS:
        if len(edition.flavor_versions) <= 1:
            continue
        for flavor in edition.flavor_versions:
            png = _build_flavor_icon(edition, flavor)
            filename = f"{flavor}.png"
            (ASSET_DIR / filename).write_bytes(png)
            (UPLOAD_DIR / filename).write_bytes(png)
            generated.append((filename, png))
            print(f"→ {filename} ({len(png)} bytes)")

    print(f"\nGenerated {len(generated)} flavor icons.")


if __name__ == "__main__":
    main()
