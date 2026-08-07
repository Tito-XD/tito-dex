#!/usr/bin/env python3
"""Fill verified shared-template item icons for the v19 bundle.

Sword/Shield's 300 Dynamax Crystal records use one upstream bag icon, while
the 100 TR records use one of 18 type-specific TR icons. The files are copied
per slug for the offline bundle, but the generated metadata keeps the shared
relationship explicit so file coverage is never reported as unique artwork.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

from enrich_items_v19 import USER_AGENT, WIKI_API, png_dimensions
from enrich_tm_icons_v19 import TYPE_ZH


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ITEMS = ROOT / "dist" / "dex-v18" / "staging" / "items.json"
DEFAULT_TM = ROOT / "data" / "l10n" / "zh" / "tm_v19_enrichment.json"
DEFAULT_SPRITES = ROOT / "data" / "assets" / "item-sprites"
DEFAULT_OUTPUT = (
    ROOT / "data" / "l10n" / "zh" / "item_media_overrides_v19.json"
)
WIKI_LICENSE = "CC BY-NC-SA 4.0"
SHARED_TM_MATERIAL_SLUGS = {
    "arrokuda-scales",
    "carbink-jewel",
    "cramorant-down",
    "feebas-scales",
    "fidough-fur",
    "gastly-gas",
    "gothita-eyelash",
    "grubbin-thread",
    "illumise-fluid",
    "kricketot-shell",
    "magikarp-scales",
    "morpeko-snack",
    "oricorio-feather",
    "sableye-gem",
    "seedot-stem",
    "shroodle-ink",
    "skwovet-fur",
    "slakoth-fur",
    "spoink-pearl",
    "sunkern-leaf",
    "tatsugiri-scales",
    "voltorb-sparks",
    "vullaby-feather",
    "wingull-feather",
    "yungoos-fur",
}
PICNIC_TEMPLATE_SLUGS = {
    "academy-cup",
    "academy-tablecloth",
    "bw-grass-tablecloth",
    "flower-pattern-cup",
    "monstrous-tablecloth",
    "peach-tablecloth",
    "spooky-tablecloth",
    "steel-bottle-y",
    "yellow-tablecloth",
}
SPECIES_CANDY_TEMPLATES = {
    "clefairy-candy": ("Bag 糖果_粉 Sprite.png", "pink"),
    "farfetchd-candy": ("Bag 糖果_褐 Sprite.png", "brown"),
    "jynx-candy": ("Bag 糖果_红 Sprite.png", "red"),
    "nidoran-f-candy": ("Bag 糖果_蓝 Sprite.png", "blue"),
    "porygon-candy": ("Bag 糖果_粉 Sprite.png", "pink"),
    "rattata-candy": ("Bag 糖果_紫 Sprite.png", "purple"),
}


def shared_targets(
    items: dict[str, dict[str, Any]], tm: dict[str, Any]
) -> dict[str, tuple[str, str, str]]:
    """Return slug -> (source file, shared key, mapping status)."""
    result: dict[str, tuple[str, str, str]] = {}
    tm_items = tm.get("itemsBySlug") or {}
    for item in items.values():
        slug = str(item.get("slug") or "")
        if item.get("categoryZh") == "极巨结晶":
            result[slug] = (
                "Bag 极巨结晶 Sprite.png",
                "52poke:dynamax-crystal",
                "shared-template",
            )
        elif slug.startswith("tr") and len(slug) == 4:
            move_type = str((tm_items.get(slug) or {}).get("moveType") or "")
            type_zh = TYPE_ZH.get(move_type)
            if type_zh:
                result[slug] = (
                    f"Bag TR {type_zh} Sprite.png",
                    f"52poke:tr:{move_type}",
                    "shared-template",
                )
        elif slug in SHARED_TM_MATERIAL_SLUGS:
            result[slug] = (
                "Bag 掉落物 SV Sprite.png",
                "52poke:sv-tm-material",
                "shared-template",
            )
        elif slug in PICNIC_TEMPLATE_SLUGS:
            result[slug] = (
                "Bag 野餐组合 SV Sprite.png",
                "52poke:sv-picnic-set",
                "fallback-template"
                if slug == "bw-grass-tablecloth"
                else "shared-template",
            )
        elif slug in SPECIES_CANDY_TEMPLATES:
            file_name, color = SPECIES_CANDY_TEMPLATES[slug]
            result[slug] = (
                file_name,
                f"52poke:lets-go-species-candy:{color}",
                "shared-template",
            )
    return result


def resolve_and_download(
    session: requests.Session, file_name: str
) -> tuple[bytes, dict[str, Any]]:
    response = session.get(
        WIKI_API,
        params={
            "action": "query",
            "titles": f"File:{file_name}",
            "prop": "imageinfo",
            "iiprop": "url|size|mime|sha1|timestamp",
            "format": "json",
            "formatversion": 2,
        },
        timeout=(20, 90),
    )
    response.raise_for_status()
    pages = response.json().get("query", {}).get("pages", [])
    info = (pages[0].get("imageinfo") or [None])[0] if pages else None
    if not info or info.get("mime") != "image/png" or not info.get("url"):
        raise RuntimeError(f"No PNG imageinfo for {file_name}")
    image = session.get(
        str(info["url"]),
        headers={"Referer": "https://wiki.52poke.com/"},
        timeout=(20, 90),
    )
    image.raise_for_status()
    dimensions = png_dimensions(image.content)
    expected = (int(info.get("width") or 0), int(info.get("height") or 0))
    if dimensions != expected or min(expected) <= 0:
        raise RuntimeError(f"PNG verification failed for {file_name}")
    return image.content, {
        "url": info["url"],
        "width": expected[0],
        "height": expected[1],
        "sha1": info.get("sha1"),
        "timestamp": info.get("timestamp"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--items", type=Path, default=DEFAULT_ITEMS)
    parser.add_argument("--tm", type=Path, default=DEFAULT_TM)
    parser.add_argument("--sprites-dir", type=Path, default=DEFAULT_SPRITES)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    items = json.loads(args.items.read_text(encoding="utf-8"))
    tm = json.loads(args.tm.read_text(encoding="utf-8"))
    targets = shared_targets(items, tm)
    if len(targets) != 440:
        raise RuntimeError(f"Expected 440 shared targets, got {len(targets)}")

    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})
    source_files = sorted({source for source, _, _ in targets.values()})
    downloaded = {
        file_name: resolve_and_download(session, file_name)
        for file_name in source_files
    }

    args.sprites_dir.mkdir(parents=True, exist_ok=True)
    overrides: dict[str, dict[str, Any]] = {}
    for slug, (file_name, shared_key, mapping_status) in sorted(targets.items()):
        content, info = downloaded[file_name]
        (args.sprites_dir / f"{slug}.png").write_bytes(content)
        overrides[slug] = {
            "spriteMappingStatus": mapping_status,
            "spriteSharedWith": shared_key,
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
        "summary": {
            "items": len(targets),
            "sharedTemplates": len(source_files),
            "dynamaxCrystalItems": sum(
                key == "52poke:dynamax-crystal"
                for _, key, _ in targets.values()
            ),
            "technicalRecordItems": sum(
                key.startswith("52poke:tr:") for _, key, _ in targets.values()
            ),
            "tmMaterialItems": sum(
                key == "52poke:sv-tm-material"
                for _, key, _ in targets.values()
            ),
            "picnicTemplateItems": sum(
                key == "52poke:sv-picnic-set"
                for _, key, _ in targets.values()
            ),
            "speciesCandyItems": sum(
                key.startswith("52poke:lets-go-species-candy:")
                for _, key, _ in targets.values()
            ),
        },
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
