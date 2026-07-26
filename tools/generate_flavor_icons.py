#!/usr/bin/env python3
"""Generate the complete TitoDex game icon set from official sources.

Source of truth (2026-07-25, confirmed with the project owner):

- Gen 6+ flavors, merged edition slugs, and single editions (PLA, Z-A,
  Champions): Pokémon HOME game icons via Bulbagarden archives
  (128x128 PNG, one consistent family). Any file resolves through
  https://archives.bulbagarden.net/wiki/Special:FilePath/<name>.
- Gen 1-5 flavors: Nintendo DS/3DS launch icons via SteamGridDB
  (cdn2.steamgriddb.com/icon/<hash>.png).
- No official game icon exists for white-2 (SteamGridDB has no usable
  direct link) or mega-dimension (no HOME icon): fall back to a Pokémon
  artwork badge per the "game icon first, Pokémon as fallback" rule.

Output: 64x64 rounded-square PNGs into flutter/assets/game_icons/ plus the
merged-slug CDN set (dist/game_icons_upload/v5/game_icons/) for the flavor
text rows that load https://dex.tito.cafe/v5/game_icons/<slug>.png.
"""

from __future__ import annotations

import io
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_dex_bundle import optimize_png  # noqa: E402

ASSET_DIR = ROOT / "flutter" / "assets" / "game_icons"
CDN_DIR = ROOT / "dist" / "game_icons_upload" / "v5" / "game_icons"
DOWNLOAD_CACHE = ROOT / "tools" / ".icon_cache"

BULBA_FILE = "https://archives.bulbagarden.net/media/upload/{}"
SGDB_FILE = "https://cdn2.steamgriddb.com/icon/{}.png"
POKEAPI_ART = (
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/"
    "sprites/pokemon/other/official-artwork/{}.png"
)

# Gen 6+ flavors (and single editions) -> Pokémon HOME icon path under
# /media/upload/ (wiki pages are Cloudflare-blocked for non-curl clients,
# but direct media links work). Any new name resolves via
# https://archives.bulbagarden.net/wiki/Special:FilePath/HOME_<Name>_icon.png
HOME_ICONS: dict[str, str] = {
    "x": "7/73/HOME_X_icon.png",
    "y": "d/d5/HOME_Y_icon.png",
    "omega-ruby": "b/b7/HOME_Omega_Ruby_icon.png",
    "alpha-sapphire": "e/e3/HOME_Alpha_Sapphire_icon.png",
    "sun": "7/7c/HOME_Sun_icon.png",
    "moon": "2/25/HOME_Moon_icon.png",
    "ultra-sun": "b/be/HOME_Ultra_Sun_icon.png",
    "ultra-moon": "b/bb/HOME_Ultra_Moon_icon.png",
    "lets-go-pikachu": "1/19/HOME_Let%27s_Go_Pikachu_icon.png",
    "lets-go-eevee": "3/3f/HOME_Let%27s_Go_Eevee_icon.png",
    "sword": "f/fe/HOME_Sword_icon.png",
    "shield": "c/c8/HOME_Shield_icon.png",
    "brilliant-diamond": "c/cf/HOME_Brilliant_Diamond_icon.png",
    "shining-pearl": "7/75/HOME_Shining_Pearl_icon.png",
    "scarlet": "2/29/HOME_Scarlet_icon.png",
    "violet": "9/92/HOME_Violet_icon.png",
    "legends-arceus": "b/ba/HOME_Legends_Arceus_icon.png",
    "legends-za": "4/4c/HOME_Legends_Z-A_icon.png",
    "champions": "6/65/HOME_Champions_icon.png",
}

