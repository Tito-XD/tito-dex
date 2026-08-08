#!/usr/bin/env python3

from __future__ import annotations

import unittest
from collections import Counter

from audit_item_media_v19 import inferred_mapping


class ItemMediaAuditTests(unittest.TestCase):
    def test_explicit_mapping_wins(self) -> None:
        item = {
            "slug": "example",
            "spriteMappingStatus": "fallback-template",
            "spriteSharedWith": "example:template",
        }
        self.assertEqual(
            inferred_mapping(item, "abc", Counter({"abc": 2})),
            ("fallback-template", "example:template"),
        )

    def test_tm_mapping_is_explicitly_shared_by_type(self) -> None:
        item = {
            "slug": "tm03",
            "categoryZh": "招式学习器",
            "moveType": "psychic",
        }
        self.assertEqual(
            inferred_mapping(item, "abc", Counter({"abc": 1})),
            ("shared-template", "52poke:tm:psychic"),
        )

    def test_legacy_pipeline_sprite_has_derived_source(self) -> None:
        item = {"slug": "legacy-item"}
        self.assertEqual(
            inferred_mapping(item, "abc", Counter({"abc": 2})),
            ("source-documented", None),
        )


if __name__ == "__main__":
    unittest.main()
