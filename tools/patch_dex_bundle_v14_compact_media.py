#!/usr/bin/env python3
"""Patch the live TitoDex v13 bundle into v14 with compact offline media.

The v13 archive contains two paths for the same 1,340 clear PNG files:
``artwork/...`` and ``sprites/...``.  Flutter's offline path resolves
``localSpritePath`` under ``sprites/``; the artwork URLs remain useful online
and continue to be served by the existing loose R2 objects.

This patch refuses to remove anything unless every bundled artwork file has a
same-path sprite with identical bytes.  It then removes only the archive's
``artwork/`` directory, bumps both manifests to v14, and writes a local upload
tree.  It never uploads to R2 or changes the live root manifest.
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
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_VERSION = 13
BUNDLE_VERSION = 14
CDN_PREFIX = "v5"
CDN_BASE = "https://dex.tito.cafe"
LIVE_ARCHIVE = f"{CDN_BASE}/{CDN_PREFIX}/bundle.tar.zst"
LIVE_ROOT_MANIFEST = f"{CDN_BASE}/bundle-manifest.json"
ARCHIVE_NAME = f"bundle-v{BUNDLE_VERSION}.tar.zst"
V14_ARCHIVE = f"{CDN_BASE}/{CDN_PREFIX}/{ARCHIVE_NAME}"
USER_AGENT = "TitoDex/1.0 (+bundle build)"


@dataclass(frozen=True)
class CompactMediaStats:
    files: int
    bytes_removed: int


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
            ["zstd", "-dc", str(archive)],
            check=True,
            stdout=subprocess.PIPE,
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
        result = subprocess.run(
            ["zstd", "-19", "--stdout"],
            input=buffer.getvalue(),
            capture_output=True,
            check=True,
        )
        archive_path.write_bytes(result.stdout)
    except (FileNotFoundError, subprocess.CalledProcessError):
        import zstandard

        archive_path.write_bytes(
            zstandard.ZstdCompressor(level=19).compress(buffer.getvalue())
        )


def verify_and_remove_duplicate_artwork(staging: Path) -> CompactMediaStats:
    artwork_dir = staging / "artwork"
    sprites_dir = staging / "sprites"
    artwork_files = sorted(file for file in artwork_dir.rglob("*") if file.is_file())
    if not artwork_files:
        raise ValueError("Base archive has no artwork files to compact")

    problems: list[str] = []
    bytes_removed = 0
    for artwork in artwork_files:
        relative = artwork.relative_to(artwork_dir)
        sprite = sprites_dir / relative
        if not sprite.is_file():
            problems.append(f"missing sprite peer: {relative.as_posix()}")
            continue
        if artwork.stat().st_size != sprite.stat().st_size:
            problems.append(f"size differs: {relative.as_posix()}")
            continue
        if sha256_file(artwork) != sha256_file(sprite):
            problems.append(f"content differs: {relative.as_posix()}")
            continue
        bytes_removed += artwork.stat().st_size

    if problems:
        preview = "; ".join(problems[:10])
        raise ValueError(
            f"Refusing compact-media patch: {len(problems)} artwork peers failed "
            f"validation ({preview})"
        )

    shutil.rmtree(artwork_dir)
    return CompactMediaStats(files=len(artwork_files), bytes_removed=bytes_removed)


def write_manifest_with_size(path: Path, manifest: dict[str, object], root: Path) -> None:
    # sizeBytes includes manifest.json itself.  A second pass makes the value
    # stable if its digit width changed after compaction.
    for _ in range(2):
        manifest["sizeBytes"] = directory_size(root)
        path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


def build(args: argparse.Namespace) -> None:
    output = args.output.resolve()
    staging = output / "staging"
    upload_root = output / "upload"
    for path in (staging, upload_root):
        if path.exists():
            shutil.rmtree(path)
    output.mkdir(parents=True, exist_ok=True)

    if args.base_archive:
        base_archive = args.base_archive.resolve()
        print(f"Using local base archive {base_archive} ...", flush=True)
    else:
        base_archive = output / f"base-v{BASE_VERSION}.tar.zst"
        if base_archive.is_file() and not args.force_download:
            print(f"Reusing cached base archive {base_archive} ...", flush=True)
        else:
            print(f"Downloading live base archive -> {base_archive} ...", flush=True)
            download(LIVE_ARCHIVE, base_archive)

    print(f"Extracting base archive -> {staging} ...", flush=True)
    extract_archive(base_archive, staging)
    (staging / "bundle.tar.zst").unlink(missing_ok=True)

    manifest_path = staging / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("version") != BASE_VERSION or manifest.get("complete") is not True:
        raise ValueError(
            f"Unexpected base manifest: version={manifest.get('version')} "
            f"complete={manifest.get('complete')}"
        )

    print("Verifying artwork/sprite identity and removing archive duplicates ...", flush=True)
    stats = verify_and_remove_duplicate_artwork(staging)
    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    manifest.update(
        {
            "version": BUNDLE_VERSION,
            "downloadedAt": published_at,
            "compactMedia": True,
            "artworkFileCount": 0,
            "artworkAlias": "sprites",
        }
    )
    write_manifest_with_size(manifest_path, manifest, staging)

    if args.base_root_manifest:
        root_manifest = json.loads(
            args.base_root_manifest.resolve().read_text(encoding="utf-8")
        )
    else:
        root_manifest_path = output / "root-manifest-base.json"
        if root_manifest_path.is_file() and not args.force_download:
            print(
                f"Reusing cached root manifest {root_manifest_path} ...",
                flush=True,
            )
        else:
            print("Downloading live root manifest ...", flush=True)
            download(LIVE_ROOT_MANIFEST, root_manifest_path)
        root_manifest = json.loads(root_manifest_path.read_text(encoding="utf-8"))
    if (
        root_manifest.get("bundleVersion") != BASE_VERSION
        or root_manifest.get("cdnPrefix") != CDN_PREFIX
        or root_manifest.get("pokemonCount") != 1025
        or root_manifest.get("complete") is not True
        or root_manifest.get("archiveUrl") != LIVE_ARCHIVE
    ):
        raise ValueError(
            "Unexpected v13 root manifest: "
            f"version={root_manifest.get('bundleVersion')} "
            f"prefix={root_manifest.get('cdnPrefix')} "
            f"pokemonCount={root_manifest.get('pokemonCount')} "
            f"complete={root_manifest.get('complete')} "
            f"archiveUrl={root_manifest.get('archiveUrl')}"
        )

    versioned = upload_root / CDN_PREFIX
    upload_root.mkdir(parents=True, exist_ok=True)
    print("Creating compact v14 archive ...", flush=True)
    create_zst_tar(staging, staging / ARCHIVE_NAME)
    shutil.copytree(staging, versioned)
    archive = versioned / ARCHIVE_NAME
    archive_sha = sha256_file(archive)

    root_manifest.update(
        {
            "bundleVersion": BUNDLE_VERSION,
            "archiveUrl": V14_ARCHIVE,
            "archiveSha256": archive_sha,
            "archiveSizeBytes": archive.stat().st_size,
            "publishedAt": published_at,
            "compactMedia": True,
            "artworkFileCount": 0,
            "artworkAlias": "sprites",
        }
    )
    (upload_root / "bundle-manifest.json").write_text(
        json.dumps(root_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("\n--- v14 compact-media prerelease ---", flush=True)
    print(f"  duplicate artwork files removed  {stats.files:,}", flush=True)
    print(f"  duplicate bytes removed          {stats.bytes_removed:,}", flush=True)
    print(f"  archive bytes                    {archive.stat().st_size:,}", flush=True)
    print(f"  archive sha256                   {archive_sha}", flush=True)
    print(f"  output                           {upload_root}", flush=True)
    print("\nBuilt locally; R2 and the live manifest are untouched.", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Patch TitoDex v13 -> v14 (compact offline media)"
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "dist" / "dex-v14-prerelease",
    )
    parser.add_argument(
        "--base-archive",
        type=Path,
        help="Local v13 bundle.tar.zst instead of downloading the live one",
    )
    parser.add_argument(
        "--base-root-manifest",
        type=Path,
        help="Local v13 root manifest instead of downloading the live one",
    )
    parser.add_argument(
        "--force-download",
        action="store_true",
        help="Re-download the live archive even if the cached copy exists",
    )
    build(parser.parse_args())


if __name__ == "__main__":
    main()
