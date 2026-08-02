import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_version_availability_index import (
    accessible_versions,
    build_index,
)


CHAIN = {
    "id": 1,
    "children": [
        {
            "id": 2,
            "triggerZh": "Lv.20",
            "children": [
                {
                    "id": 3,
                    "triggerZh": "交换",
                    "triggers": [{"trigger": "trade"}],
                    "children": [],
                }
            ],
        }
    ],
}


def detail(species_id, locations=None):
    return {
        "summary": {"id": species_id},
        "evolutionChain": CHAIN,
        "obtainLocationsByVersion": locations or {},
    }


class VersionAvailabilityIndexTest(unittest.TestCase):
    def test_dlc_access_inherits_base_version(self):
        self.assertEqual(
            accessible_versions("the-crown-tundra-sword"),
            {"sword", "the-isle-of-armor-sword", "the-crown-tundra-sword"},
        )

    def test_exact_and_merged_selections_plan_chain(self):
        payload = build_index(
            {
                1: detail(1, {"sword": [{"area": "route"}]}),
                2: detail(2),
                3: detail(3, {"shield": [{"area": "route"}]}),
            }
        )
        by_selection = payload["bySelection"]

        self.assertEqual(by_selection["sword"], [2, 3])
        self.assertEqual(by_selection["shield"], [1, 2])
        self.assertEqual(by_selection["@sword-shield"], [2])


if __name__ == "__main__":
    unittest.main()
