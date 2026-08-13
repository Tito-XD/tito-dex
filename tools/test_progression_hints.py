import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "data/journey/progression_hints.json"
BUNDLED_DATA_PATH = ROOT / "flutter/assets/data/journey/progression_hints.json"
SCHEMA_PATH = ROOT / "data/journey/progression_hints.schema.json"
API_SCHEMA_PATH = ROOT / "data/journey/assistant_api.schema.json"
LOCATION_PATH = ROOT / "data/l10n/zh/location_areas.json"
HGSS_MAP_PATH = ROOT / "data/l10n/zh/hgss_map_ids.json"
ITEM_PATH = ROOT / "data/l10n/zh/items.json"

ID_PATTERN = re.compile(r"^[a-z0-9_-]+$")
GAMES = {"heartgold", "soulsilver"}
RELIABILITIES = {"save_verified", "not_currently_parsed"}


class ProgressionHintsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(DATA_PATH.read_text())
        cls.schema = json.loads(SCHEMA_PATH.read_text())
        cls.api_schema = json.loads(API_SCHEMA_PATH.read_text())
        cls.locations = json.loads(LOCATION_PATH.read_text())
        cls.hgss_map_names = {
            value["nameEn"]
            for value in json.loads(HGSS_MAP_PATH.read_text()).values()
            if value.get("nameEn")
        }
        cls.items = {
            value["slug"]: int(key)
            for key, value in json.loads(ITEM_PATH.read_text()).items()
        }

    def test_api_contract_is_minimal_and_rejects_sensitive_fields(self):
        self.assertFalse(self.api_schema["additionalProperties"])
        context = self.api_schema["properties"]["context"]
        self.assertFalse(context["additionalProperties"])
        self.assertEqual(
            set(context["properties"]),
            {
                "game",
                "generation",
                "locationId",
                "badgeIds",
                "badgeCount",
                "milestoneIds",
                "locale",
                "parserRevision",
                "contextReliability",
            },
        )
        reliability = context["properties"]["contextReliability"]
        self.assertFalse(reliability["additionalProperties"])
        self.assertEqual(
            set(reliability["required"]),
            {"game", "location", "badges", "milestones"},
        )
        forbidden = {"rawSave", "trainerName", "trainerId", "party", "money", "coordinates"}
        self.assertTrue(forbidden.isdisjoint(context["properties"]))

    def test_host_apk_bundles_the_canonical_reviewed_dataset(self):
        self.assertEqual(BUNDLED_DATA_PATH.read_bytes(), DATA_PATH.read_bytes())

    def test_schema_and_entries_are_strictly_valid(self):
        self.assertEqual(self.schema["$schema"], "https://json-schema.org/draft/2020-12/schema")
        self.assertEqual(self.data["schemaVersion"], 1)
        self.assertGreaterEqual(self.data["datasetVersion"], 1)
        self.assertEqual(set(self.data), {"schemaVersion", "datasetVersion", "entries"})

        ids = set()
        for entry in self.data["entries"]:
            self.assertEqual(
                set(entry),
                {
                    "id",
                    "games",
                    "generation",
                    "locations",
                    "locationAliases",
                    "destinationAliases",
                    "subject",
                    "requirements",
                    "steps",
                    "overviewZh",
                    "sources",
                },
            )
            self.assertRegex(entry["id"], ID_PATTERN)
            self.assertNotIn(entry["id"], ids)
            ids.add(entry["id"])
            self.assertTrue(set(entry["games"]).issubset(GAMES))
            self.assertEqual(entry["generation"], 4)
            self.assertEqual(
                set(entry["subject"]),
                {"type", "id", "labelZh", "aliases"},
            )
            self.assertTrue(entry["subject"]["aliases"])
            self.assertLessEqual(len(entry["overviewZh"]), 180)
            self.assertTrue(entry["sources"])
            for source in entry["sources"]:
                self.assertEqual(set(source), {"title", "url", "accessedAt"})
                self.assertTrue(source["url"].startswith("https://"))
                self.assertRegex(source["accessedAt"], r"^\d{4}-\d{2}-\d{2}$")
            orders = [step["order"] for step in entry["steps"]]
            self.assertEqual(orders, list(range(1, len(orders) + 1)))
            for step in entry["steps"]:
                self.assertEqual(
                    set(step),
                    {"order", "action", "targetId", "locationId", "instructionZh"},
                )
                self.assertLessEqual(len(step["instructionZh"]), 120)
            for requirement in entry["requirements"]:
                expected = {"type", "id", "labelZh", "reliability"}
                if requirement["type"] == "key_item":
                    expected.add("itemId")
                self.assertEqual(set(requirement), expected)
                self.assertIn(requirement["reliability"], RELIABILITIES)

    def test_locations_items_and_badges_use_canonical_catalog_ids(self):
        supported_badges = {
            "zephyr_badge",
            "hive_badge",
            "plain_badge",
            "fog_badge",
            "storm_badge",
            "mineral_badge",
            "glacier_badge",
            "rising_badge",
        }
        for entry in self.data["entries"]:
            for location in entry["locations"]:
                self.assertIn(location, self.locations)
            for step in entry["steps"]:
                self.assertIn(step["locationId"], self.hgss_map_names)
            for requirement in entry["requirements"]:
                if requirement["type"] == "badge":
                    self.assertIn(requirement["id"], supported_badges)
                if requirement["type"] == "key_item":
                    self.assertEqual(
                        requirement["itemId"],
                        self.items[requirement["id"]],
                    )

    def test_exact_game_conditions_do_not_conflict(self):
        seen = {}
        for entry in self.data["entries"]:
            for game in entry["games"]:
                for location in entry["locations"]:
                    condition = (game, location, entry["subject"]["id"])
                    self.assertNotIn(condition, seen)
                    seen[condition] = entry["id"]

    def test_mvp_has_sudowoodo_and_multiple_hgss_shapes(self):
        by_id = {entry["id"]: entry for entry in self.data["entries"]}
        sample = by_id["hgss-route36-sudowoodo"]
        self.assertEqual(sample["subject"]["id"], "sudowoodo")
        self.assertIn("squirt-bottle", {item["id"] for item in sample["requirements"]})
        self.assertGreaterEqual(len(by_id), 3)


if __name__ == "__main__":
    unittest.main()
