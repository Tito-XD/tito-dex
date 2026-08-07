#!/usr/bin/env python3
"""Regression checks for the local v19 item/media candidate."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

PACHIRISU_ITEMS = {
    "exp-candy-s",
    "oran-berry",
    "seed-of-mastery",
    "spoiled-apricorn",
}
NAME_TAILS = {
    "bw-grass-tablecloth": "青草桌布（ＢＷ）",
    "fame-checker": "声音记录器",
    "kofus-wallet": "海岱的钱包",
    "koraidons-poke-ball": "故勒顿的球",
    "miraidons-poke-ball": "密勒顿的球",
    "oaks-parcel": "包裹",
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("staging", type=Path)
    args = parser.parse_args()
    root = args.staging
    items = json.loads((root / "items.json").read_text(encoding="utf-8"))
    by_slug = {item["slug"]: item for item in items.values()}
    descriptions = sum(
        bool(item.get("descriptionZh") or item.get("effectZh"))
        for item in items.values()
    )
    icons = sum(
        (root / "item-sprites" / f"{item['slug']}.png").is_file()
        for item in items.values()
    )
    assert len(items) == 2130
    assert descriptions == 2090
    assert icons == 1645

    held = json.loads(
        (root / "details" / "417.json").read_text(encoding="utf-8")
    )["heldItems"]
    assert {item["slug"] for item in held} == PACHIRISU_ITEMS
    for slug in PACHIRISU_ITEMS:
        item = by_slug[slug]
        assert item.get("descriptionZh") or item.get("effectZh")
        assert (root / "item-sprites" / f"{slug}.png").is_file()

    machine_hashes = {
        hashlib.sha256(
            (root / "item-sprites" / f"{item['slug']}.png").read_bytes()
        ).hexdigest()
        for item in items.values()
        if item.get("categoryZh") == "招式学习器"
        and (root / "item-sprites" / f"{item['slug']}.png").is_file()
    }
    assert len(machine_hashes) == 19
    assert by_slug["tm03"]["nameZh"] == "招式学习器０３"
    for slug, expected in NAME_TAILS.items():
        assert by_slug[slug]["nameZh"] == expected

    media = json.loads(
        (root / "media_catalog_52poke.json").read_text(encoding="utf-8")
    )
    assert len(media) == 1025
    for species_id in (312, 973, 990, 1022, 1023):
        assert media[str(species_id)]["source"] == "PokeAPI fallback"

    forms = []
    alternate_form_visuals = 0
    for detail_path in (root / "details").glob("*.json"):
        detail = json.loads(detail_path.read_text(encoding="utf-8"))
        detail_forms = detail.get("forms") or []
        forms.extend(detail_forms)
        species = detail.get("summary") or {}
        species_visuals = {
            species.get("artworkUrl"),
            species.get("spriteUrl"),
        } - {None, ""}
        for form in detail_forms:
            if form.get("isDefault"):
                continue
            form_visuals = {
                form.get("artworkUrl"),
                form.get("spriteUrl"),
                form.get("localSpritePath"),
            } - {None, ""}
            alternate_form_visuals += bool(form_visuals - species_visuals)
    alternate_forms = [form for form in forms if not form.get("isDefault")]
    assert len(forms) == 803
    assert len(alternate_forms) == 554
    assert alternate_form_visuals == 546

    print(
        json.dumps(
            {
                "items": len(items),
                "descriptionCoverage": descriptions,
                "spriteCoverage": icons,
                "machineIconHashes": len(machine_hashes),
                "mediaCatalogEntries": len(media),
                "formRecords": len(forms),
                "alternateForms": len(alternate_forms),
                "alternateFormsWithExactVisual": alternate_form_visuals,
                "pachirisuHeldItems": sorted(PACHIRISU_ITEMS),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
