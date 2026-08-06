#!/usr/bin/env python3
"""Download item sprite URLs from PokeAPI/52poke into data/assets/item-sprites."""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import requests

from fetch_52poke_flavor_text import ROOT, USER_AGENT

DEFAULT_EXTRA = ROOT / "data" / "l10n" / "zh" / "items_all_extra.json"
DEFAULT_OUT = ROOT / "data" / "assets" / "item-sprites"


def main() -> int:
    parser = argparse.ArgumentParser(description="Download item sprites")
    parser.add_argument("--extra-json", type=Path, default=DEFAULT_EXTRA)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--delay", type=float, default=0.15)
    args = parser.parse_args()

    extra = json.loads(args.extra_json.read_text(encoding="utf-8"))
    items = extra.get("itemsBySlug", {})
    args.output.mkdir(parents=True, exist_ok=True)
    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})
    downloaded = 0
    failed: list[str] = []
    for slug, item in sorted(items.items()):
        url = item.get("spriteUrl")
        if not url:
            continue
        dest = args.output / f"{slug}.png"
        if dest.exists():
            continue
        try:
            response = session.get(url, timeout=30)
            if response.status_code != 200 or not response.content:
                failed.append(slug)
                continue
            dest.write_bytes(response.content)
            downloaded += 1
        except requests.RequestException:
            failed.append(slug)
        time.sleep(args.delay)
    print(
        f"done: {downloaded} downloaded, {len(failed)} failed, "
        f"{len(list(args.output.glob('*.png')))} total in {args.output}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
