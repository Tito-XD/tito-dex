#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from patch_dex_bundle_v7 import (  # noqa: E402
    enrich_form_sprite_metadata,
    reuse_clear_thumbnails_as_artwork,
    rewrite_prefixes,
)


class PatchDexBundleV7Tests(unittest.TestCase):
    def test_rewrite_prefixes_only_changes_version_path(self) -> None:
        payload = {
            "sprite": "https://dex.example/v4/sprites/25.png",
            "source": "https://example.invalid/v4-not-a-prefix",
            "nested": ["https://dex.example/v4/details/25.json"],
        }
        rewritten = rewrite_prefixes(payload, "v4", "v5")
        self.assertEqual(
            rewritten["sprite"],
            "https://dex.example/v5/sprites/25.png",
        )
        self.assertEqual(
            rewritten["nested"],
            ["https://dex.example/v5/details/25.json"],
        )
        self.assertEqual(payload["source"], rewritten["source"])

    def test_clear_thumbnails_are_reused_for_artwork(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            staging = Path(temp)
            sprites = staging / "sprites"
            sprites.mkdir()
            for pokemon_id in range(1, 1026):
                (sprites / f"{pokemon_id}.png").write_bytes(
                    f"clear-{pokemon_id}".encode()
                )
            reuse_clear_thumbnails_as_artwork(staging)
            self.assertEqual(
                (staging / "artwork" / "25.png").read_bytes(),
                b"clear-25",
            )
            self.assertEqual(
                len(list((staging / "artwork").glob("*.png"))),
                1025,
            )

    def test_form_sprite_metadata_is_enriched_without_touching_locations(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp:
            staging = Path(temp)
            details = staging / "details"
            details.mkdir()
            location = {
                "speciesId": 6,
                "pokemonId": 10034,
                "formKey": "charizard-mega-x",
                "areaSlug": "sample",
            }
            detail = {
                "forms": [
                    {
                        "key": "charizard-mega-x",
                        "pokemonId": 10034,
                        "formId": 10058,
                        "introducedVersionGroup": "x-y",
                        "availableVersionGroups": ["x-y"],
                        "localSpritePath": "sprites/forms/10058.png",
                        "obtainLocationsByVersion": {"x": [location]},
                    }
                ]
            }
            path = details / "6.json"
            path.write_text(json.dumps(detail), encoding="utf-8")
            form_sprites = {
                "versions": {
                    "generation-vi": {
                        "x-y": {"front_default": "https://example.invalid/mega-x.png"}
                    }
                }
            }

            updated = enrich_form_sprite_metadata(
                staging,
                {10034: {"sprites": {}}},
                {10058: {"sprites": form_sprites}},
            )

            result = json.loads(path.read_text(encoding="utf-8"))
            form = result["forms"][0]
            self.assertEqual(updated, 1)
            self.assertEqual(
                form["spriteUrlsByVersion"],
                {"x-y": "https://example.invalid/mega-x.png"},
            )
            self.assertEqual(
                form["obtainLocationsByVersion"],
                {"x": [location]},
            )


if __name__ == "__main__":
    unittest.main()
