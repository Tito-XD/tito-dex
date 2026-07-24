#!/usr/bin/env python3
"""Patch v8 staging to v9: ensure every form has an artworkUrl fallback.

Forms that received a distinct v8 artwork keep it. Forms that inherit the
species default sprite now point artworkUrl at the existing CDN artwork.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tarfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

try:
    import zstandard as zstd
except ImportError:  # pragma: no cover
    zstd = None  # type: ignore[assignment]

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_dex_bundle import (  # noqa: E402
    directory_size,
    sha256_file,
)

BUNDLE_VERSION = 9
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


def create_archive(staging: Path, archive_path: Path) -> None:
    archive_path.unlink(missing_ok=True)
    if zstd is not None:
        compressor = zstd.ZstdCompressor(level=10, threads=-1)
        with archive_path.open("wb") as raw:
            with compressor.stream_writer(raw, closefd=False) as compressed:
                with tarfile.open(fileobj=compressed, mode="w|") as tar:
                    for path in sorted(staging.rglob("*")):
                        if path == archive_path or not path.is_file():
                            continue
                        tar.add(path, arcname=path.relative_to(staging), recursive=False)
        return

    subprocess.run(
        [
            "tar",
            "--use-compress-program=zstd -10 -T0",
            "-cf",
            str(archive_path),
            "-C",
            str(staging),
            ".",
        ],
        check=True,
    )


def write_manifests(staging: Path, upload_root: Path, cdn_base: str) -> None:
    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    archive_path = staging / "bundle.tar.zst"
    archive_path.unlink(missing_ok=True)
    manifest_path = staging / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["version"] = BUNDLE_VERSION
    manifest["downloadedAt"] = published_at
    manifest["sizeBytes"] = directory_size(staging)
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("Creating v9 archive...", flush=True)
    create_archive(staging, archive_path)

    versioned = upload_root / CDN_PREFIX
    if versioned.exists():
        shutil.rmtree(versioned)
    shutil.copytree(staging, versioned)

    archive_sha = sha256_file(versioned / "bundle.tar.zst")
    root_manifest = {
        "bundleVersion": BUNDLE_VERSION,
        "pokemonCount": int(manifest["pokemonCount"]),
        "formCount": int(manifest.get("formCount") or 0),
        "formSpriteCount": int(manifest.get("formSpriteCount") or 0),
        "schemaFeatures": manifest.get("schemaFeatures") or {},
        "cdnPrefix": CDN_PREFIX,
        "complete": bool(manifest["complete"]),
        "exactVersionLocations": bool(manifest.get("exactVersionLocations")),
        "encounterSources": manifest.get("encounterSources") or [],
        "encounterCoverage": manifest.get("encounterCoverage") or {},
        "archiveUrl": f"{cdn_base.rstrip('/')}/{CDN_PREFIX}/bundle.tar.zst",
        "archiveSha256": archive_sha,
        "archiveSizeBytes": (versioned / "bundle.tar.zst").stat().st_size,
        "publishedAt": published_at,
        "l10nVersion": manifest.get("l10nVersion"),
        "configVersion": manifest.get("configVersion"),
    }
    (upload_root / "bundle-manifest.json").write_text(
        json.dumps(root_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Archive SHA256: {archive_sha}", flush=True)
    print(
        f"Archive bytes: {root_manifest['archiveSizeBytes']:,}",
        flush=True,
    )


def upload_bundle_and_manifest(upload_root: Path) -> None:
    bundle_path = upload_root / CDN_PREFIX / "bundle.tar.zst"
    manifest_path = upload_root / CDN_PREFIX / "manifest.json"
    root_manifest_path = upload_root / "bundle-manifest.json"

    print("Uploading bundle.tar.zst...", flush=True)
    r2_put(bundle_path, f"{CDN_PREFIX}/bundle.tar.zst", "application/zstd")
    print("Uploading manifest.json...", flush=True)
    r2_put(manifest_path, f"{CDN_PREFIX}/manifest.json", "application/json")
    print("Uploading root bundle-manifest.json...", flush=True)
    r2_put(root_manifest_path, "bundle-manifest.json", "application/json")


def patch(staging: Path, upload_root: Path) -> None:
    updated = 0
    for path in sorted((staging / "details").glob("*.json")):
        species_id = int(path.stem)
        detail = json.loads(path.read_text(encoding="utf-8"))
        changed = False
        for form in detail.get("forms") or []:
            if form.get("artworkUrl"):
                continue
            # Point forms without distinct artwork at the species default artwork.
            form["artworkUrl"] = f"{CDN_BASE}/{CDN_PREFIX}/artwork/{species_id}.png"
            changed = True
            updated += 1
        if changed:
            path.write_text(
                json.dumps(detail, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
    print(f"Added fallback artworkUrl to {updated} forms.", flush=True)

    upload_root.mkdir(parents=True, exist_ok=True)
    write_manifests(staging, upload_root, CDN_BASE)
    upload_bundle_and_manifest(upload_root)
    print(f"Done: {upload_root}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--staging", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("dist/dex-v9"))
    args = parser.parse_args()
    patch(args.staging.resolve(), args.output.resolve())


if __name__ == "__main__":
    main()
