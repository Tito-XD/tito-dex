#!/usr/bin/env python3
"""Delete legacy JPEG objects from dex CDN R2 via Worker bootstrap DELETE."""

from __future__ import annotations

import argparse
import sys

import requests

BOOTSTRAP_KEY = "titodex-bootstrap-947b"
CDN_BASE = "https://dex.tito.cafe"

TYPE_NAMES = [
    "normal",
    "fire",
    "water",
    "electric",
    "grass",
    "ice",
    "fighting",
    "poison",
    "ground",
    "flying",
    "psychic",
    "bug",
    "rock",
    "ghost",
    "dragon",
    "dark",
    "steel",
    "fairy",
]


def delete_key(session: requests.Session, key: str) -> bool:
    url = f"{CDN_BASE}/_delete/{key}"
    response = session.delete(url, headers={"x-bootstrap-key": BOOTSTRAP_KEY}, timeout=60)
    if response.status_code == 200:
        print(f"✓ deleted {key}")
        return True
    if response.status_code == 404:
        print(f"· missing {key}")
        return True
    print(f"✗ {key} HTTP {response.status_code}: {response.text[:120]}", file=sys.stderr)
    return False


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-id", type=int, default=493)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    keys = [f"v2/sprites/{i}.jpg" for i in range(1, args.max_id + 1)]
    keys.extend(f"v2/type_icons/{name}.jpg" for name in TYPE_NAMES)

    if args.dry_run:
        for key in keys:
            print(key)
        return

    session = requests.Session()
    failed = 0
    for key in keys:
        if not delete_key(session, key):
            failed += 1

    if failed:
        print(f"\n{failed} deletions failed", file=sys.stderr)
        sys.exit(1)
    print(f"\nDone. Removed up to {len(keys)} legacy JPEG keys.")


if __name__ == "__main__":
    main()
