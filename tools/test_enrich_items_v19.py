from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from enrich_items_v19 import (
    latest_zh,
    png_dimensions,
    wiki_description,
    wiki_sprite_candidates,
)


def test_prefers_latest_core_game_description_and_sprite() -> None:
    text = """
|sprite=Bag 测试 LA Sprite.png{{!}}30px
{{包包信息框|8|LA|测试 LA|道具|-{zh-hans:阿尔宙斯说明。;zh-hant:阿爾宙斯說明。}-||10}}
{{包包信息框|9|SV|测试 SV|道具|-{zh-hans:朱紫说明。;zh-hant:朱紫說明。}-||10}}
{{包包信息框|9|ZA|测试 ZA|道具|-{zh-hans:ZA说明。;zh-hant:ZA說明。}-||10}}
"""
    assert wiki_description(text) == "ZA说明。"
    assert wiki_sprite_candidates(text)[:3] == [
        "Bag 测试 ZA Sprite.png",
        "Bag 测试 SV Sprite.png",
        "Bag 测试 LA Sprite.png",
    ]


def test_png_dimensions_reads_ihdr() -> None:
    data = b"\x89PNG\r\n\x1a\n" + b"\x00" * 8 + (160).to_bytes(4, "big") + (
        100
    ).to_bytes(4, "big")
    assert png_dimensions(data) == (160, 100)
    assert png_dimensions(b"not png") is None


def test_pokeapi_lowercase_zh_hans_is_accepted() -> None:
    entries = [
        {
            "language": {"name": "zh-hans"},
            "text": "中文说明",
        }
    ]
    assert latest_zh(entries, "text") == "中文说明"
