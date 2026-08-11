#!/usr/bin/env python3
"""Patch the live TitoDex v10 bundle into v11: complete items + offline sprites.

v10 shipped 208 curated items and kept item sprites CDN-only (never in the
archive), so offline users saw no item icons. v11:
  1. takes the *published* v10 bundle.tar.zst as the read-only base (nothing
     else is regenerated — encounters/forms/moves/sprites are byte-identical),
  2. replaces items.json with the expanded, Bulbapedia-grouped dataset
     (tools/build_items_dataset.py + the two 52poke enrich passes),
  3. adds item-sprites/*.png INTO the archive so icons work fully offline,
  4. writes the CC BY-NC-SA attribution for the 52poke-sourced descriptions,
  5. bumps the manifest to 11, repacks, and uploads /v5/ objects then the root
     bundle-manifest.json last (never touching the /v4/ rollback).

Run: python3 tools/patch_dex_bundle_v11_items.py [--skip-upload]
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import shutil
import subprocess
import tarfile
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


# Inlined from build_dex_bundle.py to avoid pulling its heavy imports
# (requests/PIL) just for three pure helpers.
def directory_size(path: Path) -> int:
    return sum(f.stat().st_size for f in path.rglob("*") if f.is_file())


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def create_zst_tar(source_dir: Path, archive_path: Path) -> None:
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as tar:
        for file in sorted(source_dir.rglob("*")):
            if not file.is_file() or file.name == "bundle.tar.zst":
                continue
            tar.add(file, arcname=file.relative_to(source_dir).as_posix())
    process = subprocess.run(
        ["zstd", "-19", "--stdout"], input=buffer.getvalue(),
        capture_output=True, check=True,
    )
    archive_path.write_bytes(process.stdout)

BUNDLE_VERSION = 11
CDN_PREFIX = "v5"
CDN_BASE = "https://dex.tito.cafe"
LIVE_ARCHIVE = f"{CDN_BASE}/{CDN_PREFIX}/bundle.tar.zst"
LIVE_ROOT_MANIFEST = f"{CDN_BASE}/bundle-manifest.json"

ITEMS_SRC = ROOT / "dist" / "items-v11-work" / "items.json"
SPRITES_SRC = ROOT / "dist" / "items-v11-work" / "item-sprites"

ATTRIBUTION = """\
TitoDex offline bundle — item data attribution
==============================================

