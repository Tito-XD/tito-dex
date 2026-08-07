#!/usr/bin/env python3

from __future__ import annotations

import unittest

from fill_shared_item_icons_v19 import shared_targets


class SharedItemIconTests(unittest.TestCase):
    def test_targets_use_one_crystal_and_type_specific_tr_templates(self) -> None:
        items = {
            "1": {"slug": "dynamax-crystal-and15", "categoryZh": "极巨结晶"},
            "2": {"slug": "tr00", "categoryZh": "招式学习器"},
            "3": {"slug": "potion", "categoryZh": "药品"},
        }
        tm = {"itemsBySlug": {"tr00": {"moveType": "normal"}}}
        self.assertEqual(
            shared_targets(items, tm),
            {
                "dynamax-crystal-and15": (
                    "Bag 极巨结晶 Sprite.png",
                    "52poke:dynamax-crystal",
                    "shared-template",
                ),
                "tr00": (
                    "Bag TR 一般 Sprite.png",
                    "52poke:tr:normal",
                    "shared-template",
                ),
            },
        )


if __name__ == "__main__":
    unittest.main()
