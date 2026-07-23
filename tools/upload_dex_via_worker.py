#!/usr/bin/env python3
"""Upload dex bundle to R2 via Worker bootstrap PUT (one-time)."""

from __future__ import annotations

import argparse
import mimetypes
import sys
from pathlib import Path

import requests

BOOTSTRAP_KEY = "titodex-bootstrap-947b"
CDN_BASE = "https://dex.tito.cafe"
DEFAULT_CDN_PREFIX = "v4"
LEGACY_CDN_PREFIX = "v2"


def resolve_bundle_dir(upload_dir: Path, cdn_prefix: str) -> Path:
    bundle_dir = upload_dir / cdn_prefix
    if bundle_dir.is_dir():
        return bundle_dir
    if cdn_prefix == DEFAULT_CDN_PREFIX and (upload_dir / LEGACY_CDN_PREFIX).is_dir():
        print(
            f"Note: {bundle_dir} missing; falling back to upload/{LEGACY_CDN_PREFIX}",
            file=sys.stderr,
        )
        return upload_dir / LEGACY_CDN_PREFIX
    raise FileNotFoundError(f"Missing bundle directory: {bundle_dir}")


def put_file(session: requests.Session, key: str, path: Path) -> None:
    content_type = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
    url = f"{CDN_BASE}/_put/{key}"
    print(f"→ {key} ({path.stat().st_size:,} bytes)")
    with path.open("rb") as handle:
        response = session.put(
            url,
            data=handle,
            headers={
                "x-bootstrap-key": BOOTSTRAP_KEY,
                "content-type": content_type,
            },
            timeout=600,
        )
    response.raise_for_status()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "upload_dir",
        type=Path,
        nargs="?",
        default=Path("dist/dex-v6/upload"),
    )
    parser.add_argument(
        "--cdn-prefix",
        default=DEFAULT_CDN_PREFIX,
        help=f"CDN path prefix (default: {DEFAULT_CDN_PREFIX})",
    )
    args = parser.parse_args()
    upload_dir = args.upload_dir
    try:
        bundle_dir = resolve_bundle_dir(upload_dir, args.cdn_prefix)
    except FileNotFoundError as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)

    session = requests.Session()
    put_file(session, "bundle-manifest.json", upload_dir / "bundle-manifest.json")
    for name in (
        "manifest.json",
        "summaries.json",
        "types.json",
        "moves.json",
        "abilities.json",
        "bundle.tar.zst",
    ):
        file = bundle_dir / name
        if not file.exists():
            if name == "abilities.json":
                print(f"  skip missing {name} (pre-v5 bundle)", file=sys.stderr)
                continue
            print(f"Missing {file}", file=sys.stderr)
            sys.exit(1)
        put_file(session, f"{args.cdn_prefix}/{name}", file)
    for folder in ("details", "sprites", "type_icons", "artwork"):
        folder_path = bundle_dir / folder
        if not folder_path.exists():
            continue
        for file in sorted(folder_path.rglob("*")):
            if file.is_file():
                rel = file.relative_to(bundle_dir).as_posix()
                put_file(session, f"{args.cdn_prefix}/{rel}", file)
    print("Upload complete.")


if __name__ == "__main__":
    main()
