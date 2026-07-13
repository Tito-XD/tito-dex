#!/usr/bin/env python3
"""Build PokeAPI sprite / artwork / animated assets for CDN (R2).

Downloads per version-group dex sprites, official artwork, and Showdown GIFs.
Small fixed sets (type icons) stay vendored in data/assets/.

Resume behaviour (CI-friendly):
  - Skips files that already exist locally (--output dir).
  - With --skip-existing-cdn, skips assets already on dex.tito.cafe (R2).
  - With --upload, pushes each new file to R2 immediately (not only at the end).

Usage:
  python3 tools/build_pokeapi_assets.py --output dist/pokeapi-assets --max-id 50
  python3 tools/build_pokeapi_assets.py --upload  # requires CLOUDFLARE_* env
  python3 tools/build_pokeapi_assets.py --upload --min-id 678  # continue a range
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

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
CDN_BASE = "https://dex.tito.cafe"
DEFAULT_DELAY = 0.15
WRANGLER_DIR = ROOT / "cloudflare" / "dex-cdn"


def fetch_pokemon(session: requests.Session, pokemon_id: int) -> dict[str, Any]:
    response = session.get(f"{POKEAPI_BASE}/pokemon/{pokemon_id}", timeout=60)
    response.raise_for_status()
    return response.json()


def cdn_object_exists(session: requests.Session, rel_path: str) -> bool:
    """True when dex.tito.cafe already serves this v3 asset."""
    url = f"{CDN_BASE}/{BUNDLE_CDN_PREFIX}/{rel_path.lstrip('/')}"
    try:
        response = session.head(url, timeout=20, allow_redirects=True)
        return response.status_code == 200
    except requests.RequestException:
        return False


def ensure_wrangler_ready() -> dict[str, str]:
    env = dict(__import__("os").environ)
    if not env.get("CLOUDFLARE_API_TOKEN"):
        raise SystemExit("CLOUDFLARE_API_TOKEN required for --upload")
    subprocess.run(["npm", "ci"], cwd=WRANGLER_DIR, check=True)
    return env


def upload_one_to_r2(local_path: Path, rel_path: str, wr_env: dict[str, str]) -> None:
    key = f"titodex-dex/{BUNDLE_CDN_PREFIX}/{rel_path.lstrip('/')}"
    if local_path.suffix == ".gif":
        content_type = "image/gif"
    elif local_path.suffix == ".png":
        content_type = "image/png"
    else:
        content_type = "application/json"
    subprocess.run(
        [
            "npx",
            "wrangler",
            "r2",
            "object",
            "put",
            "--remote",
            key,
            f"--file={local_path}",
            f"--content-type={content_type}",
        ],
        cwd=WRANGLER_DIR,
        check=True,
        env=wr_env,
    )


def load_sprite_index(output_dir: Path) -> dict[str, dict[str, Any]]:
    index_path = output_dir / BUNDLE_CDN_PREFIX / "sprite_index.json"
    if not index_path.is_file():
        return {}
    try:
        return json.loads(index_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def save_sprite_index(output_dir: Path, sprite_index: dict[str, dict[str, Any]]) -> None:
    index_path = output_dir / BUNDLE_CDN_PREFIX / "sprite_index.json"
    index_path.parent.mkdir(parents=True, exist_ok=True)
    index_path.write_text(
        json.dumps(sprite_index, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def maybe_publish(
    *,
    local_path: Path,
    rel_path: str,
    upload: bool,
    wr_env: dict[str, str] | None,
    stats: dict[str, int],
) -> None:
    if not upload or wr_env is None:
        return
    upload_one_to_r2(local_path, rel_path, wr_env)
    stats["uploaded"] += 1


def asset_ready(
    *,
    session: requests.Session,
    local_path: Path,
    rel_path: str,
    skip_existing_cdn: bool,
    stats: dict[str, int],
) -> bool:
    if local_path.is_file():
        stats["cached_local"] += 1
        return True
    if skip_existing_cdn and cdn_object_exists(session, rel_path):
        stats["cached_cdn"] += 1
        return True
    return False


def build_assets(
    output_dir: Path,
    *,
    min_id: int,
    max_id: int,
    version_groups: tuple[str, ...],
    delay_s: float,
    include_artwork: bool,
    include_animated: bool,
    skip_existing_cdn: bool,
    upload: bool,
) -> dict[str, int]:
    output_dir.mkdir(parents=True, exist_ok=True)
    vg_root = output_dir / BUNDLE_CDN_PREFIX / "sprites" / "by-version"
    artwork_dir = output_dir / BUNDLE_CDN_PREFIX / "artwork"
    animated_dir = output_dir / BUNDLE_CDN_PREFIX / "sprites" / "animated"
    default_dir = output_dir / BUNDLE_CDN_PREFIX / "sprites"

    session = requests.Session()
    session.headers["User-Agent"] = "TitoDex-maintainer/1.0 (+github.com/Tito-XD/tito-dex)"

    wr_env = ensure_wrangler_ready() if upload else None

    stats = {
        "pokemon": 0,
        "sprites_by_version": 0,
        "artwork": 0,
        "animated": 0,
        "default_sprites": 0,
        "sprites_skipped": 0,
        "cached_local": 0,
        "cached_cdn": 0,
        "uploaded": 0,
    }
    sprite_index = load_sprite_index(output_dir)

    for pokemon_id in range(min_id, max_id + 1):
        print(f"#{pokemon_id}/{max_id}…", flush=True)
        detail = fetch_pokemon(session, pokemon_id)
        sprites = detail.get("sprites") or {}
        stats["pokemon"] += 1

        default_url = sprite_url_for_version_group(sprites, "heartgold-soulsilver")
        if default_url:
            default_dir.mkdir(parents=True, exist_ok=True)
            dest = default_dir / f"{pokemon_id}.png"
            rel = f"sprites/{pokemon_id}.png"
            if not asset_ready(
                session=session,
                local_path=dest,
                rel_path=rel,
                skip_existing_cdn=skip_existing_cdn,
                stats=stats,
            ):
                try:
                    png = download_bytes(session, default_url)
                    dest.write_bytes(optimize_png(png, max_width=220))
                    stats["default_sprites"] += 1
                    maybe_publish(
                        local_path=dest,
                        rel_path=rel,
                        upload=upload,
                        wr_env=wr_env,
                        stats=stats,
                    )
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
            rel = f"sprites/by-version/{vg}/{pokemon_id}.png"
            if asset_ready(
                session=session,
                local_path=dest,
                rel_path=rel,
                skip_existing_cdn=skip_existing_cdn,
                stats=stats,
            ):
                vg_urls[vg] = rel
                continue
            try:
                png = download_bytes(session, url)
                dest.write_bytes(optimize_png(png, max_width=220))
                vg_urls[vg] = rel
                stats["sprites_by_version"] += 1
                maybe_publish(
                    local_path=dest,
                    rel_path=rel,
                    upload=upload,
                    wr_env=wr_env,
                    stats=stats,
                )
            except (requests.RequestException, UnidentifiedImageError, OSError) as exc:
                stats["sprites_skipped"] += 1
                print(f"  warn sprite {vg} #{pokemon_id}: {exc}", file=sys.stderr)

        if include_artwork:
            art_url = official_artwork_url(sprites)
            if art_url:
                dest = artwork_dir / f"{pokemon_id}.png"
                artwork_dir.mkdir(parents=True, exist_ok=True)
                rel = f"artwork/{pokemon_id}.png"
                if not asset_ready(
                    session=session,
                    local_path=dest,
                    rel_path=rel,
                    skip_existing_cdn=skip_existing_cdn,
                    stats=stats,
                ):
                    try:
                        png = download_bytes(session, art_url)
                        dest.write_bytes(optimize_png(png, max_width=None))
                        stats["artwork"] += 1
                        maybe_publish(
                            local_path=dest,
                            rel_path=rel,
                            upload=upload,
                            wr_env=wr_env,
                            stats=stats,
                        )
                    except (requests.RequestException, UnidentifiedImageError, OSError) as exc:
                        stats["sprites_skipped"] += 1
                        print(f"  warn artwork #{pokemon_id}: {exc}", file=sys.stderr)

        if include_animated:
            anim_url = animated_sprite_url(sprites)
            if anim_url:
                dest = animated_dir / f"{pokemon_id}.gif"
                animated_dir.mkdir(parents=True, exist_ok=True)
                rel = f"sprites/animated/{pokemon_id}.gif"
                if not asset_ready(
                    session=session,
                    local_path=dest,
                    rel_path=rel,
                    skip_existing_cdn=skip_existing_cdn,
                    stats=stats,
                ):
                    try:
                        dest.write_bytes(download_bytes(session, anim_url))
                        stats["animated"] += 1
                        maybe_publish(
                            local_path=dest,
                            rel_path=rel,
                            upload=upload,
                            wr_env=wr_env,
                            stats=stats,
                        )
                    except requests.RequestException as exc:
                        print(f"  warn animated #{pokemon_id}: {exc}", file=sys.stderr)

        sprite_index[str(pokemon_id)] = {
            "spriteUrlsByVersion": build_sprite_url_map(sprites, version_groups),
            "cdnPathsByVersion": vg_urls,
            "artworkUrl": official_artwork_url(sprites),
            "animatedUrl": animated_sprite_url(sprites),
        }
        save_sprite_index(output_dir, sprite_index)
        time.sleep(delay_s)

    if upload and wr_env is not None:
        index_path = output_dir / BUNDLE_CDN_PREFIX / "sprite_index.json"
        if index_path.is_file():
            upload_one_to_r2(index_path, "sprite_index.json", wr_env)
            stats["uploaded"] += 1

    return stats


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
    parser.add_argument(
        "--skip-existing-cdn",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Skip downloads when dex.tito.cafe already has the asset (default: on)",
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
        skip_existing_cdn=args.skip_existing_cdn,
        upload=args.upload,
    )
    print(json.dumps(stats, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