# Gen 1-5 flavors -> SteamGridDB image hash (from the icon page URL).
SGDB_ICONS: dict[str, str] = {
    "red": "ef8ff3bb5f926198d139c3e9750a3739",
    "blue": "e4e13c3ff0c5a77ff11d6cb979ba7187",
    "yellow": "9cb9c75c1489b79a085eb7f56d82f2bf",
    "gold": "c98e1bdd3a3a02c4c664baf039cf630b",
    "silver": "4d88df11c5d0c37fe147eb1d94f1a06b",
    "crystal": "9052eeb1dacdc32a450c59a90121fe66",
    "ruby": "243153b1d3e9aae08821d40e3b402ffe",
    "sapphire": "31482ea3105f2635db24a0077677930f",
    "emerald": "5d12d5a76a9683536eb23a6a1c9767cc",
    "firered": "a7c1543e35a5fbc383363e39ccb7701d",
    "leafgreen": "e736598ba2c84d7313c8614de041cae3",
    "diamond": "c1ba099b22d65b3903891b885dc686f9",
    "pearl": "a979ca2444b34449a2c80b012749e9cd",
    "platinum": "691f73fdf1c5edeb3f600c515715a358",
    "heartgold": "33abbac390f933b4d29d1ccae857ea98",
    "soulsilver": "1a371879ae7ae905850d5dee733f303e",
    "black": "8d65294979cf7c59fa43f91f993fb5c2",
    "white": "5b97f793636f8baec3ff8cd0ebf5c33c",
    "black-2": "f4cbadcb99fd2c1fc88b97adfae24854",
}

# Flavors with no official game icon -> (PokeAPI official-artwork id, bg top,
# bg bottom). The mascot of the version/DLC.
FALLBACK_ART_BADGES: dict[str, tuple[int, str, str]] = {
    "white-2": (10023, "#8FB4D9", "#4E6E96"),  # Black Kyurem, icy gradient
    "mega-dimension": (491, "#4A3A72", "#241E3E"),  # Darkrai, hyperspace night
}

# Merged edition slug -> flavor whose icon represents the merged entry.
MERGED_TO_FLAVOR: dict[str, str] = {
    # app slug icons (assets)
    "xy": "x",
    "oras": "omega-ruby",
    "sm": "sun",
    "usum": "ultra-sun",
    "lgpe": "lets-go-pikachu",
    "swsh": "sword",
    "bdsp": "brilliant-diamond",
    "pla": "legends-arceus",
    "sv": "scarlet",
    "lza": "legends-za",
    "champions": "champions",
}

# CDN merged-slug file names (games.json + flavor text iconUrl) -> flavor.
CDN_TO_FLAVOR: dict[str, str] = {
    "red-blue": "red",
    "yellow": "yellow",
    "gold-silver": "gold",
    "crystal": "crystal",
    "ruby-sapphire": "ruby",
    "emerald": "emerald",
    "firered-leafgreen": "firered",
    "diamond-pearl": "diamond",
    "platinum": "platinum",
    "heartgold-soulsilver": "heartgold",
    "black-white": "black",
    "black-2-white-2": "black-2",
    "x-y": "x",
    "omega-ruby-alpha-sapphire": "omega-ruby",
    "sun-moon": "sun",
    "ultra-sun-ultra-moon": "ultra-sun",
    "lets-go-pikachu-lets-go-eevee": "lets-go-pikachu",
    "sword-shield": "sword",
    "brilliant-diamond-shining-pearl": "brilliant-diamond",
    "legends-arceus": "legends-arceus",
    "scarlet-violet": "scarlet",
    "lza": "legends-za",
    "champions": "champions",
}


def _http_get(url: str) -> bytes | None:
    # Bulbagarden's Cloudflare throttles bursts aggressively; cache every
    # download on disk so retries and re-runs never re-fetch.
    import hashlib

    cache_key = hashlib.sha1(url.encode()).hexdigest()[:16]
    cache_path = DOWNLOAD_CACHE / f"{cache_key}.bin"
    if cache_path.is_file():
        return cache_path.read_bytes()

    for attempt in range(4):
        try:
            # Bulbagarden's Cloudflare is picky: HTTP/1.1 with a bare
            # "Mozilla/5.0" UA passes; HTTP/2 resets and browser-looking UAs
            # without a matching TLS fingerprint get 403/connection resets.
            result = subprocess.run(
                ["curl", "-sfL", "--http1.1", "-A", "Mozilla/5.0", url],
                capture_output=True,
                timeout=60,
            )
        except subprocess.TimeoutExpired:
            print(f"  warn: fetch timeout {url}", file=sys.stderr)
            return None
        if result.returncode == 0 and result.stdout:
            DOWNLOAD_CACHE.mkdir(parents=True, exist_ok=True)
            cache_path.write_bytes(result.stdout)
            return result.stdout
        if attempt < 3:
            # Bulbagarden rate-limits bursts; back off generously.
            time.sleep(4.0 * (attempt + 1))
    print(f"  warn: fetch failed {url}", file=sys.stderr)
    return None


