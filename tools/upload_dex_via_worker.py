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
        default=Path("dist/dex-v2/upload"),
    )
    args = parser.parse_args()
    upload_dir = args.upload_dir
    v2 = upload_dir / "v2"
    if not v2.exists():
        print(f"Missing {v2}", file=sys.stderr)
        sys.exit(1)

    session = requests.Session()
    put_file(session, "bundle-manifest.json", upload_dir / "bundle-manifest.json")
    for name in ("manifest.json", "summaries.json", "types.json", "moves.json", "bundle.tar.zst"):
        put_file(session, f"v2/{name}", v2 / name)
    for folder in ("details", "sprites", "type_icons"):
        for file in sorted((v2 / folder).rglob("*")):
            if file.is_file():
                rel = file.relative_to(v2).as_posix()
                put_file(session, f"v2/{rel}", file)
    print("Upload complete.")


if __name__ == "__main__":
    main()
