#!/usr/bin/env python3
"""Generate per-flavor game icons for editions with multiple versions.

For the primary flavor we reuse the existing bundled official icon (e.g.
xy.png -> x.png). For secondary flavors we download the real per-version icon
from Nintendo's public servers:

- Switch titles: tinfoil.media serves the official 1024x1024 title icon.
- 3DS titles: idbe-ctr.cdn.nintendo.net serves an encrypted IDBE blob; we
  decrypt it with the public nn_idbe AES keys and extract the 48x48 RGB565
  icon (8x8 tiled).

The output is a 64x64 rounded-square PNG so all flavors share the same shape
and shadow treatment as the bundled primary icons.
"""

from __future__ import annotations

import io
import subprocess
import sys
from pathlib import Path
from typing import cast

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_dex_bundle import GAME_EDITIONS, GameEdition, optimize_png  # noqa: E402

ASSET_DIR = ROOT / "flutter" / "assets" / "game_icons"
UPLOAD_DIR = ROOT / "dist" / "dex-v9" / "upload" / "v5" / "game_icons"

# Title IDs for per-flavor official icons.  Only editions with distinct
# per-version artwork need entries here; single-flavor editions fall back to
# the bundled edition slug icon.
FLAVOR_TITLE_IDS: dict[str, tuple[str, str]] = {
    # 3DS
    "x": ("3ds", "0004000000055D00"),
    "y": ("3ds", "0004000000055E00"),
    "omega-ruby": ("3ds", "000400000011C400"),
    "alpha-sapphire": ("3ds", "000400000011C500"),
    "sun": ("3ds", "0004000000164800"),
    "moon": ("3ds", "0004000000175E00"),
    "ultra-sun": ("3ds", "00040000001B5000"),
    "ultra-moon": ("3ds", "00040000001B5100"),
    # Switch
    "lets-go-pikachu": ("switch", "010003F003A34000"),
    "lets-go-eevee": ("switch", "0100187003A36000"),
    "sword": ("switch", "0100ABF008968000"),
    "shield": ("switch", "01008DB008C2C000"),
    "brilliant-diamond": ("switch", "0100000011D90000"),
    "shining-pearl": ("switch", "010018E011D92000"),
    "legends-arceus": ("switch", "01001F5010DFA000"),
    "scarlet": ("switch", "0100A3D008C5C000"),
    "violet": ("switch", "01008F6008C5E000"),
}

# Public nn_idbe AES constants (from nn_idbe.rpl .rodata+0x4c).
IDBE_IV = bytes.fromhex("A46987AE47D82BB4FA8ABC0450285FA4")
IDBE_KEYS = [
    bytes.fromhex(k)
    for k in (
        "4AB9A40E146975A84BB1B4F3ECEFC47B",
        "90A0BB1E0E864AE87D13A6A03D28C9B8",
        "FFBB57C14E98EC6975B384FCF40786B5",
        "80923799B41F36A6A75FB8B48C95F66F",
    )
]

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


def _http_get(url: str) -> bytes | None:
    import urllib.request
    import urllib.error
    import ssl
    import time

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/126.0.0.0 Safari/537.36"
            ),
        },
    )
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
                return response.read()
        except urllib.error.HTTPError as exc:
            if exc.code >= 500 and attempt < 2:
                time.sleep(0.5 * (attempt + 1))
                continue
            print(f"  warn: fetch failed {url}: {exc}", file=sys.stderr)
            return None
        except Exception as exc:
            print(f"  warn: fetch failed {url}: {exc}", file=sys.stderr)
            return None
    return None


def _download_switch_icon(title_id: str) -> Image.Image | None:
    url = f"https://tinfoil.media/ti/{title_id}/0/0/"
    data = _http_get(url)
    if data is None:
        return None
    try:
        return Image.open(io.BytesIO(data)).convert("RGBA")
    except Exception as exc:
        print(f"  warn: cannot open Switch icon for {title_id}: {exc}", file=sys.stderr)
        return None


