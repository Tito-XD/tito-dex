#!/usr/bin/env python3
"""Patch the live TitoDex bundle into v16 with 52poke wild held-item data.

Merges ``data/l10n/zh/held_items_52poke.json`` into each detail's
``heldItems``: existing PokeAPI entries are kept, 52poke rates override the
same version, and versions missing from the bundle are added. Adds a
CC BY-NC-SA 4.0 attribution file and bumps both manifests to v16. Never
uploads to R2.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import shutil
import subprocess
import tarfile
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BASE_VERSION = 15
BUNDLE_VERSION = 16
CDN_PREFIX = "v5"
CDN_BASE = "https://dex.tito.cafe"
LIVE_ARCHIVE = f"{CDN_BASE}/{CDN_PREFIX}/bundle.tar.zst"
LIVE_ROOT_MANIFEST = f"{CDN_BASE}/bundle-manifest.json"
ARCHIVE_NAME = f"bundle-v{BUNDLE_VERSION}.tar.zst"
V16_ARCHIVE = f"{CDN_BASE}/{CDN_PREFIX}/{ARCHIVE_NAME}"
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


def load_item_slugs(staging: Path) -> dict[str, str]:
    items = json.loads((staging / "items.json").read_text(encoding="utf-8"))
    by_zh: dict[str, str] = {}
    for item in items.values():
        name_zh = item.get("nameZh")
        if name_zh:
            by_zh.setdefault(name_zh, item["slug"])
    return by_zh


MANUAL_ITEM_OVERRIDES: dict[str, dict[str, str]] = {
    "果实": {"slug": "berry", "nameEn": "Berry"},
}


def merge_extra_items(
    staging: Path, extra_data: dict[str, Any]
) -> tuple[int, list[str]]:
    items_path = staging / "items.json"
    items = json.loads(items_path.read_text(encoding="utf-8"))
    by_zh = {item["nameZh"]: item["slug"] for item in items.values()}
    next_id = max(int(k) for k in items.keys()) + 1
    added = 0
    merged: dict[str, dict[str, Any]] = {}
    for zh_name, item in (extra_data.get("itemsByZhName") or {}).items():
        merged[zh_name] = item
    for zh_name, enname in (extra_data.get("unresolvedWithEnname") or {}).items():
        merged[zh_name] = {
            "slug": MANUAL_ITEM_OVERRIDES.get(zh_name, {}).get(
                "slug", enname.lower().replace(" ", "-").replace("'", "")
            ),
            "nameEn": MANUAL_ITEM_OVERRIDES.get(zh_name, {}).get("nameEn", enname),
            "nameZh": zh_name,
            "category": "held-items",
            "categoryZh": "携带道具",
            "cost": 0,
            "spriteUrl": None,
            "descriptionZh": "",
            "effectZh": "",
        }
    unresolved: list[str] = []
    for zh_name, item in sorted(merged.items()):
        if zh_name in by_zh:
            continue
        slug = str(item["slug"])
        items[str(next_id)] = {
            "id": next_id,
            "slug": slug,
            "nameEn": item.get("nameEn") or slug,
            "nameZh": item.get("nameZh") or zh_name,
            "category": item.get("category") or "held-items",
            "categoryZh": item.get("categoryZh") or "携带道具",
            "cost": int(item.get("cost") or 0),
            "spriteUrl": item.get("spriteUrl"),
            "descriptionZh": item.get("descriptionZh") or "",
            "effectZh": item.get("effectZh") or "",
        }
        next_id += 1
        added += 1
    items_path.write_text(
        json.dumps(items, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return added, unresolved


def patch_details(
    staging: Path, held_data: dict[str, Any], by_zh: dict[str, str]
) -> tuple[int, int]:
    entries = {str(item["id"]): item for item in held_data.get("entries", [])}
    patched = 0
    unresolved: set[str] = set()
    for path in sorted((staging / "details").glob("*.json")):
        detail = json.loads(path.read_text(encoding="utf-8"))
        species_id = str(detail.get("summary", {}).get("id") or path.stem)
        item = entries.get(species_id)
        if not item:
            continue
        merged: dict[str, dict[str, float]] = {}
        for existing in detail.get("heldItems") or []:
            merged[existing["slug"]] = dict(existing.get("rarityByVersion") or {})
        changed = False
        for version, rows in (item.get("versions") or {}).items():
            for row in rows:
                slug = by_zh.get(row.get("itemZh", ""))
                if not slug:
                    unresolved.add(row.get("itemZh", ""))
                    continue
                rates = merged.setdefault(slug, {})
                old = rates.get(version)
                rate = row.get("rate")
                if rate is None:
                    known = [
                        value for value in rates.values() if value is not None
                    ]
                    rate = max(known) if known else 5.0
                if old == rate:
                    continue
                rates[version] = rate
                changed = True
        if changed:
            held = [
                {
                    "slug": slug,
                    "rarityByVersion": dict(sorted(rates.items())),
                    "maxRarity": max(rates.values()) if rates else 0,
                }
                for slug, rates in sorted(merged.items())
                if rates
            ]
            detail["heldItems"] = held
            path.write_text(
                json.dumps(detail, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            patched += 1
    return patched, unresolved


def write_attribution(upload_root: Path, held_data: dict[str, Any]) -> None:
    source = held_data.get("source") or {}
    lines = [
        "TitoDex wild held-item data for versions missing from PokeAPI",
        "comes from 52poke wiki and is used under CC BY-NC-SA 4.0.",
        "",
        f"Source: {source.get('url', 'https://wiki.52poke.com')}",
        f"License: {source.get('license', 'CC BY-NC-SA 4.0')}",
        f"FetchedAt: {held_data.get('fetchedAt', '')}",
        f"Species: {len(held_data.get('entries', []))}",
        "",
        "52poke (神奇宝贝百科) content is licensed under CC BY-NC-SA 4.0.",
        "The original pages remain the canonical source of the data.",
    ]
    (upload_root / "HELD_ITEMS_ATTRIBUTION.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )


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

    held_data = json.loads(args.held_json.read_text(encoding="utf-8"))
    extra_path = args.extra_items_json
    if extra_path and extra_path.is_file():
        extra_data = json.loads(extra_path.read_text(encoding="utf-8"))
        added_items, unresolved_items = merge_extra_items(staging, extra_data)
        print(
            f"items.json: +{added_items} new items "
            f"({len(unresolved_items)} unresolved)",
            flush=True,
        )
    by_zh = load_item_slugs(staging)
    patched, unresolved = patch_details(staging, held_data, by_zh)
    if unresolved:
        print(f"warning: {len(unresolved)} unresolved item names: "
              f"{sorted(unresolved)[:20]}", flush=True)

    manifest_path = staging / "manifest.json"
    base_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    base_manifest.update(
        {
            "version": BUNDLE_VERSION,
            "downloadedAt": published_at,
            "heldItemsSource": "PokeAPI + 52poke (CC BY-NC-SA 4.0)",
            "heldItemsPatchedSpecies": patched,
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
    write_attribution(staging, held_data)
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
            "archiveUrl": V16_ARCHIVE,
            "archiveSha256": archive_sha,
            "archiveSizeBytes": (versioned / ARCHIVE_NAME).stat().st_size,
            "publishedAt": published_at,
            "heldItemsSource": "PokeAPI + 52poke (CC BY-NC-SA 4.0)",
            "heldItemsPatchedSpecies": patched,
        }
    )
    (upload_root / "bundle-manifest.json").write_text(
        json.dumps(root_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"\n--- v{BUNDLE_VERSION} held-items summary ---", flush=True)
    print(f"  species patched               {patched}", flush=True)
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
        description="Patch TitoDex v15 -> v16 (52poke wild held items)"
    )
    parser.add_argument(
        "--held-json",
        type=Path,
        default=ROOT / "data" / "l10n" / "zh" / "held_items_52poke.json",
    )
    parser.add_argument(
        "--extra-items-json",
        type=Path,
        default=ROOT / "data" / "l10n" / "zh" / "items_52poke_extra.json",
        help="Optional resolved/extra items to merge into items.json",
    )
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "dex-v16")
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
