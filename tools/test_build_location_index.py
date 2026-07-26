#!/usr/bin/env python3
"""Unit tests for the reverse location index (v12)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_location_index import LocationIndexBuilder  # noqa: E402


def _entry(**overrides):
    base = {
        "areaSlug": "kanto-route-34-area",
        "areaLabelZh": "34号道路",
        "methods": ["walk"],
        "maxChance": 10,
        "minLevel": 10,
        "maxLevel": 12,
    }
    base.update(overrides)
    return base


class LocationIndexTests(unittest.TestCase):
    def test_inverts_default_and_form_lists(self):
        builder = LocationIndexBuilder()
        added = builder.add_detail(
            63,
            {
                "obtainLocationsByVersion": {
                    "soulsilver": [_entry()],
                    "heartgold": [_entry(maxChance=5)],
                },
                "forms": [
                    {
                        "key": "abra-variant",
                        "obtainLocationsByVersion": {
                            "soulsilver": [
                                _entry(areaSlug="ilex-forest-area",
                                       areaLabelZh="桧皮森林")
                            ],
                        },
                    }
                ],
            },
        )
        self.assertEqual(added, 3)

        index = builder.build()
        self.assertEqual(index["version"], 1)
        self.assertEqual(
            sorted(index["byVersion"].keys()), ["heartgold", "soulsilver"]
        )
        soulsilver = index["byVersion"]["soulsilver"]
        self.assertIn("kanto-route-34-area", soulsilver)
        self.assertIn("ilex-forest-area", soulsilver)
        form_entry = soulsilver["ilex-forest-area"]["entries"][0]
        self.assertEqual(form_entry["speciesId"], 63)
        self.assertEqual(form_entry["formKey"], "abra-variant")
        self.assertEqual(soulsilver["ilex-forest-area"]["labelZh"], "桧皮森林")

    def test_exact_duplicates_collapse(self):
        builder = LocationIndexBuilder()
        detail = {
            "obtainLocationsByVersion": {"soulsilver": [_entry(), _entry()]}
        }
        self.assertEqual(builder.add_detail(63, detail), 1)
        # The same detail fed twice (default list mirrored on a form) either.
        self.assertEqual(builder.add_detail(63, detail), 0)

    def test_form_aware_fields_and_flags_survive(self):
        builder = LocationIndexBuilder()
        builder.add_detail(
            904,
            {
                "obtainLocationsByVersion": {
                    "legends-arceus": [
                        _entry(
                            areaSlug="alabaster-icelands",
                            areaLabelZh="纯白冻土",
                            formKey="overqwil",
                            isAlpha=True,
                            formAmbiguous=True,
                            teraType="dark",
                            conditions=["time-dusk"],
                        )
                    ]
                }
            },
        )
        entry = builder.build()["byVersion"]["legends-arceus"][
            "alabaster-icelands"
        ]["entries"][0]
        self.assertEqual(entry["formKey"], "overqwil")
        self.assertTrue(entry["isAlpha"])
        self.assertTrue(entry["formAmbiguous"])
        self.assertEqual(entry["teraType"], "dark")
        self.assertEqual(entry["conditions"], ["time-dusk"])
        # False flags and empty values are omitted, toJson-style.
        self.assertNotIn("isTitan", entry)
        self.assertNotIn("rateValue", entry)

    def test_entries_sorted_for_deterministic_output(self):
        builder = LocationIndexBuilder()
        builder.add_detail(
            129, {"obtainLocationsByVersion": {"soulsilver": [_entry()]}}
        )
        builder.add_detail(
            63, {"obtainLocationsByVersion": {"soulsilver": [_entry()]}}
        )
        entries = builder.build()["byVersion"]["soulsilver"][
            "kanto-route-34-area"
        ]["entries"]
        self.assertEqual([e["speciesId"] for e in entries], [63, 129])

    def test_missing_area_slug_is_skipped(self):
        builder = LocationIndexBuilder()
        added = builder.add_detail(
            63,
            {
                "obtainLocationsByVersion": {
                    "soulsilver": [{"areaLabelZh": "无slug"}]
                }
            },
        )
        self.assertEqual(added, 0)
        self.assertEqual(builder.entry_count, 0)


if __name__ == "__main__":
    unittest.main()