def _download_3ds_icon(title_id: str) -> Image.Image | None:
    url = f"https://idbe-ctr.cdn.nintendo.net/icondata/10/{title_id}.idbe"
    data = _http_get(url)
    if data is None:
        return None
    if len(data) < 2:
        return None
    key_index = data[1]
    if key_index >= len(IDBE_KEYS):
        print(f"  warn: unknown key index {key_index} for {title_id}", file=sys.stderr)
        return None
    try:
        from Crypto.Cipher import AES
    except ImportError as exc:
        print(
            f"  warn: pycryptodome required for 3DS icon decryption: {exc}",
            file=sys.stderr,
        )
        return None
    cipher = AES.new(IDBE_KEYS[key_index], AES.MODE_CBC, IDBE_IV)
    decrypted = cipher.decrypt(data[2:])
    # Decrypted layout: 0x20 SHA256, 0x50 header, 0x200*16 title strings,
    # then 24x24 RGB565 at 0x2050 and 48x48 RGB565 at 0x24D0.
    icon_offset = 0x24D0
    icon_size = 48 * 48 * 2
    if len(decrypted) < icon_offset + icon_size:
        print(f"  warn: decrypted IDBE too short for {title_id}", file=sys.stderr)
        return None
    raw = decrypted[icon_offset : icon_offset + icon_size]
    return _decode_rgb565_tiled(raw, 48, 48)


def _decode_rgb565_tiled(raw: bytes, width: int, height: int) -> Image.Image:
    """Decode a 3DS RGB565 icon stored as 8x8 tiles."""
    image = Image.new("RGBA", (width, height))
    tile_size = 8
    tiles_x = width // tile_size
    tiles_y = height // tile_size
    idx = 0
    for ty in range(tiles_y):
        for tx in range(tiles_x):
            for y in range(tile_size):
                for x in range(tile_size):
                    px = tx * tile_size + x
                    py = ty * tile_size + y
                    value = raw[idx] | (raw[idx + 1] << 8)
                    idx += 2
                    r = ((value >> 11) & 0x1F) << 3
                    g = ((value >> 5) & 0x3F) << 2
                    b = (value & 0x1F) << 3
                    image.putpixel((px, py), (r, g, b, 255))
    return image


def _render_rounded_icon(source: Image.Image) -> bytes:
    size = 64
    radius = 12
    # Resize using Lanczos to keep crisp edges on the 48x48 3DS icons.
    resized = source.resize((size, size), Image.Resampling.LANCZOS)

    # Build a rounded mask.
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)

    # Composite onto a transparent canvas with a soft drop shadow.
    canvas = Image.new("RGBA", (size + 4, size + 4), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 55))
    shadow.putalpha(mask)
    canvas.paste(shadow, (2, 2), shadow)

    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.paste(resized, (0, 0), mask)
    canvas.paste(icon, (0, 0), icon)

    buf = io.BytesIO()
    canvas.save(buf, format="PNG", optimize=True)
    return optimize_png(buf.getvalue(), max_width=64)


def _download_official_icon(flavor: str) -> bytes | None:
    mapping = FLAVOR_TITLE_IDS.get(flavor)
    if mapping is None:
        return None
    platform, title_id = mapping
    print(f"  downloading {platform} icon for {flavor} ({title_id})...")
    if platform == "switch":
        image = _download_switch_icon(title_id)
    else:
        image = _download_3ds_icon(title_id)
    if image is None:
        return None
    return _render_rounded_icon(image)


def _build_flavor_icon(edition: GameEdition, flavor: str) -> bytes:
    flavors = list(edition.flavor_versions)
    if flavors and flavors[0] == flavor:
        # Primary flavor: reuse the bundled official merged icon.
        source = ASSET_DIR / f"{edition.slug}.png"
        if source.exists():
            return optimize_png(source.read_bytes(), max_width=64)

    # Secondary flavor: try an official per-version icon first.
    official = _download_official_icon(flavor)
    if official is not None:
        return official

    # Fallback to the generated badge so the UI never breaks.
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