def _hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def _render_rounded_icon(source: Image.Image) -> bytes:
    """Resize to 64x64 and clip to the shared rounded-square shape."""
    size = 64
    radius = 12
    resized = source.resize((size, size), Image.Resampling.LANCZOS)

    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(resized, (0, 0), mask)

    buf = io.BytesIO()
    canvas.save(buf, format="PNG", optimize=True)
    return optimize_png(buf.getvalue(), max_width=64)


def _download_image(url: str) -> Image.Image | None:
    data = _http_get(url)
    # Pace requests: Bulbagarden 403s bursts even from curl.
    time.sleep(3.0)
    if data is None:
        return None
    try:
        return Image.open(io.BytesIO(data)).convert("RGBA")
    except Exception as exc:
        print(f"  warn: cannot decode {url}: {exc}", file=sys.stderr)
        return None


def _gradient_background(size: int, top: str, bottom: str) -> Image.Image:
    top_rgb, bottom_rgb = _hex_to_rgb(top), _hex_to_rgb(bottom)
    image = Image.new("RGBA", (size, size))
    for y in range(size):
        t = y / max(size - 1, 1)
        rgb = tuple(int(top_rgb[c] + (bottom_rgb[c] - top_rgb[c]) * t) for c in range(3))
        for x in range(size):
            image.putpixel((x, y), (*rgb, 255))
    return image


def _build_art_badge(pokemon_id: int, top: str, bottom: str) -> bytes | None:
    art = _download_image(POKEAPI_ART.format(pokemon_id))
    if art is None:
        return None
    size = 64
    background = _gradient_background(size, top, bottom)
    padded = art.copy()
    padded.thumbnail((size - 10, size - 10), Image.Resampling.LANCZOS)
    background.paste(
        padded,
        ((size - padded.width) // 2, (size - padded.height) // 2),
        padded,
    )
    return _render_rounded_icon(background)


def _flavor_png(flavor: str) -> bytes | None:
    if flavor in HOME_ICONS:
        image = _download_image(BULBA_FILE.format(HOME_ICONS[flavor]))
        if image is not None:
            return _render_rounded_icon(image)
    if flavor in SGDB_ICONS:
        image = _download_image(SGDB_FILE.format(SGDB_ICONS[flavor]))
        if image is not None:
            return _render_rounded_icon(image)
    if flavor in FALLBACK_ART_BADGES:
        pokemon_id, top, bottom = FALLBACK_ART_BADGES[flavor]
        return _build_art_badge(pokemon_id, top, bottom)
    return None


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    CDN_DIR.mkdir(parents=True, exist_ok=True)

    flavors = sorted(set(HOME_ICONS) | set(SGDB_ICONS) | set(FALLBACK_ART_BADGES))
    rendered: dict[str, bytes] = {}
    for flavor in flavors:
        png = _flavor_png(flavor)
        if png is None:
            print(f"  !! no icon produced for {flavor}", file=sys.stderr)
            continue
        rendered[flavor] = png
        (ASSET_DIR / f"{flavor}.png").write_bytes(png)
        print(f"→ {flavor}.png ({len(png)} bytes)")

    # Merged app slug icons reuse the primary flavor's art.
    for slug, flavor in MERGED_TO_FLAVOR.items():
        png = rendered.get(flavor) or _flavor_png(flavor)
        if png is None:
            print(f"  !! no merged icon for {slug} (flavor {flavor})", file=sys.stderr)
            continue
        (ASSET_DIR / f"{slug}.png").write_bytes(png)
        print(f"→ {slug}.png (merged, from {flavor})")

    # CDN merged-slug set for games.json / flavor-text iconUrl rows.
    for name, flavor in CDN_TO_FLAVOR.items():
        png = rendered.get(flavor) or _flavor_png(flavor)
        if png is None:
            print(f"  !! no CDN icon for {name} (flavor {flavor})", file=sys.stderr)
            continue
        (CDN_DIR / f"{name}.png").write_bytes(png)
        print(f"→ cdn {name}.png (from {flavor})")

    print(
        f"\nGenerated {len(rendered)} flavor icons, "
        f"{len(MERGED_TO_FLAVOR)} merged assets, {len(CDN_TO_FLAVOR)} CDN files."
    )


if __name__ == "__main__":
    main()
