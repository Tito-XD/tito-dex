#!/usr/bin/env python3
"""Build PokeAPI sprite / artwork / animated assets for CDN (R2).

Downloads per version-group dex sprites, official artwork, and Showdown GIFs.
Small fixed sets (type icons) stay vendored in data/assets/.

Usage:
  python3 tools/build_pokeapi_assets.py --output dist/pokeapi-assets --max-id 50
  python3 tools/build_pokeapi_assets.py --upload  # requires CLOUDFLARE_* env
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import requests
from PIL import UnidentifiedImageError

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_dex_bundle import (  # noqa: E402
    BUNDLE_CDN_PREFIX,
    download_bytes,
    optimize_png,
)
from pokeapi_assets import (  # noqa: E402
    ALL_SPRITE_VERSION_GROUPS,
    animated_sprite_url,
    build_sprite_url_map,
    official_artwork_url,
    sprite_url_for_version_group,
)

POKEAPI_BASE = "https://pokeapi.co/api/v2"
DEFAULT_DELAY = 0.15


def fetch_pokemon(session: requests.Session, pokemon_id: int) -> dict:
    response = session.get(f"{POKEAPI_BASE}/pokemon/{pokemon_id}", timeout=60)
    response.raise_for_status()
    return response.json()


def build_assets(
    output_dir: Path,
    *,
    min_id: int,
    max_id: int,
    version_groups: tuple[str, ...],
    delay_s: float,
    include_artwork: bool,
    include_animated: bool,
) -> dict[str, int]:
    output_dir.mkdir(parents=True, exist_ok=True)
    vg_root = output_dir / BUNDLE_CDN_PREFIX / "sprites" / "by-version"
    artwork_dir = output_dir / BUNDLE_CDN_PREFIX / "artwork"
    animated_dir = output_dir / BUNDLE_CDN_PREFIX / "sprites" / "animated"
    default_dir = output_dir / BUNDLE_CDN_PREFIX / "sprites"

    session = requests.Session()
    session.headers["User-Agent"] = "TitoDex-maintainer/1.0 (+github.com/Tito-XD/tito-dex)"

    stats = {
        "pokemon": 0,
        "sprites_by_version": 0,
        "artwork": 0,
        "animated": 0,
        "default_sprites": 0,
        "sprites_skipped": 0,
    }
    sprite_index: dict[str, dict[str, str]] = {}

    for pokemon_id in range(min_id, max_id + 1):
        print(f"#{pokemon_id}/{max_id}…", flush=True)
        detail = fetch_pokemon(session, pokemon_id)
        sprites = detail.get("sprites") or {}
        stats["pokemon"] += 1

        # Default list thumbnail (HGSS-style default path: use HGSS if present).
        default_url = sprite_url_for_version_group(sprites, "heartgold-soulsilver")
        if default_url:
            default_dir.mkdir(parents=True, exist_ok=True)
            dest = default_dir / f"{pokemon_id}.png"
            if not dest.exists():
                try:
                    png = download_bytes(session, default_url)
                    dest.write_bytes(optimize_png(png, max_width=220))
                    stats["default_sprites"] += 1
                except (requests.RequestException, UnidentifiedImageError, OSError) as exc:
                    stats["sprites_skipped"] += 1
                    print(
                        f"  warn default sprite #{pokemon_id}: {exc}",
                        file=sys.stderr,
                    )

        vg_urls: dict[str, str] = {}
        for vg in version_groups:
            url = sprite_url_for_version_group(sprites, vg)
            if not url:
                continue
            dest_dir = vg_root / vg
            dest_dir.mkdir(parents=True, exist_ok=True)
            dest = dest_dir / f"{pokemon_id}.png"
            if dest.exists():
                vg_urls[vg] = f"sprites/by-version/{vg}/{pokemon_id}.png"
                continue
            try:
                png = download_bytes(session, url)
                dest.write_bytes(optimize_png(png, max_width=220))
                vg_urls[vg] = f"sprites/by-version/{vg}/{pokemon_id}.png"
                stats["sprites_by_version"] += 1
            except (requests.RequestException, UnidentifiedImageError, OSError) as exc:
                stats["sprites_skipped"] += 1
                print(f"  warn sprite {vg} #{pokemon_id}: {exc}", file=sys.stderr)

        if include_artwork:
            art_url = official_artwork_url(sprites)
            if art_url:
                dest = artwork_dir / f"{pokemon_id}.png"
                artwork_dir.mkdir(parents=True, exist_ok=True)
                if not dest.exists():
                    try:
                        png = download_bytes(session, art_url)
                        dest.write_bytes(optimize_png(png, max_width=None))
                        stats["artwork"] += 1
                    except (requests.RequestException, UnidentifiedImageError, OSError) as exc:
                        stats["sprites_skipped"] += 1
                        print(f"  warn artwork #{pokemon_id}: {exc}", file=sys.stderr)

        if include_animated:
            anim_url = animated_sprite_url(sprites)
            if anim_url:
                dest = animated_dir / f"{pokemon_id}.gif"
                animated_dir.mkdir(parents=True, exist_ok=True)
                if not dest.exists():
                    try:
                        dest.write_bytes(download_bytes(session, anim_url))
                        stats["animated"] += 1
                    except requests.RequestException as exc:
                        print(f"  warn animated #{pokemon_id}: {exc}", file=sys.stderr)

        sprite_index[str(pokemon_id)] = {
            "spriteUrlsByVersion": build_sprite_url_map(sprites, version_groups),
            "cdnPathsByVersion": vg_urls,
            "artworkUrl": official_artwork_url(sprites),
            "animatedUrl": animated_sprite_url(sprites),
        }
        time.sleep(delay_s)

    index_path = output_dir / BUNDLE_CDN_PREFIX / "sprite_index.json"
    index_path.write_text(
        json.dumps(sprite_index, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return stats


def upload_to_r2(output_dir: Path) -> None:
    import subprocess

    env = {**dict(__import__("os").environ)}
    if not env.get("CLOUDFLARE_API_TOKEN"):
        raise SystemExit("CLOUDFLARE_API_TOKEN required for --upload")

    cdn_root = output_dir / BUNDLE_CDN_PREFIX
    wr = "npx wrangler r2 object put --remote"
    subprocess.run(["npm", "ci"], cwd=ROOT / "cloudflare" / "dex-cdn", check=True)

    count = 0
    for path in sorted(cdn_root.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(output_dir / BUNDLE_CDN_PREFIX).as_posix()
        key = f"titodex-dex/{BUNDLE_CDN_PREFIX}/{rel}"
        content_type = "image/gif" if path.suffix == ".gif" else (
            "image/png" if path.suffix == ".png" else "application/json"
        )
        subprocess.run(
            f'{wr} "{key}" --file="{path}" --content-type={content_type}',
            shell=True,
            cwd=ROOT / "cloudflare" / "dex-cdn",
            check=True,
            env=env,
        )
        count += 1
        if count % 100 == 0:
            print(f"  uploaded {count}…", flush=True)
    print(f"Uploaded {count} objects to R2", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "pokeapi-assets")
    parser.add_argument("--min-id", type=int, default=1)
    parser.add_argument("--max-id", type=int, default=1025)
    parser.add_argument("--delay", type=float, default=DEFAULT_DELAY)
    parser.add_argument("--no-artwork", action="store_true")
    parser.add_argument("--no-animated", action="store_true")
    parser.add_argument(
        "--version-groups",
        nargs="*",
        default=list(ALL_SPRITE_VERSION_GROUPS),
    )
    parser.add_argument("--upload", action="store_true")
    args = parser.parse_args()

    stats = build_assets(
        args.output,
        min_id=args.min_id,
        max_id=args.max_id,
        version_groups=tuple(args.version_groups),
        delay_s=args.delay,
        include_artwork=not args.no_artwork,
        include_animated=not args.no_animated,
    )
    print(json.dumps(stats, indent=2), flush=True)

    if args.upload:
        upload_to_r2(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