Item list, categories, costs, English names, and most Simplified-Chinese
in-game descriptions: PokeAPI (https://pokeapi.co/); its data repository is
BSD-3-Clause. Item sprites are located through PokeAPI/sprites and retain the
upstream credits and varying underlying media rights. Item grouping follows
Bulbapedia's Browse:Items player-facing taxonomy.

Simplified-Chinese descriptions for the newest items (tera shards, SV mochi and
masks, Legends: Arceus balls, and a few Gen 9 held items) are sourced from
神奇宝贝百科 (52Poké Wiki, https://wiki.52poke.com/), licensed under
CC BY-NC-SA 3.0 (https://creativecommons.org/licenses/by-nc-sa/3.0/).

Pokémon and item names/data are trademarks of Nintendo / Creatures Inc. /
GAME FREAK inc. TitoDex is a non-commercial fan companion.
"""


def r2_put(local_path: Path, key: str, content_type: str) -> None:
    subprocess.run(
        [
            "npx", "wrangler", "r2", "object", "put",
            f"titodex-dex/{key}", f"--file={local_path}", "--remote",
            f"--content-type={content_type}",
        ],
        check=True,
        cwd=ROOT / "cloudflare" / "dex-cdn",
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def download(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "TitoDex/1.0 (+bundle build)"})
    with urllib.request.urlopen(req, timeout=180) as resp, open(dest, "wb") as fh:
        shutil.copyfileobj(resp, fh)


def extract_archive(archive: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    # zstd CLI + tar: reliable, no python-zstandard dependency at build time.
    zstd = subprocess.run(["zstd", "-dc", str(archive)], check=True, stdout=subprocess.PIPE)
    subprocess.run(["tar", "-x", "-C", str(dest)], check=True, input=zstd.stdout)


def build(args: argparse.Namespace) -> None:
    output = args.output.resolve()
    staging = output / "staging"
    upload_root = output / "upload"
    for path in (staging, upload_root):
        if path.exists():
            shutil.rmtree(path)
    output.mkdir(parents=True, exist_ok=True)

    # 1. Authoritative base: the published v10 archive.
    base_archive = output / "base-v10.tar.zst"
    print(f"Downloading live base archive → {base_archive} ...", flush=True)
    download(LIVE_ARCHIVE, base_archive)
    print(f"Extracting base archive → {staging} ...", flush=True)
    extract_archive(base_archive, staging)
    (staging / "bundle.tar.zst").unlink(missing_ok=True)

    base_manifest = json.loads((staging / "manifest.json").read_text(encoding="utf-8"))
    if base_manifest.get("version") != 10 or not base_manifest.get("complete"):
        raise ValueError(f"Unexpected base manifest (want v10 complete): {base_manifest}")

    # 2. New items.json.
    items = json.loads(ITEMS_SRC.read_text(encoding="utf-8"))
    (staging / "items.json").write_text(
        json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Wrote items.json ({len(items)} items).", flush=True)

    # 3. Item sprites into the archive tree.
    dest_sprites = staging / "item-sprites"
    if dest_sprites.exists():
        shutil.rmtree(dest_sprites)
    shutil.copytree(SPRITES_SRC, dest_sprites)
    sprite_files = sorted(dest_sprites.glob("*.png"))
    print(f"Copied {len(sprite_files)} item sprites into the bundle.", flush=True)

    # 4. Attribution.
    (staging / "ITEMS_ATTRIBUTION.txt").write_text(ATTRIBUTION, encoding="utf-8")

    # 5. Manifest bump.
    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    described = sum(1 for it in items.values() if it.get("descriptionZh"))
    base_manifest.update(
        {
            "version": BUNDLE_VERSION,
            "downloadedAt": published_at,
            "itemCount": len(items),
            "itemSpriteCount": len(sprite_files),
            "itemDescribedZh": described,
        }
    )
    base_manifest["sizeBytes"] = directory_size(staging)
    (staging / "manifest.json").write_text(
        json.dumps(base_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    print("Creating v11 archive ...", flush=True)
    archive_path = staging / "bundle.tar.zst"
    create_zst_tar(staging, archive_path)

    versioned = upload_root / CDN_PREFIX
    upload_root.mkdir(parents=True, exist_ok=True)
    shutil.copytree(staging, versioned)

    archive_sha = sha256_file(versioned / "bundle.tar.zst")
    print("Downloading live root manifest to preserve its fields ...", flush=True)
    root_manifest_path = output / "root-manifest-base.json"
    download(LIVE_ROOT_MANIFEST, root_manifest_path)
    root_manifest = json.loads(root_manifest_path.read_text(encoding="utf-8"))
    root_manifest.update(
        {
            "bundleVersion": BUNDLE_VERSION,
            "archiveSha256": archive_sha,
            "archiveSizeBytes": (versioned / "bundle.tar.zst").stat().st_size,
            "itemCount": len(items),
            "publishedAt": published_at,
        }
    )
    (upload_root / "bundle-manifest.json").write_text(
        json.dumps(root_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Archive SHA256: {archive_sha}", flush=True)
    print(f"Archive bytes: {root_manifest['archiveSizeBytes']:,}", flush=True)

    if args.skip_upload:
        print(f"\n--skip-upload: built {upload_root} locally, R2 untouched.", flush=True)
        return

    # Phase 1: all /v5/ objects (item-sprites + items.json + manifest + archive).
    print("Uploading item sprites ...", flush=True)

    def upload_sprite(path: Path) -> None:
        r2_put(path, f"{CDN_PREFIX}/item-sprites/{path.name}", "image/png")

    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = [ex.submit(upload_sprite, p) for p in sprite_files]
        for done, fut in enumerate(as_completed(futures), start=1):
            fut.result()
            if done % 100 == 0 or done == len(futures):
                print(f"  sprites {done}/{len(futures)}", flush=True)

    print("Uploading v5/items.json ...", flush=True)
    r2_put(versioned / "items.json", f"{CDN_PREFIX}/items.json", "application/json")
    print("Uploading v5/ITEMS_ATTRIBUTION.txt ...", flush=True)
    r2_put(versioned / "ITEMS_ATTRIBUTION.txt", f"{CDN_PREFIX}/ITEMS_ATTRIBUTION.txt", "text/plain; charset=utf-8")
    print("Uploading v5/manifest.json ...", flush=True)
    r2_put(versioned / "manifest.json", f"{CDN_PREFIX}/manifest.json", "application/json")
    print("Uploading v5/bundle.tar.zst ...", flush=True)
    r2_put(versioned / "bundle.tar.zst", f"{CDN_PREFIX}/bundle.tar.zst", "application/zstd")

    # Phase 2: root manifest last — clients only switch to v11 once every object above exists.
    print("Uploading root bundle-manifest.json (last) ...", flush=True)
    r2_put(upload_root / "bundle-manifest.json", "bundle-manifest.json", "application/json")
    print(f"Done: published v11. {upload_root}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Patch TitoDex v10 → v11 (complete items)")
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "dex-v11")
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--skip-upload", action="store_true", help="build locally, don't touch R2")
    args = parser.parse_args()
    if not (1 <= args.workers <= 16):
        parser.error("--workers must be within 1..16")
    build(args)


if __name__ == "__main__":
    main()
