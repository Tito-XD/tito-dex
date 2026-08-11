#!/usr/bin/env python3
"""Fill missing Simplified-Chinese item descriptions from 52poke (神奇宝贝百科).

PokeAPI's `zh-hans` flavor covers most items, but the newest Gen 8/9 additions
(tera shards, SV mochi/masks, some held items) have no zh-hans entry yet. For
those, 52poke's 包包信息框 template carries the exact in-game Simplified-Chinese
bag description as `-{zh-hans:…;zh-hant:…}-`, with a `==使用效果==` prose section
as a secondary source. This build-time pass fills `descriptionZh`/`effectZh` for
gap items that have a Chinese name (used as the 52poke page title).

52poke content is CC BY-NC-SA 3.0 — attribution ships in the bundle (see the
attribution file written by the v11 patch). Nothing here runs in the app.

Run: python3 tools/enrich_items_52poke.py [--items dist/items-v11-work/items.json]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API = "https://wiki.52poke.com/api.php"

_LINK = re.compile(r"\[\[(?:[^\]|]*\|)?([^\]|]+)\]\]")   # [[a|b]] -> b, [[a]] -> a
_TEMPLATE = re.compile(r"\{\{[^{}]*\}\}")
_ZH_HANS = re.compile(r"zh-hans:\s*([^;{}]+?)\s*;\s*zh-hant:")
_USE_EFFECT = re.compile(r"==\s*使用效果\s*==\s*\n(.+?)(?:\n==|\Z)", re.S)


def fetch_wikitext(title: str, *, retries: int = 3) -> str | None:
    params = {
        "action": "parse", "page": title, "prop": "wikitext",
        "format": "json", "redirects": 1,
    }
    url = f"{API}?{urllib.parse.urlencode(params)}"
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "TitoDex/1.0 (+bundle build)"})
            with urllib.request.urlopen(req, timeout=40) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            if "error" in data:
                return None
            return data.get("parse", {}).get("wikitext", {}).get("*")
        except Exception:  # noqa: BLE001
            time.sleep(0.6 * (attempt + 1))
    return None


def _clean(text: str) -> str:
    text = _LINK.sub(r"\1", text)
    text = _TEMPLATE.sub("", text)
    text = text.replace("'''", "").replace("''", "")
    text = re.sub(r"^[\*#:\s]+", "", text)
    return " ".join(text.split())


def extract_description(wikitext: str) -> str | None:
    # Best: the in-game bag description carried as -{zh-hans:…;zh-hant:…}-.
    hans = _ZH_HANS.findall(wikitext)
    if hans:
        best = max((_clean(h) for h in hans), key=len)
        if len(best) >= 6:
            return best
    # Secondary: the 使用效果 prose section (first bullet/line).
    section = _USE_EFFECT.search(wikitext)
    if section:
        first = section.group(1).strip().splitlines()[0]
        cleaned = _clean(first)
        if len(cleaned) >= 6:
            return cleaned
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description="Fill zh item descriptions from 52poke")
    parser.add_argument("--items", type=Path, default=ROOT / "dist" / "items-v11-work" / "items.json")
    args = parser.parse_args()

    items = json.loads(args.items.read_text(encoding="utf-8"))
    gaps = [
        it for it in items.values()
        if not it.get("descriptionZh")
        and it.get("nameZh") and it["nameZh"] != it.get("nameEn")
    ]
    print(f"Gap items with a Chinese name to look up: {len(gaps)}", flush=True)

    filled = 0
    for i, it in enumerate(gaps, start=1):
        wt = fetch_wikitext(it["nameZh"])
        if wt:
            desc = extract_description(wt)
            if desc:
                it["descriptionZh"] = desc
                it["effectZh"] = desc
                it["_descSource"] = "52poke"
                filled += 1
        if i % 10 == 0 or i == len(gaps):
            print(f"  {i}/{len(gaps)} (filled {filled})", flush=True)
        time.sleep(0.2)

    args.items.write_text(
        json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    remaining = sum(1 for it in items.values() if not it.get("descriptionZh"))
    print(f"\nFilled {filled} from 52poke. Remaining zh gaps: {remaining}/{len(items)}", flush=True)


if __name__ == "__main__":
    main()
