from __future__ import annotations

import importlib.util
import json
import sys
import unittest
from pathlib import Path


TOOLS = Path(__file__).parent
sys.path.insert(0, str(TOOLS))


def load(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, TOOLS / filename)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gameplay = load("v20_gameplay", "build_dex_bundle_v20_gameplay.py")
overlay = load("v20_reference_overlay", "build_dex_v20_reference_overlay.py")


class GameplayV20Test(unittest.TestCase):
    def setUp(self) -> None:
        self.keys_payload = json.loads(gameplay.VERSION_KEYS.read_text(encoding="utf-8"))
        self.keys = gameplay.VersionKeys(self.keys_payload)

    def test_version_keys_normalize_legends_za(self) -> None:
        self.assertEqual(len(self.keys.groups), 23)
        self.assertEqual(self.keys.normalize("legends-z-a"), "legends-za")
        self.assertEqual(self.keys.group_for("mega-dimension"), "legends-za")
        self.assertEqual(self.keys.group_for("violet"), "scarlet-violet")

    def test_family_plan_distinguishes_trade_and_egg_candidates(self) -> None:
        chain = {
            "id": 1,
            "triggers": [],
            "children": [
                {
                    "id": 2,
                    "triggers": [{"trigger": "level-up"}],
                    "children": [
                        {
                            "id": 3,
                            "triggers": [{"trigger": "trade"}],
                            "children": [],
                        }
                    ],
                }
            ],
        }
        plan = gameplay.plan_chain(chain, {2}, supports_breeding=True)
        self.assertEqual(plan, {1: "egg", 2: "direct", 3: "trade"})

    def test_trade_species_links_to_stable_pokemon_id(self) -> None:
        result = gameplay.normalize_trigger(
            {"trigger": "trade", "tradeSpecies": "shelmet"},
            items_by_slug={},
            moves_by_slug={},
            pokemon_by_slug={"shelmet": "pokemon:616"},
        )
        self.assertEqual(result["tradeSpeciesStableId"], "pokemon:616")
        self.assertEqual(result["tradeSpeciesResolution"], "resolved")

    def test_story_links_ignore_held_item_relationships(self) -> None:
        hints = {
            "datasetVersion": 5,
            "entries": [
                {
                    "id": "golden",
                    "games": ["heartgold"],
                    "generation": 4,
                    "locations": ["route"],
                    "subject": {"id": "tree"},
                    "requirements": [
                        {
                            "type": "key_item",
                            "id": "squirt-bottle",
                            "labelZh": "杰尼龟喷壶",
                            "reliability": "reviewed",
                        },
                        {
                            "type": "held_item",
                            "id": "leftovers",
                            "labelZh": "剩饭",
                            "reliability": "reviewed",
                        },
                    ],
                    "sources": [{"title": "Reviewed source"}],
                }
            ],
        }
        items = {
            "1": {"id": 448, "slug": "squirt-bottle", "stableId": "item:448"},
            "2": {"id": 234, "slug": "leftovers", "stableId": "item:234"},
        }
        result = gameplay.build_story_item_links(hints, items)
        self.assertEqual([row["itemStableId"] for row in result["links"]], ["item:448"])
        self.assertNotIn("item:234", json.dumps(result))

    def test_only_pinned_pkhex_overlays_are_indexed(self) -> None:
        indexed = gameplay.load_overlay_encounters(self.keys)
        self.assertEqual(len(indexed), 17)
        self.assertNotIn("x", indexed)
        source = next(iter(indexed["violet"].values()))
        self.assertEqual(source["commit"], overlay.PKHEX_COMMIT)

    def test_overlay_provenance_covers_expected_paths(self) -> None:
        provenance = overlay.build_provenance(
            generated_at="2026-08-23T00:00:00+00:00",
            version_keys=self.keys_payload,
        )
        self.assertEqual(provenance["baseBundleVersion"], 19)
        patterns = {row["pathPattern"] for row in provenance["objects"]}
        self.assertIn("moves.json", patterns)
        self.assertIn("gameplay/obtain_methods.json", patterns)
        self.assertNotIn("manifest.json", patterns)
        self.assertNotIn("provenance.json", patterns)
        self.assertTrue(
            all(20 <= row["priority"] <= 99 for row in provenance["objects"])
        )
        schema_path = gameplay.ROOT / "data" / "dex" / "bundle_overlay.schema.json"
        if schema_path.is_file():
            try:
                import jsonschema
            except ImportError:
                return
            jsonschema.validate(provenance, json.loads(schema_path.read_text()))


if __name__ == "__main__":
    unittest.main()
