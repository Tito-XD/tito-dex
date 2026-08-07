from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from enrich_items_v19 import (
    latest_zh,
    png_dimensions,
    wiki_description,
    wiki_sprite_candidates,
)


class EnrichItemsV19Tests(unittest.TestCase):
    def test_prefers_latest_core_game_description_and_sprite(self) -> None:
        text = """
|sprite=Bag 测试 LA Sprite.png{{!}}30px
{{包包信息框|8|LA|测试 LA|道具|-{zh-hans:阿尔宙斯说明。;zh-hant:阿爾宙斯說明。}-||10}}
{{包包信息框|9|SV|测试 SV|道具|-{zh-hans:朱紫说明。;zh-hant:朱紫說明。}-||10}}
{{包包信息框|9|ZA|测试 ZA|道具|-{zh-hans:ZA说明。;zh-hant:ZA說明。}-||10}}
"""
        self.assertEqual(wiki_description(text), "ZA说明。")
        self.assertEqual(
            wiki_sprite_candidates(text)[:3],
            [
                "Bag 测试 ZA Sprite.png",
                "Bag 测试 SV Sprite.png",
                "Bag 测试 LA Sprite.png",
            ],
        )

    def test_plain_chinese_bag_description_is_parsed(self) -> None:
        text = """
{{包包信息框|2|GSC|冰冻的果实|道具|携带后，可以治愈自己的灼伤状态。}}
{{包包信息框|3|FRLG|极光船票|重要物品|前往[[诞生之岛]]时必要的船票。}}
"""
        self.assertEqual(wiki_description(text), "前往诞生之岛时必要的船票。")

    def test_unknown_word_inside_real_sentence_is_not_placeholder(self) -> None:
        text = "{{包包信息框|9|SV|面条|野餐|作为馅料的潜力还是未知数。|280|70}}"
        self.assertEqual(wiki_description(text), "作为馅料的潜力还是未知数。")

    def test_png_dimensions_reads_ihdr(self) -> None:
        data = (
            b"\x89PNG\r\n\x1a\n"
            + b"\x00" * 8
            + (160).to_bytes(4, "big")
            + (100).to_bytes(4, "big")
        )
        self.assertEqual(png_dimensions(data), (160, 100))
        self.assertIsNone(png_dimensions(b"not png"))

    def test_pokeapi_lowercase_zh_hans_is_accepted(self) -> None:
        entries = [
            {
                "language": {"name": "zh-hans"},
                "text": "中文说明",
            }
        ]
        self.assertEqual(latest_zh(entries, "text"), "中文说明")


if __name__ == "__main__":
    unittest.main()
