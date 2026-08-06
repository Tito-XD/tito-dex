#!/usr/bin/env python3
"""Offline tests for the v15 52poke flavor-text patch logic."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from fetch_52poke_flavor_text import (
    CJK_RE,
    extract_zh_hans,
    flavors_from_wikitext,
)
from patch_dex_bundle_v15_flavor_text import (
    merge_flavor_entries,
    patch_details,
    write_attribution,
)


SAMPLE_WIKITEXT = """\
{{图鉴
|type=草
|gen=2
|golddex=-{zh-hans:从头上的叶子那里会飘散出淡淡的甜香。性情温和，非常喜欢沐浴阳光。;zh-hant:從頭上的葉子飄散出淡淡的清甜香氣。性情溫和，最愛沐浴在陽光下。}-
|silverdex=-{zh-hans:带有香味的叶子拥有能感知周围的湿度和温度的能力。;zh-hant:帶有香氣的葉子具有能夠感知周圍濕度與溫度的能力。}-
|dpptdex=-{zh-hans:会用头上的叶子来感知周围的温度和湿度。非常喜欢沐浴阳光。;zh-hant:會用頭上的葉子來感知周圍的溫度和濕度。最喜歡沐浴在陽光下。}-
|scdex=-{zh-hans:非常喜欢沐浴阳光。会用头上的叶子来寻找温暖的地方。;zh-hant:最喜歡沐浴在陽光下。會用頭上的葉子尋找溫暖的地方。}-
|zadex=-{zh-hans:从头上的叶子那里会飘散出淡淡的甜香。性情温和，非常喜欢沐浴阳光。;zh-hant:從頭上的葉子飄散出淡淡的清甜香氣。性情溫和，最愛沐浴在陽光下。}-
}}
"""


class FlavorParsingTests(unittest.TestCase):
    def test_extract_zh_hans_block(self) -> None:
        value = (
            "-{zh-hans:中文介绍。;zh-hant:繁體介紹。}-"
        )
        self.assertEqual(extract_zh_hans(value), "中文介绍。")

    def test_extract_plain_value(self) -> None:
        self.assertEqual(extract_zh_hans("直接中文"), "直接中文")

    def test_extract_rejects_template_reference(self) -> None:
        self.assertIsNone(extract_zh_hans("{{Dex1000|Sc}}"))

    def test_flavors_from_wikitext(self) -> None:
        versions = flavors_from_wikitext(SAMPLE_WIKITEXT)
        self.assertEqual(versions["gold"], "从头上的叶子那里会飘散出淡淡的甜香。性情温和，非常喜欢沐浴阳光。")
        self.assertEqual(versions["silver"], "带有香味的叶子拥有能感知周围的湿度和温度的能力。")
        self.assertEqual(versions["diamond"], "会用头上的叶子来感知周围的温度和湿度。非常喜欢沐浴阳光。")
        self.assertEqual(versions["platinum"], versions["diamond"])
        self.assertEqual(versions["scarlet"], "非常喜欢沐浴阳光。会用头上的叶子来寻找温暖的地方。")
        self.assertEqual(versions["legends-za"], versions["gold"])
        self.assertEqual(versions["mega-dimension"], versions["gold"])


class PatchDetailsTests(unittest.TestCase):
    def test_merge_flavor_entries_manual_wins(self) -> None:
        fetched = {
            "1000": {
                "id": 1000,
                "versions": {"scarlet": "fetch-text", "violet": "fetch-text"},
            }
        }
        manual = {
            "entries": [
                {
                    "id": 1000,
                    "versions": {
                        "scarlet": "人工中文",
                        "legends-za": "人工Z-A",
                    },
                },
                {"id": 999, "versions": {"scarlet": "新增物种"}},
            ]
        }
        merged = merge_flavor_entries(fetched, manual)
        self.assertEqual(merged["1000"]["versions"]["scarlet"], "人工中文")
        self.assertEqual(merged["1000"]["versions"]["violet"], "fetch-text")
        self.assertEqual(merged["1000"]["versions"]["legends-za"], "人工Z-A")
        self.assertEqual(merged["999"]["versions"]["scarlet"], "新增物种")

    def _make_bundle(self, root: Path) -> None:
        (root / "details").mkdir(parents=True)
        (root / "games.json").write_text(
            json.dumps(
                [
                    {
                        "slug": "gs",
                        "labelZh": "金/银",
                        "versionGroup": "gold-silver",
                        "flavorVersions": ["gold", "silver"],
                        "iconUrl": "https://dex.tito.cafe/v5/game_icons/gold-silver.png",
                    },
                    {
                        "slug": "sv",
                        "labelZh": "朱/紫",
                        "versionGroup": "scarlet-violet",
                        "flavorVersions": ["scarlet", "violet"],
                        "iconUrl": "https://dex.tito.cafe/v5/game_icons/scarlet-violet.png",
                    },
                ]
            ),
            encoding="utf-8",
        )
        detail = {
            "summary": {"id": 152},
            "flavorEntries": [
                {
                    "gameEdition": "rgb",
                    "versionGroup": "red-blue",
                    "version": "gold",
                    "labelZh": "金/银",
                    "text": "A strange seed was planted on its back at birth.",
                },
                {
                    "gameEdition": "sv",
                    "versionGroup": "scarlet-violet",
                    "version": "scarlet",
                    "labelZh": "朱/紫",
                    "text": "已有的中文文本",
                },
            ],
        }
        (root / "details" / "152.json").write_text(
            json.dumps(detail, ensure_ascii=False), encoding="utf-8"
        )

    def test_patch_details_only_fills_non_cjk(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "staging"
            self._make_bundle(root)
            flavor = {
                "entries": [
                    {
                        "id": 152,
                        "versions": {
                            "gold": "中文金版介绍",
                            "scarlet": "中文朱版介绍",
                            "violet": "中文紫版介绍",
                        },
                    }
                ]
            }
            patched = patch_details(root, flavor)
            self.assertEqual(patched, 1)
            detail = json.loads(
                (root / "details" / "152.json").read_text(encoding="utf-8")
            )
            entries = detail["flavorEntries"]
            self.assertEqual(entries[0]["text"], "中文金版介绍")
            self.assertEqual(entries[0]["source"], "52poke")
            self.assertEqual(entries[1]["text"], "已有的中文文本")
            self.assertNotIn("source", entries[1])
            appended = {entry["version"]: entry for entry in entries}[
                "violet"
            ]
            self.assertEqual(appended["text"], "中文紫版介绍")
            self.assertEqual(appended["gameEdition"], "sv")
            self.assertEqual(appended["versionGroup"], "scarlet-violet")

    def test_write_attribution(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_attribution(
                root,
                {
                    "source": {"url": "https://wiki.52poke.com", "license": "CC BY-NC-SA 4.0"},
                    "fetchedAt": "2026-08-05T00:00:00+00:00",
                    "entries": [{"id": 152}],
                },
            )
            text = (root / "FLAVOR_ATTRIBUTION.txt").read_text(encoding="utf-8")
            self.assertIn("CC BY-NC-SA 4.0", text)
            self.assertIn("wiki.52poke.com", text)


if __name__ == "__main__":
    unittest.main()
