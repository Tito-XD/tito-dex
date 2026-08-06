#!/usr/bin/env python3
"""Offline tests for the v17 full-item-catalog patch logic."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from patch_dex_bundle_v17_items import copy_sprites, merge_items


class ItemMergeTests(unittest.TestCase):
    def _make_bundle(self, root: Path) -> None:
        (root / "item-sprites").mkdir(parents=True)
        (root / "items.json").write_text(
            json.dumps({"1": {"id": 1, "slug": "master-ball", "nameZh": "大师球"}}),
            encoding="utf-8",
        )

    def test_merge_items(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "staging"
            self._make_bundle(root)
            extra = {
                "itemsBySlug": {
                    "tm01": {
                        "nameZh": "招式学习器０１",
                        "category": "all-machines",
                        "categoryZh": "招式学习器",
                        "spriteUrl": None,
                    },
                    "master-ball": {"nameZh": "重复"},
                }
            }
            added, total = merge_items(root, extra)
            self.assertEqual(added, 1)
            self.assertEqual(total, 2)
            items = json.loads(
                (root / "items.json").read_text(encoding="utf-8")
            )
            tm = [item for item in items.values() if item["slug"] == "tm01"][0]
            self.assertEqual(tm["categoryZh"], "招式学习器")

    def test_copy_sprites(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "sprites").mkdir()
            (root / "sprites" / "tm01.png").write_bytes(b"png")
            staging = root / "staging"
            (staging / "item-sprites").mkdir(parents=True)
            copied = copy_sprites(staging, root / "sprites")
            self.assertEqual(copied, 1)
            self.assertTrue((staging / "item-sprites" / "tm01.png").exists())


if __name__ == "__main__":
    unittest.main()
