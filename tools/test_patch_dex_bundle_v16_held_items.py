#!/usr/bin/env python3
"""Offline tests for the v16 52poke held-item patch logic."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from fetch_52poke_held_items import parse_held_items
from patch_dex_bundle_v16_held_items import (
    load_item_slugs,
    merge_extra_items,
    patch_details,
)


SAMPLE_WIKITEXT = """\
{{携带物品/header|电}}
{{携带物品/main|8|LA|文柚果|rate1=25|蛀球果|rate2=15|row=2}}
{{携带物品/main|9|SV|电气球|rate1=5|row=1}}
{{携带物品/end|电}}
"""


class HeldItemParsingTests(unittest.TestCase):
    def test_parse_held_items(self) -> None:
        versions = parse_held_items(SAMPLE_WIKITEXT)
        self.assertIn("legends-arceus", versions)
        self.assertIn("scarlet", versions)
        self.assertEqual(
            versions["legends-arceus"],
            [{"itemZh": "文柚果", "rate": 25.0}, {"itemZh": "蛀球果", "rate": 15.0}],
        )
        self.assertEqual(versions["violet"], [{"itemZh": "电气球", "rate": 5.0}])


class HeldItemPatchTests(unittest.TestCase):
    def _make_bundle(self, root: Path) -> None:
        (root / "details").mkdir(parents=True)
        (root / "items.json").write_text(
            json.dumps(
                {
                    "1": {"slug": "oran-berry", "nameZh": "橙橙果"},
                    "2": {"slug": "light-ball", "nameZh": "电气球"},
                    "3": {"slug": "lum-berry", "nameZh": "文柚果"},
                }
            ),
            encoding="utf-8",
        )
        detail = {
            "summary": {"id": 25},
            "heldItems": [
                {
                    "slug": "oran-berry",
                    "rarityByVersion": {"black": 50},
                    "maxRarity": 50,
                }
            ],
        }
        (root / "details" / "25.json").write_text(
            json.dumps(detail, ensure_ascii=False), encoding="utf-8"
        )

    def test_patch_details_merges_and_overrides(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "staging"
            self._make_bundle(root)
            held_data = {
                "entries": [
                    {
                        "id": 25,
                        "versions": {
                            "scarlet": [{"itemZh": "电气球", "rate": 5.0}],
                            "black": [{"itemZh": "橙橙果", "rate": 100.0}],
                            "sword": [{"itemZh": "橙橙果"}],
                        },
                    }
                ]
            }
            by_zh = load_item_slugs(root)
            patched, unresolved = patch_details(root, held_data, by_zh)
            self.assertEqual(patched, 1)
            self.assertEqual(unresolved, set())
            detail = json.loads(
                (root / "details" / "25.json").read_text(encoding="utf-8")
            )
            items = {item["slug"]: item for item in detail["heldItems"]}
            self.assertEqual(items["oran-berry"]["rarityByVersion"]["black"], 100.0)
            self.assertEqual(
                items["oran-berry"]["rarityByVersion"]["sword"], 100.0
            )
            self.assertEqual(items["oran-berry"]["maxRarity"], 100.0)
            self.assertEqual(
                items["light-ball"]["rarityByVersion"], {"scarlet": 5.0}
            )
            self.assertEqual(items["light-ball"]["maxRarity"], 5.0)

    def test_merge_extra_items(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "staging"
            self._make_bundle(root)
            extra = {
                "itemsByZhName": {
                    "不变之石": {
                        "slug": "everstone",
                        "nameZh": "不变之石",
                        "nameEn": "everstone",
                        "spriteUrl": "https://example.com/everstone.png",
                    }
                },
                "unresolvedWithEnname": {"泥丸": "Ball of Mud"},
            }
            added, unresolved = merge_extra_items(root, extra)
            self.assertEqual(added, 2)
            self.assertEqual(unresolved, [])
            items = json.loads(
                (root / "items.json").read_text(encoding="utf-8")
            )
            slugs = {item["slug"]: item for item in items.values()}
            self.assertEqual(slugs["everstone"]["nameZh"], "不变之石")
            self.assertEqual(slugs["ball-of-mud"]["nameZh"], "泥丸")
            self.assertEqual(slugs["ball-of-mud"]["categoryZh"], "携带道具")


if __name__ == "__main__":
    unittest.main()
