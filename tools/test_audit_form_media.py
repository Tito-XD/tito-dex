#!/usr/bin/env python3
"""Regression tests for explicit form media mapping."""

from __future__ import annotations

import unittest

from audit_form_media import form_codes, map_form_keys


class FormMediaAuditTests(unittest.TestCase):
    def test_home_codes_map_exact_and_shared_forms(self) -> None:
        forms = [
            {"key": "charizard", "isDefault": True},
            {"key": "charizard-mega-x", "isDefault": False},
            {"key": "charizard-mega-y", "isDefault": False},
            {"key": "charizard-gmax", "isDefault": False},
        ]
        keys, code = map_form_keys("HOME_006MX.png", 6, "Charizard", forms)
        self.assertEqual(keys, ["charizard-mega-x"])
        self.assertEqual(code, "MX")

        ride_forms = [
            {"key": "koraidon-apex-build", "isDefault": True},
            {"key": "koraidon-limited-build", "isDefault": False},
            {"key": "koraidon-sprinting-build", "isDefault": False},
            {"key": "koraidon-swimming-build", "isDefault": False},
            {"key": "koraidon-gliding-build", "isDefault": False},
        ]
        keys, code = map_form_keys("HOME_1007L.png", 1007, "Koraidon", ride_forms)
        self.assertEqual(len(keys), 4)
        self.assertEqual(code, "L")

    def test_special_cosmetic_codes_are_explicit(self) -> None:
        self.assertEqual(
            form_codes(
                201,
                {"key": "unown-exclamation", "isDefault": False},
                "unown",
            ),
            {"EX"},
        )
        self.assertEqual(
            form_codes(
                869,
                {
                    "key": "alcremie-rainbow-swirl-ribbon-sweet",
                    "isDefault": False,
                },
                "alcremie",
            ),
            {"RaSR"},
        )

    def test_full_name_form_art_maps_without_guessing_url(self) -> None:
        forms = [
            {"key": "venusaur", "isDefault": True},
            {"key": "venusaur-mega", "isDefault": False},
            {"key": "venusaur-gmax", "isDefault": False},
        ]
        keys, code = map_form_keys(
            "003Venusaur-Gigantamax.png", 3, "Venusaur", forms
        )
        self.assertEqual(keys, ["venusaur-gmax"])
        self.assertIsNone(code)

    def test_full_name_form_art_maps_species_above_99(self) -> None:
        forms = [
            {"key": "tauros", "isDefault": True},
            {"key": "tauros-paldea-combat-breed", "isDefault": False},
        ]
        keys, code = map_form_keys(
            "128Tauros-Paldea-Combat-Breed.png", 128, "Tauros", forms
        )
        self.assertEqual(keys, ["tauros-paldea-combat-breed"])
        self.assertIsNone(code)

    def test_alcremie_full_name_abbreviations_map_explicitly(self) -> None:
        forms = [
            {
                "key": "alcremie-rainbow-swirl-ribbon-sweet",
                "isDefault": False,
            }
        ]
        keys, code = map_form_keys(
            "869Alcremie-RainbowSwirlRS.png", 869, "Alcremie", forms
        )
        self.assertEqual(keys, ["alcremie-rainbow-swirl-ribbon-sweet"])
        self.assertIsNone(code)


if __name__ == "__main__":
    unittest.main()
