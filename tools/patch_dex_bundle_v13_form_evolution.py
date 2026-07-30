#!/usr/bin/env python3
"""Patch the live TitoDex v12 bundle into v13: per-form evolution chains.

v12 already shipped species search axes on /v5/, but forms still lacked their
own ``evolutionChain``.  Clients on an older app build prune the species chain
with ``filteredForForm``; this release bakes the resolved chain (with real form
sprites) into every non-cosmetic form so a fresh offline install shows
洗翠卡蒂狗 → 洗翠风速狗 without relying on the in-app table.

Base is the *published* v12 archive — sprites, artwork, encounters, items and
the v12 axes stay byte-identical.  Only ``details/*.json`` gain
``forms[].evolutionChain``, then the archive + manifests bump to 13.

Uploading is intentionally NOT part of this script:

    python3 tools/patch_dex_bundle_v13_form_evolution.py
    python3 tools/verify_dex_upload_tree.py dist/dex-v13/upload
    python3 tools/upload_dex_bundle_r2.py dist/dex-v13/upload \\
        --cdn-prefix v5 --phase objects
    python3 tools/upload_dex_bundle_r2.py dist/dex-v13/upload \\
        --cdn-prefix v5 --phase manifest
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import shutil
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from form_evolution_chains import apply_form_evolution_chains  # noqa: E402

BASE_VERSION = 12
BUNDLE_VERSION = 13
CDN_PREFIX = "v5"
CDN_BASE = "https://dex.tito.cafe"
LIVE_ARCHIVE = f"{CDN_BASE}/{CDN_PREFIX}/bundle.tar.zst"
LIVE_ROOT_MANIFEST = f"{CDN_BASE}/bundle-manifest.json"
USER_AGENT = "TitoDex/1.0 (+bundle build)"


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
    with tarfile_open_write(buffer) as tar:
        for file in sorted(source_dir.rglob("*")):
            if not file.is_file() or file.name == "bundle.tar.zst":
                continue
            tar.add(file, arcname=file.relative_to(source_dir).as_posix())
    process = subprocess.run(
        ["zstd", "-19", "--stdout"],
        input=buffer.getvalue(),
        capture_output=True,
        check=True,
    )
    archive_path.write_bytes(process.stdout)


def tarfile_open_write(buffer: io.BytesIO):
    import tarfile

    return tarfile.open(fileobj=buffer, mode="w")


def download(url: str, dest: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=180) as response:
        with open(dest, "wb") as handle:
            shutil.copyfileobj(response, handle)


def extract_archive(archive: Path, dest: Path) -> None:
    import tarfile

    dest.mkdir(parents=True, exist_ok=True)
    zstd = subprocess.run(
        ["zstd", "-dc", str(archive)], check=True, stdout=subprocess.PIPE
    )
    with tarfile.open(fileobj=io.BytesIO(zstd.stdout), mode="r:") as tar:
        tar.extractall(dest)


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
            print(f"Downloading live base archive → {base_archive} ...", flush=True)
            download(LIVE_ARCHIVE, base_archive)

    print(f"Extracting base archive → {staging} ...", flush=True)
    extract_archive(base_archive, staging)
    (staging / "bundle.tar.zst").unlink(missing_ok=True)

    base_manifest = json.loads(
        (staging / "manifest.json").read_text(encoding="utf-8")
    )
    if base_manifest.get("version") != BASE_VERSION or not base_manifest.get(
        "complete"
    ):
        raise ValueError(
            f"Unexpected base manifest (want v{BASE_VERSION} complete): "
            f"version={base_manifest.get('version')} "
            f"complete={base_manifest.get('complete')}"
        )

    details_dir = staging / "details"
    print("Resolving per-form evolution chains…", flush=True)
    form_chains, problems = apply_form_evolution_chains(
        details_dir, compact=True
    )
    for problem in problems:
        print(f"  warn: {problem}", file=sys.stderr)
    if problems:
        raise ValueError(
            f"{len(problems)} form evolution chains could not be resolved; "
            "fix tools/form_evolution_chains.py before publishing"
        )
    print(f"Wrote {form_chains} per-form evolution chains.", flush=True)

    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    base_manifest.update(
        {
            "version": BUNDLE_VERSION,
            "downloadedAt": published_at,
            "formsWithEvolutionChain": form_chains,
        }
    )
    base_manifest["sizeBytes"] = directory_size(staging)
    (staging / "manifest.json").write_text(
        json.dumps(base_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    versioned = upload_root / CDN_PREFIX
    upload_root.mkdir(parents=True, exist_ok=True)
    print("Creating v13 archive …", flush=True)
    create_zst_tar(staging, staging / "bundle.tar.zst")
    shutil.copytree(staging, versioned)
    archive_sha = sha256_file(versioned / "bundle.tar.zst")

    if args.base_root_manifest:
        root_manifest = json.loads(
            args.base_root_manifest.read_text(encoding="utf-8")
        )
    else:
        print("Downloading live root manifest …", flush=True)
        root_manifest_path = output / "root-manifest-base.json"
        download(LIVE_ROOT_MANIFEST, root_manifest_path)
        root_manifest = json.loads(
            root_manifest_path.read_text(encoding="utf-8")
        )
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

    print("\n--- v13 summary ---", flush=True)
    print(f"  forms with evolutionChain    {form_chains}", flush=True)
    print(f"  archive sha256               {archive_sha}", flush=True)
    print(
        f"  archive bytes                "
        f"{root_manifest['archiveSizeBytes']:,}",
        flush=True,
    )
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
        description="Patch TitoDex v12 → v13 (per-form evolution chains)"
    )
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "dex-v13")
    parser.add_argument(
        "--base-archive",
        type=Path,
        help="Local v12 bundle.tar.zst instead of downloading the live one",
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
