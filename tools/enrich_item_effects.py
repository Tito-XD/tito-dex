"""Fetch PokeAPI item effect descriptions (zh) and enrich items.json.

Usage: python3 tools/enrich_item_effects.py
"""

from __future__ import annotations

import json
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ITEMS_JSON = ROOT / "dist" / "dex-v10" / "staging" / "items.json"
POKEAPI_ITEM = "https://pokeapi.co/api/v2/item"

def main() -> None:
    with open(ITEMS_JSON, encoding="utf-8") as fh:
        items: dict[str, dict] = json.load(fh)

    updated = 0
    for item_id, item in sorted(items.items(), key=lambda x: int(x[0])):
        if item.get("effectZh") or item.get("descriptionZh"):
            continue  # Already has effect data.

        slug = item["slug"]
        url = f"{POKEAPI_ITEM}/{slug}"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "TitoDex/1.0"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode())
        except Exception as exc:
            print(f"  warn: {slug} ({item_id}): {exc}", file=sys.stderr)
            time.sleep(0.5)
            continue

        effect_entries = data.get("effect_entries") or []
        zh_effect = None
        en_effect = None
        for entry in effect_entries:
            lang = entry.get("language", {}).get("name", "")
            txt = (entry.get("short_effect") or entry.get("effect") or "").strip()
            if lang == "zh-Hans" and txt:
                zh_effect = txt
                break
            elif lang == "en" and txt and not en_effect:
                en_effect = txt

        flavor_entries = data.get("flavor_text_entries") or []
        zh_flavor = None
        for entry in flavor_entries:
            if (entry.get("language", {}).get("name") == "zh-Hans"
                    and entry.get("version_group", {}).get("name") in ("scarlet-violet",)):
                txt = (entry.get("text") or "").replace("\n", " ").replace("\f", " ").strip()
                if txt:
                    zh_flavor = txt
                    break
        if not zh_flavor:
            for entry in flavor_entries:
                if entry.get("language", {}).get("name") == "zh-Hans":
                    txt = (entry.get("text") or "").replace("\n", " ").replace("\f", " ").strip()
                    if txt:
                        zh_flavor = txt
                        break

        if zh_effect:
            item["effectZh"] = zh_effect
        elif en_effect:
            item["effectZh"] = en_effect
        if zh_flavor:
            item["descriptionZh"] = zh_flavor
        if zh_effect or en_effect or zh_flavor:
            updated += 1
            if updated % 30 == 0:
                print(f"  ... {updated} items enriched")

        time.sleep(0.5)  # Rate limit

    with open(ITEMS_JSON, "w", encoding="utf-8") as fh:
        json.dump(items, fh, ensure_ascii=False, indent=2)
    print(f"Enriched {updated} items with effectZh / descriptionZh")

if __name__ == "__main__":
    main()
