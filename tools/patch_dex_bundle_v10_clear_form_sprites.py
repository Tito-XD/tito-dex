#!/usr/bin/env python3
"""Patch TitoDex v9 bundle into v10: clear (official-artwork) form sprites.

The v9 bundle ships pixelated in-game sprites under sprites/forms/ while the
matching clear official artwork already exists under artwork/forms/ (315
files, 1:1). Cached pages (detail header, form grid, thumbnails) resolve
localSpritePath -> sprites/forms/, so every offline/cached form showed the
pixelated image.

This patch:
  1. copies dist/dex-v9/v5 into a v10 staging tree,
  2. rewrites every sprites/forms/<id>.png from artwork/forms/<id>.png
     (optimized to the 220px sprite spec),
  3. uploads the 315 sprite files to R2 (same keys, content replaced),
  4. bumps manifest version to 10, repacks bundle.tar.zst, rewrites the root
     bundle-manifest.json (new sha/size), and uploads all three.

Run: python3 tools/patch_dex_bundle_v10_clear_form_sprites.py [--skip-upload]
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_dex_bundle import (  # noqa: E402
    create_zst_tar,
    directory_size,
    optimize_png,
    sha256_file,
)

SOURCE_STAGING = ROOT / "dist" / "dex-v9" / "v5"
BUNDLE_VERSION = 10
CDN_PREFIX = "v5"
CDN_BASE = "https://dex.tito.cafe"


def r2_put(local_path: Path, key: str, content_type: str) -> None:
    subprocess.run(
        [
            "npx",
            "wrangler",
            "r2",
            "object",
            "put",
            f"titodex-dex/{key}",
            f"--file={local_path}",
            "--remote",
            f"--content-type={content_type}",
        ],
        check=True,
        cwd=ROOT / "cloudflare" / "dex-cdn",
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def rebuild_form_sprites(staging: Path) -> list[Path]:
    sprites_dir = staging / "sprites" / "forms"
    artwork_dir = staging / "artwork" / "forms"
    rebuilt: list[Path] = []
    for sprite_path in sorted(sprites_dir.glob("*.png")):
        artwork_path = artwork_dir / sprite_path.name
        if not artwork_path.is_file():
            print(f"  warn no artwork counterpart for {sprite_path.name}", flush=True)
            continue
        sprite_path.write_bytes(optimize_png(artwork_path.read_bytes(), max_width=220))
        rebuilt.append(sprite_path)
    return rebuilt


def upload_form_sprites(rebuilt: list[Path], staging: Path, workers: int) -> None:
    def upload_one(path: Path) -> None:
        r2_put(path, f"{CDN_PREFIX}/sprites/forms/{path.name}", "image/png")

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(upload_one, path) for path in rebuilt]
        for completed, future in enumerate(as_completed(futures), start=1):
            future.result()
            if completed % 50 == 0 or completed == len(futures):
                print(f"  upload {completed}/{len(futures)}", flush=True)


def build(args: argparse.Namespace) -> None:
    output = args.output.resolve()
    staging = output / "staging"
    upload_root = output / "upload"

    if staging.exists():
        shutil.rmtree(staging)
    if upload_root.exists():
        shutil.rmtree(upload_root)
    staging.mkdir(parents=True, exist_ok=True)

    print(f"Copying {SOURCE_STAGING} -> {staging} ...", flush=True)
    shutil.copytree(SOURCE_STAGING, staging, dirs_exist_ok=True)
    # The source tree already contains a bundle archive; rebuild it later.
    (staging / "bundle.tar.zst").unlink(missing_ok=True)

    base_manifest = json.loads((staging / "manifest.json").read_text(encoding="utf-8"))
    if (
        base_manifest.get("version") != 9
        or base_manifest.get("pokemonCount") != 1025
        or not base_manifest.get("complete")
    ):
        raise ValueError(f"Unexpected v9 seed manifest: {base_manifest}")

    print("Rewriting sprites/forms from artwork/forms ...", flush=True)
    rebuilt = rebuild_form_sprites(staging)
    print(f"Rebuilt {len(rebuilt)} clear form sprites.", flush=True)

    if not args.skip_upload:
        print("Uploading form sprites to R2 ...", flush=True)
        upload_form_sprites(rebuilt, staging, args.workers)

    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    base_manifest["version"] = BUNDLE_VERSION
    base_manifest["downloadedAt"] = published_at
    base_manifest["sizeBytes"] = directory_size(staging)
    (staging / "manifest.json").write_text(
        json.dumps(base_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("Creating v10 archive ...", flush=True)
    archive_path = staging / "bundle.tar.zst"
    create_zst_tar(staging, archive_path)

    versioned = upload_root / CDN_PREFIX
    upload_root.mkdir(parents=True, exist_ok=True)
    if versioned.exists():
        shutil.rmtree(versioned)
    shutil.copytree(staging, versioned)

    archive_sha = sha256_file(versioned / "bundle.tar.zst")
    root_manifest_path = ROOT / "dist" / "dex-v9" / "bundle-manifest.json"
    root_manifest = json.loads(root_manifest_path.read_text(encoding="utf-8"))
    root_manifest.update(
        {
            "bundleVersion": BUNDLE_VERSION,
            "archiveSha256": archive_sha,
            "archiveSizeBytes": (versioned / "bundle.tar.zst").stat().st_size,
            "publishedAt": published_at,
        }
    )
    (upload_root / "bundle-manifest.json").write_text(
        json.dumps(root_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Archive SHA256: {archive_sha}", flush=True)
    print(f"Archive bytes: {root_manifest['archiveSizeBytes']:,}", flush=True)

    if not args.skip_upload:
        print("Uploading bundle.tar.zst ...", flush=True)
        r2_put(versioned / "bundle.tar.zst", f"{CDN_PREFIX}/bundle.tar.zst", "application/zstd")
        print("Uploading v5/manifest.json ...", flush=True)
        r2_put(versioned / "manifest.json", f"{CDN_PREFIX}/manifest.json", "application/json")
        print("Uploading root bundle-manifest.json ...", flush=True)
        r2_put(upload_root / "bundle-manifest.json", "bundle-manifest.json", "application/json")

    print(f"Done: {upload_root}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Patch TitoDex v9 into v10 with clear form sprites"
    )
    parser.add_argument("--output", type=Path, default=Path("dist/dex-v10"))
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Build the v10 tree locally without touching R2",
    )
    args = parser.parse_args()
    if args.workers < 1 or args.workers > 16:
        parser.error("--workers must be within 1..16")
    build(args)


if __name__ == "__main__":
    main()
