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
    assert descriptions == 2130
    assert icons == 2130

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
    assert len(machine_hashes) == 37
    assert by_slug["tm03"]["nameZh"] == "招式学习器０３"
    for slug, expected in NAME_TAILS.items():
        assert by_slug[slug]["nameZh"] == expected

    media = json.loads(
        (root / "media_catalog_52poke.json").read_text(encoding="utf-8")
    )
    assert len(media) == 1025
    for species_id in (312, 973, 990, 1022, 1023):
        entry = media[str(species_id)]
        assert entry["cries"][0]["source"] == "PokeAPI"
        assert any(art.get("urlVerified") for art in entry["forms"])

    forms = []
    for detail_path in (root / "details").glob("*.json"):
        detail = json.loads(detail_path.read_text(encoding="utf-8"))
        detail_forms = detail.get("forms") or []
        forms.extend(detail_forms)
    alternate_forms = [form for form in forms if not form.get("isDefault")]
    assert len(forms) == 803
    assert len(alternate_forms) == 554
    audit = json.loads(
        (root / "form_media_audit.json").read_text(encoding="utf-8")
    )
    audit_summary = audit["summary"]
    assert audit_summary["formRecords"] == len(forms)
    assert audit_summary["alternateForms"] == len(alternate_forms)
    assert audit_summary["alternateCoverage"]["static"] == 548
    assert audit_summary["alternateCoverage"]["shinyStatic"] == 497
    assert audit_summary["alternateCoverage"]["animated"] == 386
    assert audit_summary["alternateCoverage"]["shinyAnimated"] == 386
    assert audit_summary["alternateCoverage"]["cry"] == 554
    assert audit_summary["unresolved52pokeArt"] == 0
    assert audit_summary["failed52pokeFiles"] == 0
    assert audit["gaps"]["static"] == [
        "koraidon-sprinting-build",
        "koraidon-swimming-build",
        "koraidon-gliding-build",
        "miraidon-drive-mode",
        "miraidon-aquatic-mode",
        "miraidon-glide-mode",
    ]

    item_audit = json.loads(
        (root / "item_media_audit_v19.json").read_text(encoding="utf-8")
    )
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["formMediaAudit"] == "form_media_audit.json"
    assert manifest["itemMediaAudit"] == "item_media_audit_v19.json"
    item_summary = item_audit["summary"]
    assert item_summary["items"] == len(items)
    assert item_summary["descriptions"] == descriptions
    assert item_summary["icons"] == icons
    assert item_summary["mappingStatus"]["shared-template"] == 669
    assert item_summary["mappingStatus"]["fallback-template"] == 1
    assert item_summary["mappingStatus"]["exact"] == 10
    assert item_audit["gaps"] == {"descriptions": [], "icons": []}

    print(
        json.dumps(
            {
                "items": len(items),
                "descriptionCoverage": descriptions,
                "spriteCoverage": icons,
                "machineIconHashes": len(machine_hashes),
                "itemIconMappingStatus": item_summary["mappingStatus"],
                "mediaCatalogEntries": len(media),
                "formRecords": len(forms),
                "alternateForms": len(alternate_forms),
                "alternateFormMediaCoverage": audit_summary[
                    "alternateCoverage"
                ],
                "staticFormGaps": audit["gaps"]["static"],
                "pachirisuHeldItems": sorted(PACHIRISU_ITEMS),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
