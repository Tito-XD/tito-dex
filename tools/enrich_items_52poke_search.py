#!/usr/bin/env python3
"""Second 52poke pass: resolve the newest items by English-name search.

Items with no PokeAPI zh name (SV-DLC mochi/masks/teacups, LA balls, a few Gen 9
held items) can't be looked up by a Chinese title. 52poke's search finds them by
English name — the first result is the item page `XXX（道具）`. From that page we
take the zh name (title minus the （道具） suffix) and the in-game zh-hans bag
description, same extraction as enrich_items_52poke.py.

52poke content is CC BY-NC-SA 3.0 (attribution ships with the bundle).

Run: python3 tools/enrich_items_52poke_search.py [--items dist/items-v11-work/items.json]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from enrich_items_52poke import _client, extract_description, fetch_wikitext  # noqa: E402

ITEM_SUFFIX = "（道具）"


def search_item_page(name_en: str, *, retries: int = 3) -> str | None:
    for attempt in range(retries):
        try:
            titles = _client().search_titles(name_en, limit=3)
            for title in titles:
                if title.endswith(ITEM_SUFFIX):
                    return title
            return titles[0] if titles else None
        except Exception:  # noqa: BLE001 - best-effort legacy enrichment
            if attempt == retries - 1:
                return None
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description="Resolve newest items via 52poke English search")
    parser.add_argument("--items", type=Path, default=ROOT / "dist" / "items-v11-work" / "items.json")
    args = parser.parse_args()

    items = json.loads(args.items.read_text(encoding="utf-8"))
    targets = [
        it for it in items.values()
        if not it.get("descriptionZh") or not it.get("nameZh") or it["nameZh"] == it.get("nameEn")
    ]
    print(f"Items to resolve by English search: {len(targets)}", flush=True)

    named = desc_filled = 0
    for i, it in enumerate(targets, start=1):
        title = search_item_page(it["nameEn"])
        if title:
            if title.endswith(ITEM_SUFFIX) and (not it.get("nameZh") or it["nameZh"] == it["nameEn"]):
                it["nameZh"] = title[: -len(ITEM_SUFFIX)]
                named += 1
            if not it.get("descriptionZh"):
                wt = fetch_wikitext(title)
                if wt:
                    desc = extract_description(wt)
                    if desc:
                        it["descriptionZh"] = desc
                        it["effectZh"] = desc
                        desc_filled += 1
        if i % 10 == 0 or i == len(targets):
            print(f"  {i}/{len(targets)} (names {named}, descs {desc_filled})", flush=True)
    args.items.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    no_name = sum(1 for it in items.values() if not it.get("nameZh") or it["nameZh"] == it.get("nameEn"))
    no_desc = sum(1 for it in items.values() if not it.get("descriptionZh"))
    print(f"\nFilled {named} names, {desc_filled} descriptions.", flush=True)
    print(f"Remaining: no-name {no_name}, no-desc {no_desc} / {len(items)}", flush=True)


if __name__ == "__main__":
    main()
