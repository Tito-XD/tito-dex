#!/usr/bin/env python3

from __future__ import annotations

import unittest

from pokemon_forms import (
    classify_form,
    form_label_zh,
    is_cosmetic_variety,
    variety_suffix,
)


def pokemon_payload(
    *,
    types: tuple[str, ...] = ("water",),
    attack: int = 50,
    ability: str = "damp",
    height: int = 4,
    weight: int = 85,
) -> dict:
    return {
        "types": [
            {"slot": index + 1, "type": {"name": type_name}}
            for index, type_name in enumerate(types)
        ],
        "stats": [{"base_stat": attack, "stat": {"name": "attack"}}],
        "abilities": [
            {
                "ability": {"name": ability},
                "is_hidden": False,
                "slot": 1,
            }
        ],
        "moves": [{"move": {"name": "tackle"}}],
        "height": height,
        "weight": weight,
    }


class PokemonFormsTests(unittest.TestCase):
    def test_variety_suffix_keeps_hyphenated_species(self) -> None:
        self.assertEqual(
            variety_suffix("mr-mime", "mr-mime-galar"),
            "galar",
        )

    def test_classifies_region_mega_gmax_and_battle_forms(self) -> None:
        self.assertEqual(classify_form("wooper", "wooper-paldea"), "regional")
        self.assertEqual(classify_form("charizard", "charizard-mega-x"), "mega")
        self.assertEqual(classify_form("charizard", "charizard-gmax"), "gigantamax")
        self.assertEqual(
            classify_form("meloetta", "meloetta-pirouette", is_battle_only=True),
            "battle",
        )

    def test_cosmetic_requires_all_battle_fields_to_match(self) -> None:
        default = pokemon_payload()
        self.assertTrue(is_cosmetic_variety(default, pokemon_payload()))
        self.assertFalse(
            is_cosmetic_variety(
                default,
                pokemon_payload(types=("poison", "ground")),
            )
        )
        self.assertFalse(
            is_cosmetic_variety(default, pokemon_payload(), is_battle_only=True)
        )

    def test_chinese_fallback_labels_known_forms(self) -> None:
        self.assertEqual(
            form_label_zh("乌波", "wooper", "wooper-paldea"),
            "乌波（帕底亚的样子）",
        )
        self.assertEqual(
            form_label_zh("美洛耶塔", "meloetta", "meloetta-pirouette"),
            "美洛耶塔（舞步形态）",
        )
        self.assertEqual(
            form_label_zh("基格尔德", "zygarde", "zygarde-complete"),
            "基格尔德（完全体形态）",
        )

    def test_no_fabricated_one_percent_zygarde_form(self) -> None:
        # PokeAPI exposes 10%, 50%, and Complete battle varieties.  Cells and
        # Cores are components rather than selectable Pokemon varieties.
        known = {
            form_label_zh("基格尔德", "zygarde", slug)
            for slug in ("zygarde-10", "zygarde-50", "zygarde-complete")
        }
        self.assertNotIn("基格尔德（1%形态）", known)


if __name__ == "__main__":
    unittest.main()
