import copy
import json
import unittest
from pathlib import Path

from tools.validate_journey_fact_pack import validate_supply_chain


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data/journey"


def read(name: str) -> dict:
    return json.loads((DATA / name).read_text(encoding="utf-8"))


class JourneyFactPackSupplyChainTest(unittest.TestCase):
    def setUp(self):
        self.registry = read("sources/source_registry.json")
        self.lock = read("sources/source_lock.json")
        self.pack = read("packs/hgss/facts.json")

    def test_three_schemas_are_strict_and_release_inputs_pass(self):
        for name in (
            "source_registry.schema.json",
            "source_lock.schema.json",
            "fact_pack.schema.json",
        ):
            schema = read(name)
            self.assertEqual(schema["$schema"], "https://json-schema.org/draft/2020-12/schema")
            self.assertFalse(schema["additionalProperties"])
        validate_supply_chain(self.registry, self.lock, self.pack)
        validate_supply_chain(self.registry, self.lock, self.pack, release=True)

    def test_only_pokeapi_and_wikidata_can_enable_automated_import(self):
        enabled = {
            source["sourceId"]
            for source in self.registry["sources"]
            if source["acquisition"]["automatedImport"]
        }
        self.assertEqual(enabled, {"pokeapi-api-data", "wikidata"})

        registry = copy.deepcopy(self.registry)
        bulba = next(item for item in registry["sources"] if item["sourceId"] == "bulbapedia")
        bulba["acquisition"] = {
            "mode": "pinned_auto_import",
            "automatedImport": True,
            "policyUrl": bulba["canonicalUrl"],
        }
        with self.assertRaisesRegex(ValueError, "not allowlisted"):
            validate_supply_chain(registry, self.lock, self.pack)

    def test_allowed_use_and_review_gates_fail_closed(self):
        registry = copy.deepcopy(self.registry)
        bulba = next(item for item in registry["sources"] if item["sourceId"] == "bulbapedia")
        bulba["allowedUses"] = ["structured_data"]
        with self.assertRaisesRegex(ValueError, "does not allow fact_check"):
            validate_supply_chain(registry, self.lock, self.pack)

        pack = copy.deepcopy(self.pack)
        pack["facts"][0]["review"]["status"] = "in_review"
        with self.assertRaisesRegex(ValueError, "only approved facts"):
            validate_supply_chain(self.registry, self.lock, pack)

        source_lock = copy.deepcopy(self.lock)
        source_lock["locks"][0]["revision"]["kind"] = "unlocked_legacy"
        with self.assertRaisesRegex(ValueError, "unlocked legacy"):
            validate_supply_chain(self.registry, source_lock, self.pack, release=True)


if __name__ == "__main__":
    unittest.main()
