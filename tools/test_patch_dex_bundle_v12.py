#!/usr/bin/env python3
"""Unit tests for the v11 → v12 species-axes patch."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from patch_dex_bundle_v12_species_axes import (  # noqa: E402
    apply_triggers,
    detail_additions,
    summary_additions,
    triggers_by_species,
)


def _species(**overrides):
    base = {
        "generation": {"name": "generation-i"},
        "shape": {"name": "quadruped"},
        "color": {"name": "brown"},
        "growth_rate": {"name": "slow"},
        "habitat": {"name": "grassland"},
        "is_legendary": False,
        "is_mythical": False,
        "is_baby": False,
        "has_gender_differences": False,
    }
    base.update(overrides)
    return base


class SummaryAdditionsTests(unittest.TestCase):
    def test_carries_every_searchable_field(self):
        adds = summary_additions(
            _species(),
            {"height": 7},
            {"summary": {"id": 58}, "genusZh": "小狗宝可梦"},
        )
        self.assertEqual(
            adds,
            {
                "genusZh": "小狗宝可梦",
                "generation": 1,
                "shapeSlug": "quadruped",
                "colorSlug": "brown",
                "heightDm": 7,
            },
        )

    def test_pseudo_legendary_is_tagged_without_a_pokeapi_flag(self):
        adds = summary_additions(
            _species(generation={"name": "generation-iv"}),
            {"height": 19},
            {"summary": {"id": 445}, "genusZh": "斧牙宝可梦"},
        )
        self.assertEqual(adds["tags"], ["pseudo-legendary"])

    def test_legendary_flag_becomes_a_tag(self):
        adds = summary_additions(
            _species(is_legendary=True),
            {"height": 52},
            {"summary": {"id": 249}, "genusZh": "潜水宝可梦"},
        )
        self.assertEqual(adds["tags"], ["legendary"])

    def test_height_falls_back_to_the_existing_detail_value(self):
        adds = summary_additions(
            _species(), {}, {"summary": {"id": 1}, "heightDm": 7}
        )
        self.assertEqual(adds["heightDm"], 7)

    def test_missing_optional_fields_are_omitted_not_nulled(self):
        adds = summary_additions(
            {"generation": None, "shape": None, "color": None},
            {},
            {"summary": {"id": 9999}},
        )
        self.assertEqual(adds, {})


class DetailAdditionsTests(unittest.TestCase):
    def test_slugs_only_no_localized_labels(self):
        adds = detail_additions(_species(), {"base_experience": 64})
        self.assertEqual(adds["growthRateSlug"], "slow")
        self.assertEqual(adds["habitatSlug"], "grassland")
        self.assertNotIn("growthRateZh", adds)
        self.assertNotIn("habitatZh", adds)

    def test_post_gen3_species_get_no_habitat(self):
        adds = detail_additions(_species(habitat=None), {})
        self.assertNotIn("habitatSlug", adds)

    def test_held_items_keep_per_version_rarity(self):
        adds = detail_additions(
            _species(),
            {
                "held_items": [
                    {
                        "item": {"name": "metal-coat"},
                        "version_details": [
                            {"rarity": 5, "version": {"name": "heartgold"}}
                        ],
                    }
                ]
            },
        )
        self.assertEqual(adds["heldItems"][0]["slug"], "metal-coat")
        self.assertEqual(
            adds["heldItems"][0]["rarityByVersion"], {"heartgold": 5}
        )


class EvolutionTriggerTests(unittest.TestCase):
    # Scyther → Scizor: trade holding Metal Coat. `triggerZh` flattens this to a
    # bare 交换 because the display helper never reads `held_item`.
    CHAIN = {
        "species": {"url": "https://pokeapi.co/api/v2/pokemon-species/123/"},
        "evolution_details": [],
        "evolves_to": [
            {
                "species": {
                    "url": "https://pokeapi.co/api/v2/pokemon-species/212/"
                },
                "evolution_details": [
                    {
                        "trigger": {"name": "trade"},
                        "held_item": {"name": "metal-coat"},
                        "item": None,
                        "min_level": None,
                    }
                ],
                "evolves_to": [],
            }
        ],
    }

    def test_flattens_a_chain_to_species_id_keys(self):
        lookup = triggers_by_species(self.CHAIN)
        self.assertEqual(
            lookup, {212: [{"trigger": "trade", "heldItem": "metal-coat"}]}
        )
        self.assertNotIn(123, lookup, "a root with no condition gets no entry")

    def test_attaches_triggers_onto_the_bundle_tree(self):
        node = {
            "id": 123,
            "triggerZh": None,
            "children": [{"id": 212, "triggerZh": "交换", "children": []}],
        }
        annotated = apply_triggers(node, triggers_by_species(self.CHAIN))
        self.assertEqual(annotated, 1)
        scizor = node["children"][0]
        self.assertEqual(
            scizor["triggers"], [{"trigger": "trade", "heldItem": "metal-coat"}]
        )
        # The display string must survive untouched so existing UI is unaffected.
        self.assertEqual(scizor["triggerZh"], "交换")
        self.assertNotIn("triggers", node)

    def test_nodes_without_conditions_stay_unannotated(self):
        node = {"id": 1, "children": [{"id": 2, "children": []}]}
        self.assertEqual(apply_triggers(node, {}), 0)
        self.assertEqual(
            json.dumps(node, sort_keys=True),
            json.dumps(
                {"id": 1, "children": [{"id": 2, "children": []}]},
                sort_keys=True,
            ),
        )


if __name__ == "__main__":
    unittest.main()
