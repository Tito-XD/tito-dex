#!/usr/bin/env python3
"""Verify a complete TitoDex upload tree and its archive before publishing."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import tarfile
from pathlib import Path
from urllib.parse import urlparse

import zstandard


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify(upload_dir: Path) -> None:
    root = json.loads((upload_dir / "bundle-manifest.json").read_text(encoding="utf-8"))
    bundle_version = int(root["bundleVersion"])
    cdn_prefix = str(root["cdnPrefix"])
    versioned = upload_dir / cdn_prefix
    manifest = json.loads((versioned / "manifest.json").read_text(encoding="utf-8"))
    archive_path = Path(urlparse(str(root["archiveUrl"])).path)
    assert archive_path.parent.name == cdn_prefix, root
    assert archive_path.name.startswith("bundle") and archive_path.name.endswith(
        ".tar.zst"
    ), root
    archive = versioned / archive_path.name

    assert bundle_version >= 6, root
    # v7+ patches in place over /v5/; earlier releases used v{bundle_version - 2}.
    expected_prefix = "v5" if bundle_version >= 7 else f"v{bundle_version - 2}"
    assert cdn_prefix == expected_prefix, root
    assert root["pokemonCount"] == 1025, root
    assert root["complete"] is True, root
    assert root["exactVersionLocations"] is True, root
    assert root["archiveSha256"] == sha256(archive), "archive SHA-256 mismatch"
    assert root["archiveSizeBytes"] == archive.stat().st_size, root
    assert manifest["version"] == bundle_version, manifest
    assert manifest["pokemonCount"] == 1025, manifest
    assert manifest["complete"] is True, manifest
    assert manifest["formCount"] == root["formCount"], (manifest, root)

    details = list((versioned / "details").glob("*.json"))
    sprites = list((versioned / "sprites").glob("[0-9]*.png"))
    form_sprites = list((versioned / "sprites" / "forms").glob("*.png"))
    assert len(details) == 1025, f"expected 1025 details, found {len(details)}"
    assert len(sprites) == 1025, f"expected 1025 default sprites, found {len(sprites)}"
    assert len(form_sprites) == root["formSpriteCount"], (
        len(form_sprites),
        root["formSpriteCount"],
    )
    # Form artwork may be bundled (v11 already ships 315 files under
    # artwork/forms/); the app falls back to CDN when a form image is missing,
    # so bulk presence is not a release blocker.

    decompressed = zstandard.ZstdDecompressor().decompress(
        archive.read_bytes(), max_output_size=2 * 1024 * 1024 * 1024
    )
    with tarfile.open(fileobj=io.BytesIO(decompressed), mode="r:") as tar:
        names = set(tar.getnames())
    required = {
        "manifest.json",
        "summaries.json",
        "details/1.json",
        "details/1025.json",
        "sprites/1.png",
        "sprites/1025.png",
        "games.json",
        "l10n/zh/location_area_labels.json",
        "l10n/zh/location_area_id_to_slug.json",
    }
    missing = sorted(required - names)
    assert not missing, f"archive missing: {missing}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("upload_dir", type=Path)
    args = parser.parse_args()
    verify(args.upload_dir)
    print(f"OK: verified TitoDex upload tree at {args.upload_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
