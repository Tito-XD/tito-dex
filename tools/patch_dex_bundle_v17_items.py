#!/usr/bin/env python3
"""Patch the live TitoDex bundle into v17 with the full item catalog.

Merges ``items_all_extra.json`` (1536 PokeAPI items) into ``items.json``,
copies new item sprites from ``data/assets/item-sprites`` into the bundle,
and bumps both manifests to v17. Never uploads to R2.
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
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BASE_VERSION = 16
BUNDLE_VERSION = 17
CDN_PREFIX = "v5"
CDN_BASE = "https://dex.tito.cafe"
LIVE_ARCHIVE = f"{CDN_BASE}/{CDN_PREFIX}/bundle.tar.zst"
LIVE_ROOT_MANIFEST = f"{CDN_BASE}/bundle-manifest.json"
ARCHIVE_NAME = f"bundle-v{BUNDLE_VERSION}.tar.zst"
V17_ARCHIVE = f"{CDN_BASE}/{CDN_PREFIX}/{ARCHIVE_NAME}"
USER_AGENT = "TitoDex/1.0 (+bundle build)"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def directory_size(path: Path) -> int:
    return sum(file.stat().st_size for file in path.rglob("*") if file.is_file())


def download(url: str, dest: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=180) as response:
        with dest.open("wb") as handle:
            shutil.copyfileobj(response, handle)


def extract_archive(archive: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    try:
        result = subprocess.run(
            ["zstd", "-dc", str(archive)], check=True, stdout=subprocess.PIPE
        )
        data = result.stdout
    except (FileNotFoundError, subprocess.CalledProcessError):
        import zstandard

        data = zstandard.ZstdDecompressor().decompress(
            archive.read_bytes(), max_output_size=2 * 1024 * 1024 * 1024
        )
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:") as tar:
        destination = dest.resolve()
        for member in tar.getmembers():
            target = (dest / member.name).resolve()
            if target != destination and destination not in target.parents:
                raise ValueError(f"Unsafe archive member: {member.name}")
        tar.extractall(dest)


def create_zst_tar(source_dir: Path, archive_path: Path) -> None:
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as tar:
        for file in sorted(source_dir.rglob("*")):
            if not file.is_file() or file.resolve() == archive_path.resolve():
                continue
            tar.add(file, arcname=file.relative_to(source_dir).as_posix())
    try:
        subprocess.run(
            ["zstd", "-q", "-f", "-o", str(archive_path), "-"],
            input=buffer.getvalue(),
            check=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        import zstandard

        archive_path.write_bytes(
            zstandard.ZstdCompressor(level=19).compress(buffer.getvalue())
        )


def merge_items(staging: Path, extra_data: dict[str, Any]) -> tuple[int, int]:
    items_path = staging / "items.json"
    items = json.loads(items_path.read_text(encoding="utf-8"))
    by_slug = {item["slug"] for item in items.values()}
    next_id = max(int(k) for k in items.keys()) + 1
    added = 0
    for slug, item in sorted((extra_data.get("itemsBySlug") or {}).items()):
        if slug in by_slug:
            continue
        items[str(next_id)] = {
            "id": next_id,
            "slug": slug,
            "nameEn": item.get("nameEn") or slug,
            "nameZh": item.get("nameZh") or slug,
            "category": item.get("category") or "held-items",
            "categoryZh": item.get("categoryZh") or "其他道具",
            "cost": int(item.get("cost") or 0),
            "spriteUrl": item.get("spriteUrl"),
            "descriptionZh": item.get("descriptionZh") or "",
            "effectZh": item.get("effectZh") or "",
        }
        by_slug.add(slug)
        next_id += 1
        added += 1
    items_path.write_text(
        json.dumps(items, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return added, len(items)


def copy_sprites(staging: Path, sprite_dir: Path) -> int:
    dest = staging / "item-sprites"
    dest.mkdir(parents=True, exist_ok=True)
    copied = 0
    for source in sorted(sprite_dir.glob("*.png")):
        target = dest / source.name
        if not target.exists():
            shutil.copyfile(source, target)
            copied += 1
    return copied


def build(args: argparse.Namespace) -> None:
    output: Path = args.output
    output.mkdir(parents=True, exist_ok=True)
    staging = output / "staging"
    upload_root = output / "upload"
    for path in (staging, upload_root):
        if path.exists():
            shutil.rmtree(path)

    if args.base_archive:
        archive = args.base_archive
    else:
        archive = output / "bundle-base.tar.zst"
        if not archive.exists() or args.force_download:
            print(f"Downloading live v{BASE_VERSION} archive ...", flush=True)
            download(LIVE_ARCHIVE, archive)
    extract_archive(archive, staging)

    extra_data = json.loads(args.extra_json.read_text(encoding="utf-8"))
    added, total = merge_items(staging, extra_data)
    copied = copy_sprites(staging, args.sprites_dir)

    manifest_path = staging / "manifest.json"
    base_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    base_manifest.update(
        {
            "version": BUNDLE_VERSION,
            "downloadedAt": published_at,
            "itemCatalogSource": (
                "PokeAPI data (BSD-3-Clause) + 52poke original wiki text "
                "(CC BY-NC-SA 3.0) + media with upstream/source-page credits "
                "(underlying rights vary)"
            ),
            "itemsAdded": added,
            "itemSpritesCopied": copied,
        }
    )
    base_manifest["sizeBytes"] = directory_size(staging)
    manifest_path.write_text(
        json.dumps(base_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    versioned = upload_root / CDN_PREFIX
    upload_root.mkdir(parents=True, exist_ok=True)
    print(f"Creating v{BUNDLE_VERSION} archive ...", flush=True)
    create_zst_tar(staging, staging / ARCHIVE_NAME)
    shutil.copytree(staging, versioned)
    archive_sha = sha256_file(versioned / ARCHIVE_NAME)

    if args.base_root_manifest:
        root_manifest = json.loads(
            args.base_root_manifest.read_text(encoding="utf-8")
        )
    else:
        print("Downloading live root manifest ...", flush=True)
        root_manifest_path = output / "root-manifest-base.json"
        download(LIVE_ROOT_MANIFEST, root_manifest_path)
        root_manifest = json.loads(
            root_manifest_path.read_text(encoding="utf-8")
        )
    root_manifest.update(
        {
            "bundleVersion": BUNDLE_VERSION,
            "archiveUrl": V17_ARCHIVE,
            "archiveSha256": archive_sha,
            "archiveSizeBytes": (versioned / ARCHIVE_NAME).stat().st_size,
            "publishedAt": published_at,
            "itemCatalogSource": (
                "PokeAPI data (BSD-3-Clause) + 52poke original wiki text "
                "(CC BY-NC-SA 3.0) + media with upstream/source-page credits "
                "(underlying rights vary)"
            ),
            "itemsAdded": added,
        }
    )
    (upload_root / "bundle-manifest.json").write_text(
        json.dumps(root_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"\n--- v{BUNDLE_VERSION} item-catalog summary ---", flush=True)
    print(f"  items added                   {added} (total {total})", flush=True)
    print(f"  sprites copied                {copied}", flush=True)
    print(f"  archive sha256                {archive_sha}", flush=True)
    print(f"  archive bytes                 {root_manifest['archiveSizeBytes']:,}", flush=True)
    print(
        "\nBuilt locally; R2 untouched. Release with:\n"
        f"  python3 tools/verify_dex_upload_tree.py {upload_root}\n"
        f"  python3 tools/upload_dex_bundle_r2.py {upload_root} "
        f"--cdn-prefix {CDN_PREFIX} --phase objects\n"
        f"  python3 tools/upload_dex_bundle_r2.py {upload_root} "
        f"--cdn-prefix {CDN_PREFIX} --phase manifest",
        flush=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Patch TitoDex v16 -> v17 (full item catalog)"
    )
    parser.add_argument(
        "--extra-json",
        type=Path,
        default=ROOT / "data" / "l10n" / "zh" / "items_all_extra.json",
    )
    parser.add_argument(
        "--sprites-dir",
        type=Path,
        default=ROOT / "data" / "assets" / "item-sprites",
    )
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "dex-v17")
    parser.add_argument(
        "--base-archive",
        type=Path,
        help="Local base bundle.tar.zst instead of downloading the live one",
    )
    parser.add_argument(
        "--base-root-manifest",
        type=Path,
        help="Local root bundle-manifest.json instead of downloading it",
    )
    parser.add_argument(
        "--force-download",
        action="store_true",
        help="Re-download the live archive even if a cached copy exists",
    )
    args = parser.parse_args()
    build(args)


if __name__ == "__main__":
    main()
