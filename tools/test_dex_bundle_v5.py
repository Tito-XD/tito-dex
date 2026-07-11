#!/usr/bin/env python3
"""Validate dex bundle v5 output shape (abilities, obtainLocations, pokedexNumbers)."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "tools"))

from build_dex_bundle import (  # noqa: E402
    BUNDLE_CDN_PREFIX,
    BUNDLE_VERSION,
    ability_description_zh,
    encounter_area_label_zh,
    parse_pokedex_numbers,
)


class DexBundleV5ValidationTests(unittest.TestCase):
    def test_helper_pokedex_numbers(self) -> None:
        entries = [
            {"entry_number": 25, "pokedex": {"name": "national"}},
            {"entry_number": 22, "pokedex": {"name": "original-johto"}},
        ]
        self.assertEqual(
            parse_pokedex_numbers(entries),
            {"national": 25, "original-johto": 22},
        )

    def test_encounter_area_label_route(self) -> None:
        self.assertEqual(encounter_area_label_zh("route-3-area"), "3号道路")

    def test_ability_description_prefers_zh(self) -> None:
        detail = {
            "effect_entries": [
                {
                    "language": {"name": "zh-Hans"},
                    "short_effect": "静电",
                    "effect": "long",
                },
                {"language": {"name": "en"}, "short_effect": "Static"},
            ]
        }
        self.assertEqual(ability_description_zh(detail), "静电")

    def test_sample_detail_json_has_v5_fields(self) -> None:
        bundle_dir = REPO_ROOT / "dist" / "dex-v5-smoke" / "upload" / BUNDLE_CDN_PREFIX
        detail_path = bundle_dir / "details" / "1.json"
        if not detail_path.exists():
            self.skipTest(f"Smoke build not found at {detail_path}")

        detail = json.loads(detail_path.read_text(encoding="utf-8"))
        self.assertIn("abilities", detail)
        self.assertIn("obtainLocations", detail)
        self.assertIn("moveSets", detail)
        self.assertIsInstance(detail["abilities"], list)
        self.assertIsInstance(detail["obtainLocations"], list)
        if detail["abilities"]:
            ability = detail["abilities"][0]
            for key in ("nameEn", "nameZh", "descriptionZh", "isHidden"):
                self.assertIn(key, ability)

        summaries_path = bundle_dir / "summaries.json"
        summaries = json.loads(summaries_path.read_text(encoding="utf-8"))
        self.assertTrue(summaries)
        self.assertIn("pokedexNumbers", summaries[0])
        self.assertIn("national", summaries[0]["pokedexNumbers"])

        abilities_index = json.loads(
            (bundle_dir / "abilities.json").read_text(encoding="utf-8")
        )
        self.assertTrue(abilities_index)
        first = next(iter(abilities_index.values()))
        self.assertIn("pokemonIds", first)

        manifest = json.loads(
            (REPO_ROOT / "dist" / "dex-v5-smoke" / "upload" / "bundle-manifest.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(manifest["bundleVersion"], BUNDLE_VERSION)
        self.assertIn(f"/{BUNDLE_CDN_PREFIX}/bundle.tar.zst", manifest["archiveUrl"])


def validate_detail_dir(details_dir: Path) -> list[str]:
    errors: list[str] = []
    for detail_file in sorted(details_dir.glob("*.json")):
        detail = json.loads(detail_file.read_text(encoding="utf-8"))
        for key in ("abilities", "obtainLocations"):
            if key not in detail:
                errors.append(f"{detail_file.name}: missing {key}")
    return errors


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        target = Path(sys.argv[2]) if len(sys.argv) > 2 else REPO_ROOT / "dist" / "dex-v5-smoke" / "upload" / BUNDLE_CDN_PREFIX / "details"
        errors = validate_detail_dir(target)
        if errors:
            print("\n".join(errors), file=sys.stderr)
            sys.exit(1)
        print(f"OK: {target}")
        sys.exit(0)
    unittest.main()
