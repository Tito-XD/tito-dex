#!/usr/bin/env python3
"""Patch the live TitoDex bundle into v15 with 52poke zh-Hans flavor text.

Only entries whose current text contains no CJK characters are replaced, so
existing PokeAPI zh entries stay untouched. Adds a CC BY-NC-SA 4.0 attribution
file and bumps both manifests to v15. Never uploads to R2.
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
BASE_VERSION = 14
BUNDLE_VERSION = 15
CDN_PREFIX = "v5"
CDN_BASE = "https://dex.tito.cafe"
LIVE_ARCHIVE = f"{CDN_BASE}/{CDN_PREFIX}/bundle.tar.zst"
LIVE_ROOT_MANIFEST = f"{CDN_BASE}/bundle-manifest.json"
ARCHIVE_NAME = f"bundle-v{BUNDLE_VERSION}.tar.zst"
V15_ARCHIVE = f"{CDN_BASE}/{CDN_PREFIX}/{ARCHIVE_NAME}"
USER_AGENT = "TitoDex/1.0 (+bundle build)"

CJK_RE = re.compile(r"[\u4e00-\u9fff]")


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

        archive_path.write_bytes(zstandard.ZstdCompressor().compress(buffer.getvalue()))


def load_games_index(staging: Path) -> dict[str, dict[str, Any]]:
    games = json.loads((staging / "games.json").read_text(encoding="utf-8"))
    return {
        str(edition["slug"]): edition
        for edition in games
        if edition.get("flavorVersions")
    }


def patch_details(staging: Path, flavor_data: dict[str, Any]) -> int:
    entries = {str(item["id"]): item for item in flavor_data.get("entries", [])}
    games = load_games_index(staging)
    edition_by_version: dict[str, dict[str, Any]] = {}
    for edition in games.values():
        for version in edition["flavorVersions"]:
            edition_by_version.setdefault(version, edition)
    patched = 0
    for path in sorted((staging / "details").glob("*.json")):
        detail = json.loads(path.read_text(encoding="utf-8"))
        species_id = str(detail.get("summary", {}).get("id") or path.stem)
        item = entries.get(species_id)
        if not item:
            continue
        versions = item.get("versions") or {}
        changed = False
        present = {entry.get("version") for entry in detail.get("flavorEntries") or []}
        for entry in detail.get("flavorEntries") or []:
            version = entry.get("version")
            zh = versions.get(version) if version else None
            if not zh:
                continue
            if CJK_RE.search(entry.get("text", "")):
                continue
            entry["text"] = zh
            entry["source"] = "52poke"
            changed = True
        for version, zh in versions.items():
            if version in present:
                continue
            edition = edition_by_version.get(version)
            if not edition:
                continue
            detail.setdefault("flavorEntries", []).append(
                {
                    "gameEdition": edition["slug"],
                    "versionGroup": edition["versionGroup"],
                    "version": version,
                    "labelZh": edition["labelZh"],
                    "iconUrl": edition["iconUrl"],
                    "text": zh,
                    "source": "52poke",
                }
            )
            changed = True
        if changed:
            path.write_text(
                json.dumps(detail, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            patched += 1
    return patched


def merge_flavor_entries(
    fetched: dict[str, Any], manual: dict[str, Any] | None
) -> dict[str, Any]:
    merged = dict(fetched)
    for item in (manual or {}).get("entries", []):
        key = str(item["id"])
        if key not in merged:
            merged[key] = dict(item)
            continue
        merged[key] = {
            **merged[key],
            "versions": {
                **merged[key].get("versions", {}),
                **item.get("versions", {}),
            },
        }
    return merged


def write_attribution(upload_root: Path, flavor_data: dict[str, Any]) -> None:
    source = flavor_data.get("source") or {}
    lines = [
        "TitoDex flavor text for versions missing zh-Hans in PokeAPI",
        "comes from 52poke wiki and is used under CC BY-NC-SA 4.0.",
        "",
        f"Source: {source.get('url', 'https://wiki.52poke.com')}",
        f"License: {source.get('license', 'CC BY-NC-SA 4.0')}",
        f"FetchedAt: {flavor_data.get('fetchedAt', '')}",
        f"Species: {len(flavor_data.get('entries', []))}",
        "",
        "52poke (神奇宝贝百科) content is licensed under CC BY-NC-SA 4.0.",
        "The original pages remain the canonical source of the text.",
    ]
    (upload_root / "FLAVOR_ATTRIBUTION.txt").write_text(
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

    flavor_data = json.loads(args.flavor_json.read_text(encoding="utf-8"))
    if args.manual_json and args.manual_json.is_file():
        manual_data = json.loads(args.manual_json.read_text(encoding="utf-8"))
        entries = merge_flavor_entries(
            {str(item["id"]): item for item in flavor_data.get("entries", [])},
            manual_data,
        )
        flavor_data = {**flavor_data, "entries": list(entries.values())}
    patched = patch_details(staging, flavor_data)

    manifest_path = staging / "manifest.json"
    base_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    base_manifest.update(
        {
            "version": BUNDLE_VERSION,
            "downloadedAt": published_at,
            "flavorTextSource": "PokeAPI + 52poke (CC BY-NC-SA 4.0)",
            "flavorTextPatchedSpecies": patched,
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
    write_attribution(staging, flavor_data)
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
            "archiveUrl": V15_ARCHIVE,
            "archiveSha256": archive_sha,
            "archiveSizeBytes": (versioned / ARCHIVE_NAME).stat().st_size,
            "publishedAt": published_at,
            "flavorTextSource": "PokeAPI + 52poke (CC BY-NC-SA 4.0)",
            "flavorTextPatchedSpecies": patched,
        }
    )
    (upload_root / "bundle-manifest.json").write_text(
        json.dumps(root_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"\n--- v{BUNDLE_VERSION} flavor-text summary ---", flush=True)
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
        description="Patch TitoDex v14 -> v15 (52poke zh-Hans flavor text)"
    )
    parser.add_argument(
        "--flavor-json",
        type=Path,
        default=ROOT / "data" / "l10n" / "zh" / "flavor_text_52poke.json",
    )
    parser.add_argument(
        "--manual-json",
        type=Path,
        default=ROOT / "data" / "l10n" / "zh" / "flavor_text_manual.json",
        help="Optional maintainer-supplied flavor entries merged on top of the fetched file",
    )
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "dex-v15")
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
