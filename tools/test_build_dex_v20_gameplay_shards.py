from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from build_dex_v20_gameplay_shards import (
    MAX_SHARD_BYTES,
    validate_shard,
    verify_shard_tree,
    write_species_shards,
)


POKEAPI = "a" * 40
PKHEX = "b" * 40


class GameplayShardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.obtain = {
            "1": {
                "stableId": "pokemon:1",
                "byExactVersion": {"violet": {"encounterCount": 1}},
                "verifiedRouteByVersionGroup": {"scarlet-violet": "direct"},
                "derivedFamilyRouteByVersionGroup": {"scarlet-violet": "direct"},
            }
        }
        self.encounters = {
            "1": {
                "violet": [{
                    "method": "wild",
                    "exactVersion": "violet",
                    "versionGroup": "scarlet-violet",
                    "areaSlug": "south-province-area-two",
                    "areaLabelZh": "南第2区",
                    "minLevel": 16,
                    "maxLevel": 20,
                    "rateKind": "percent",
                    "rateValue": 10,
                    "encounterMethods": ["walk"],
                    "conditions": [],
                    "formStableId": None,
                    "isAlpha": False,
                    "isTitan": False,
                    "isRaid": False,
                    "isFixedEncounter": False,
                    "source": {
                        "sourceId": "pokeapi-api-data",
                        "commit": POKEAPI,
                        "license": "BSD-3-Clause",
                    },
                }]
            }
        }
        self.learn = {
            "1": {
                "stableId": "pokemon:1",
                "sourceStatus": "covered",
                "byVersionGroup": {
                    "scarlet-violet": {
                        "levelUp": [{"moveStableId": "move:14", "level": 40}],
                        "machine": ["move:14"],
                        "egg": [],
                        "tutor": [],
                    }
                },
            }
        }
        self.transitions = [{
            "stableId": "evolution:1:2",
            "fromPokemonStableId": "pokemon:1",
            "toPokemonStableId": "pokemon:2",
            "triggers": [{"trigger": "level-up", "minLevel": 16}],
            "applicabilityByVersionGroup": {"scarlet-violet": "unknown"},
            "source": {
                "sourceId": "pokeapi-api-data",
                "scope": "global chain; exact-game applicability unknown",
            },
        }]

    def _write(self, root: Path) -> dict[str, int]:
        return write_species_shards(
            root,
            species_ids=[1],
            obtain_by_species=self.obtain,
            encounters_by_species=self.encounters,
            learn_by_species=self.learn,
            transitions=self.transitions,
            pokeapi_commit=POKEAPI,
            pkhex_commit=PKHEX,
        )

    def test_writes_bounded_strict_shard_and_replaces_summary_rows(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            report = self._write(root)
            self.assertEqual(report["shardCount"], 1)
            self.assertLess(report["maximumShardBytes"], MAX_SHARD_BYTES)
            verified = verify_shard_tree(root, expected_species_ids=[1])
            self.assertEqual(verified, report)
            payload = json.loads((root / "1.json").read_text())
            self.assertIsInstance(payload["obtain"]["byExactVersion"]["violet"], list)
            self.assertEqual(payload["learn"]["byVersionGroup"]["scarlet-violet"]["machine"], ["move:14"])
            self.assertEqual(len(payload["evolutions"]), 1)

    def test_rejects_path_identity_and_unknown_top_level_fields(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self._write(root)
            payload = json.loads((root / "1.json").read_text())
            with self.assertRaisesRegex(ValueError, "path/species"):
                validate_shard(payload, expected_species_id=2)
            unexpected = copy.deepcopy(payload)
            unexpected["secret"] = "must not pass"
            with self.assertRaisesRegex(ValueError, "shard keys differ"):
                validate_shard(unexpected, expected_species_id=1)

    def test_rejects_unbounded_or_mismatched_nested_content(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self._write(root)
            payload = json.loads((root / "1.json").read_text())
            payload["obtain"]["byExactVersion"]["violet"][0]["exactVersion"] = "scarlet"
            with self.assertRaisesRegex(ValueError, "encounter identity"):
                validate_shard(payload, expected_species_id=1)
            payload = json.loads((root / "1.json").read_text())
            payload["learn"]["byVersionGroup"]["scarlet-violet"]["machine"] = ["move:0"]
            with self.assertRaisesRegex(ValueError, "move stable id"):
                validate_shard(payload, expected_species_id=1)


if __name__ == "__main__":
    unittest.main()
