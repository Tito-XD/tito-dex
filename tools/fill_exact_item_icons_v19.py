#!/usr/bin/env python3
"""Fill the final exact v19 item icons whose page search names are ambiguous."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import requests

from enrich_items_v19 import USER_AGENT
from fill_shared_item_icons_v19 import WIKI_LICENSE, resolve_and_download


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SPRITES = ROOT / "data" / "assets" / "item-sprites"
DEFAULT_OUTPUT = (
    ROOT / "data" / "l10n" / "zh" / "item_media_exact_overrides_v19.json"
)

EXACT_FILES = {
    "tough-candy-l": "Bag 守护糖果L Sprite.png",
    "smart-candy-l": "Bag 知识糖果L Sprite.png",
    "courage-candy-l": "Bag 心灵糖果L Sprite.png",
    "tough-candy-xl": "Bag 守护糖果XL Sprite.png",
    "smart-candy-xl": "Bag 知识糖果XL Sprite.png",
    "courage-candy-xl": "Bag 心灵糖果XL Sprite.png",
    "legendary-clue-question": "Bag 传说笔记 Sprite.png",
    "meowsticite": "Bag 超能妙喵进化石 ZA Sprite.png",
    "leaf-letter--eevee": "Bag 树叶信 伊布 Sprite.png",
    "leaf-letter--pikachu": "Bag 树叶信 皮卡丘 Sprite.png",
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sprites-dir", type=Path, default=DEFAULT_SPRITES)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})
    args.sprites_dir.mkdir(parents=True, exist_ok=True)
    overrides = {}
    for slug, file_name in EXACT_FILES.items():
        content, info = resolve_and_download(session, file_name)
        (args.sprites_dir / f"{slug}.png").write_bytes(content)
        overrides[slug] = {
            "spriteMappingStatus": "exact",
            "spriteSource": "52poke",
            "spriteSourceFile": file_name,
            "spriteSourceUrl": info["url"],
            "spriteLicense": WIKI_LICENSE,
            "spriteWidth": info["width"],
            "spriteHeight": info["height"],
        }

    payload = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "summary": {"exactItems": len(overrides)},
        "itemsBySlug": overrides,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(payload["summary"], ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
