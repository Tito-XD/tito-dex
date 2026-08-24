from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("patch_dex_bundle_v20_reference.py")
SPEC = importlib.util.spec_from_file_location("patch_v20_reference", MODULE_PATH)
assert SPEC and SPEC.loader
patcher = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(patcher)


class ReferenceV20Test(unittest.TestCase):
    def test_flavor_prefers_simplified_chinese(self) -> None:
        entries = [
            {
                "flavor_text": "简体说明",
                "language": {"name": "zh-Hans"},
                "version_group": {"name": "scarlet-violet"},
            },
            {
                "flavor_text": "繁體說明",
                "language": {"name": "zh-Hant"},
                "version_group": {"name": "scarlet-violet"},
            },
        ]
        self.assertEqual(
            patcher.flavor_by_version(entries), {"scarlet-violet": "简体说明"}
        )

    def test_move_record_preserves_version_history_and_machine(self) -> None:
        detail = {
            "id": 14,
            "name": "swords-dance",
            "names": [{"name": "剑舞", "language": {"name": "zh-Hans"}}],
            "type": {"name": "normal"},
            "damage_class": {"name": "status"},
            "power": None,
            "accuracy": None,
            "pp": 20,
            "priority": 0,
            "target": {"name": "user"},
            "generation": {"name": "generation-i"},
            "effect_chance": None,
            "effect_entries": [
                {
                    "effect": "Raises Attack.",
                    "short_effect": "Raises Attack.",
                    "language": {"name": "en"},
                }
            ],
            "flavor_text_entries": [
                {
                    "flavor_text": "大幅提高自己的攻击。",
                    "language": {"name": "zh-Hans"},
                    "version_group": {"name": "scarlet-violet"},
                }
            ],
            "meta": {
                "ailment": {"name": "none"},
                "category": {"name": "net-good-stats"},
                "ailment_chance": 0,
                "stat_chance": 0,
                "flinch_chance": 0,
                "drain": 0,
                "healing": 0,
                "crit_rate": 0,
                "min_hits": None,
                "max_hits": None,
                "min_turns": None,
                "max_turns": None,
            },
            "stat_changes": [{"change": 2, "stat": {"name": "attack"}}],
            "past_values": [
                {"pp": 30, "version_group": {"name": "x-y"}, "effect_entries": []}
            ],
            "machines": [{"machine": {"url": "/api/v2/machine/1/"}}],
        }
        machine = {
            "machineId": 1,
            "itemId": 392,
            "itemSlug": "tm88",
            "itemNameZh": "招式学习器８８",
            "moveId": 14,
            "moveSlug": "swords-dance",
            "versionGroup": "scarlet-violet",
            "kind": "TM",
            "number": 88,
        }
        record = patcher.build_move_record(
            detail,
            existing=None,
            label={"nameZh": "剑舞", "categoryZh": "变化", "typeZh": "一般"},
            machines={1: machine},
            commit="abc",
        )
        self.assertEqual(record["stableId"], "move:14")
        self.assertEqual(record["descriptionZh"], "大幅提高自己的攻击。")
        self.assertEqual(record["history"][0]["previousValues"]["pp"], 30)
        self.assertEqual(record["machines"], [machine])
        self.assertEqual(record["statChanges"], [{"stat": "attack", "stages": 2}])

    def test_effect_chance_is_substituted(self) -> None:
        result = patcher.replace_effect_chance("Has a $effect_chance% chance.", 30)
        self.assertEqual(result, "Has a 30% chance.")

    def test_candidate_archive_url_only_replaces_leaf(self) -> None:
        result = patcher.candidate_archive_url(
            "https://example.invalid/private-prefix/old.tar.zst",
            "bundle-v20.tar.zst",
        )
        self.assertEqual(
            result, "https://example.invalid/private-prefix/bundle-v20.tar.zst"
        )

    def test_item_matrix_uses_canonical_v20_version_groups(self) -> None:
        result = patcher.normalize_item_version_matrix(
            {
                "schemaVersion": 1,
                "items": {
                    "1": {
                        "slug": "fixture",
                        "versionGroups": [
                            "blue-japan",
                            "red-green-japan",
                            "legends-z-a",
                        ],
                        "generations": [1, 9],
                        "prices": {
                            "legends-z-a": {"buy": 50000, "sell": 25000},
                            "legends-za": {"buy": 50000, "sell": 12500},
                        },
                    }
                },
            }
        )
        self.assertEqual(
            result["items"]["1"]["versionGroups"],
            ["legends-za", "red-blue"],
        )
        self.assertEqual(
            result["items"]["1"]["prices"],
            {"legends-za": {"buy": 50000, "sell": 12500}},
        )


if __name__ == "__main__":
    unittest.main()
