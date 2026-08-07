#!/usr/bin/env python3
"""Regression tests for exact per-version sprite availability."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from generate_sprite_version_existence import (  # noqa: E402
    compress_ranges,
    extract_ids,
)
from pokeapi_assets import (  # noqa: E402
    SPRITE_VERSION_EXISTENCE,
    build_sprite_url_map,
    sprite_asset_exists,
)


class SpriteVersionExistenceTests(unittest.TestCase):
    def test_generated_matrix_is_pinned_and_covers_exact_sources(self) -> None:
        self.assertRegex(
            SPRITE_VERSION_EXISTENCE["sourceCommit"], r"^[0-9a-f]{40}$"
        )
        groups = SPRITE_VERSION_EXISTENCE["versionGroups"]
        self.assertIn("brilliant-diamond-shining-pearl", groups)
        self.assertIn("scarlet-violet", groups)
        self.assertNotIn("sword-shield", groups)
        self.assertNotIn("legends-arceus", groups)
        media = SPRITE_VERSION_EXISTENCE["mediaAssets"]
        self.assertIn("home", media)
        self.assertIn("officialArtworkShiny", media)
        self.assertIn("showdownAnimated", media)
        self.assertEqual(
            SPRITE_VERSION_EXISTENCE["itemAssets"]["pathPrefix"],
            "sprites/items",
        )
        self.assertIn(
            "oran-berry.png",
            SPRITE_VERSION_EXISTENCE["itemAssets"]["files"],
        )

    def test_file_matrix_and_debut_cap_are_both_required(self) -> None:
        self.assertTrue(sprite_asset_exists("scarlet-violet", 25))
        self.assertFalse(sprite_asset_exists("scarlet-violet", 10))
        self.assertTrue(
            sprite_asset_exists("brilliant-diamond-shining-pearl", 493)
        )
        self.assertFalse(
            sprite_asset_exists("brilliant-diamond-shining-pearl", 494)
        )
        self.assertFalse(sprite_asset_exists("black-white", 1000))

    def test_sprite_map_drops_api_slots_without_exact_files(self) -> None:
        sprites = {
            "versions": {
                "generation-v": {
                    "black-white": {
                        "front_default": (
                            "https://raw.githubusercontent.com/PokeAPI/sprites/"
                            "master/sprites/pokemon/versions/generation-v/"
                            "black-white/1000.png"
                        )
                    }
                },
                "generation-ix": {
                    "scarlet-violet": {
                        "front_default": (
                            "https://raw.githubusercontent.com/PokeAPI/sprites/"
                            "master/sprites/pokemon/versions/generation-ix/"
                            "scarlet-violet/1000.png"
                        )
                    }
                },
            },
            "other": {
                "official-artwork": {
                    "front_default": "https://example.invalid/1000.png"
                }
            },
        }
        result = build_sprite_url_map(sprites)
        self.assertNotIn("black-white", result)
        self.assertIn("scarlet-violet", result)

    def test_generator_compresses_and_classifies_exact_paths(self) -> None:
        self.assertEqual(compress_ranges([3, 1, 2, 7, 7]), [[1, 3], [7, 7]])
        extracted = extract_ids(
            [
                {"type": "blob", "path": "game/1.png"},
                {"type": "blob", "path": "game/back/1.png"},
                {"type": "blob", "path": "game/animated/1.gif"},
                {"type": "blob", "path": "game/animated/back/1.gif"},
                {"type": "blob", "path": "game/493-unknown.png"},
                {"type": "blob", "path": "game/shiny/493-unknown.png"},
                {"type": "blob", "path": "other/2.png"},
                {"type": "blob", "path": "game/0.png"},
            ],
            folder_within_generation="game",
        )
        self.assertEqual(extracted["front"], [1])
        self.assertEqual(extracted["back"], [1])
        self.assertEqual(extracted["animatedFront"], [1])
        self.assertEqual(extracted["animatedBack"], [1])
        self.assertEqual(extracted["namedFront"], ["493-unknown.png"])
        self.assertEqual(
            extracted["namedShinyFront"], ["shiny/493-unknown.png"]
        )

    def test_generator_classifies_shiny_version_paths_separately(self) -> None:
        extracted = extract_ids(
            [
                {"type": "blob", "path": "game/shiny/1.png"},
                {"type": "blob", "path": "game/back/shiny/2.png"},
                {"type": "blob", "path": "game/animated/shiny/3.gif"},
                {
                    "type": "blob",
                    "path": "game/animated/back/shiny/4.gif",
                },
            ],
            folder_within_generation="game",
        )
        self.assertEqual(extracted["shinyFront"], [1])
        self.assertEqual(extracted["shinyBack"], [2])
        self.assertEqual(extracted["animatedShinyFront"], [3])
        self.assertEqual(extracted["animatedShinyBack"], [4])


if __name__ == "__main__":
    unittest.main()
