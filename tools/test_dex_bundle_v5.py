#!/usr/bin/env python3
"""Validate dex bundle v5/v0.4.0 output shape."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import build_dex_bundle as dex_builder  # noqa: E402
from build_dex_bundle import (  # noqa: E402
    BUNDLE_CDN_PREFIX,
    BUNDLE_VERSION,
    GAME_EDITIONS,
    ability_description_zh,
    encounter_area_label_zh,
    fetch_obtain_locations,
    fetch_species_obtain_locations,
    merge_obtain_location_versions,
    parse_ev_yield,
    parse_pokedex_numbers,
    parse_obtain_locations_by_version,
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

    def test_ev_yield_reads_pokemon_stat_effort_values(self) -> None:
        self.assertEqual(
            parse_ev_yield([
                {"effort": 0, "stat": {"name": "hp"}},
                {"effort": 2, "stat": {"name": "special-attack"}},
            ]),
            {"specialAttack": 2},
        )

    def test_game_editions_count(self) -> None:
        self.assertEqual(len(GAME_EDITIONS), 23)
        by_slug = {edition.slug: edition for edition in GAME_EDITIONS}
        self.assertEqual(by_slug["lza"].version_group, "legends-za")
        self.assertEqual(by_slug["champions"].version_group, "champions")
        self.assertIn(
            "the-crown-tundra-shield", by_slug["swsh"].encounter_versions
        )
        self.assertIn(
            "the-indigo-disk-violet", by_slug["sv"].encounter_versions
        )

    def test_encounters_preserve_exact_versions_and_details(self) -> None:
        encounters = [
            {
                "location_area": {
                    "name": "route-3-area",
                    "url": "https://pokeapi.co/api/v2/location-area/route-3-area/"
                },
                "version_details": [
                    {
                        "version": {"name": "red"},
                        "max_chance": 25,
                        "encounter_details": [
                            {
                                "min_level": 3,
                                "max_level": 5,
                                "method": {"name": "walk"},
                                "condition_values": [{"name": "time-day"}],
                            }
                        ],
                    },
                    {
                        "version": {"name": "blue"},
                        "max_chance": 15,
                        "encounter_details": [
                            {
                                "min_level": 4,
                                "max_level": 7,
                                "method": {"name": "walk"},
                                "condition_values": [],
                            }
                        ],
                    },
                ],
            }
        ]
        by_version = parse_obtain_locations_by_version(
            encounters,
            pokemon_id=10091,
            species_id=19,
            form_key="rattata-alola",
            is_default_form=False,
        )
        self.assertEqual(set(by_version), {"blue", "red"})
        self.assertEqual(by_version["red"][0]["versions"], ["red"])
        self.assertEqual(by_version["red"][0]["minLevel"], 3)
        self.assertEqual(by_version["red"][0]["maxLevel"], 5)
        self.assertEqual(by_version["red"][0]["methods"], ["walk"])
        self.assertEqual(by_version["red"][0]["conditions"], ["time-day"])
        self.assertEqual(by_version["red"][0]["pokemonId"], 10091)
        self.assertEqual(by_version["red"][0]["speciesId"], 19)
        self.assertEqual(by_version["red"][0]["formKey"], "rattata-alola")

        grouped = merge_obtain_location_versions(by_version, {"red", "blue"})
        self.assertEqual(grouped[0]["versions"], ["blue", "red"])
        self.assertEqual(grouped[0]["minLevel"], 3)
        self.assertEqual(grouped[0]["maxLevel"], 7)
        self.assertEqual(grouped[0]["maxChance"], 25)

    def test_encounter_corrections_remove_known_bad_cross_region_rows(self) -> None:
        roaming = parse_obtain_locations_by_version(
            [{
                "location_area": {
                    "name": "team-flare-secret-hq-area",
                    "url": "https://pokeapi.co/api/v2/location-area/1176/",
                },
                "version_details": [{
                    "version": {"name": "black"},
                    "max_chance": 100,
                    "encounter_details": [],
                }],
            }],
            pokemon_id=641,
            species_id=641,
            form_key="tornadus-incarnate",
            is_default_form=True,
        )
        self.assertEqual(roaming["black"][0]["areaSlug"], "unova-roaming-area")
        self.assertIn("roaming", roaming["black"][0]["conditions"])

        invalid = parse_obtain_locations_by_version(
            [{
                "location_area": {
                    "name": "new-mauville-area",
                    "url": "https://pokeapi.co/api/v2/location-area/388/",
                },
                "version_details": [{
                    "version": {"name": "sun"},
                    "max_chance": 100,
                    "encounter_details": [],
                }],
            }],
            pokemon_id=100,
            species_id=100,
            form_key="voltorb",
            is_default_form=True,
        )
        self.assertEqual(invalid, {})

    def test_species_encounters_keep_varieties_separate_in_same_area(self) -> None:
        class Builder:
            def _get_json_list(self, path: str):
                return [{
                    "location_area": {
                        "name": "route-1-area",
                        "url": "https://pokeapi.co/api/v2/location-area/1/",
                    },
                    "version_details": [{
                        "version": {"name": "sun"},
                        "max_chance": 20,
                        "encounter_details": [],
                    }],
                }]

        species = {
            "id": 19,
            "varieties": [
                {
                    "is_default": True,
                    "pokemon": {
                        "name": "rattata",
                        "url": "https://pokeapi.co/api/v2/pokemon/19/",
                    },
                },
                {
                    "is_default": False,
                    "pokemon": {
                        "name": "rattata-alola",
                        "url": "https://pokeapi.co/api/v2/pokemon/10091/",
                    },
                },
            ],
        }
        _by_game, by_version = fetch_species_obtain_locations(Builder(), species, 19)
        self.assertEqual(len(by_version["sun"]), 2)
        self.assertEqual(
            {entry["pokemonId"] for entry in by_version["sun"]},
            {19, 10091},
        )

    def test_species_only_overlay_is_explicitly_form_ambiguous(self) -> None:
        original = dex_builder._ENCOUNTER_OVERLAYS
        dex_builder._ENCOUNTER_OVERLAYS = {
            "scarlet": {
                "species:194": [{
                    "areaSlug": "south-province-area-one",
                    "areaLabelZh": "南第1区",
                    "pokemonId": 10253,
                    "formKey": "wooper-paldea",
                    "versions": ["scarlet"],
                }],
            },
        }
        try:
            _by_game, by_version = fetch_species_obtain_locations(
                type("Builder", (), {"_get_json_list": lambda _self, _path: []})(),
                {
                    "id": 194,
                    "varieties": [{
                        "is_default": True,
                        "pokemon": {
                            "name": "wooper",
                            "url": "https://pokeapi.co/api/v2/pokemon/194/",
                        },
                    }],
                },
                194,
            )
        finally:
            dex_builder._ENCOUNTER_OVERLAYS = original

        entry = by_version["scarlet"][0]
        self.assertEqual(entry["speciesId"], 194)
        self.assertTrue(entry["formAmbiguous"])
        self.assertNotIn("pokemonId", entry)
        self.assertNotIn("formKey", entry)

    def test_default_overlay_uses_authoritative_variety_key(self) -> None:
        original = dex_builder._ENCOUNTER_OVERLAYS
        dex_builder._ENCOUNTER_OVERLAYS = {
            "legends-za": {
                "648": [{
                    "speciesId": 648,
                    "pokemonId": 648,
                    "formIndex": 0,
                    "formKey": "meloetta",
                    "areaSlug": "pkhex-za-test",
                    "areaLabelZh": "密阿雷市",
                }],
            },
        }
        try:
            _by_game, by_version = fetch_obtain_locations(
                type("Builder", (), {"_get_json_list": lambda _self, _path: []})(),
                648,
                species_id=648,
                form_key="meloetta-aria",
                is_default_form=True,
            )
        finally:
            dex_builder._ENCOUNTER_OVERLAYS = original

        self.assertEqual(
            by_version["legends-za"][0]["formKey"],
            "meloetta-aria",
        )

    def test_form_builder_omits_single_default_and_keeps_all_cosmetics(self) -> None:
        builder = dex_builder.PokeApiBuilder(delay_s=0)
        builder.load_type_relations = lambda: {}
        single = {
            "id": 1,
            "name": "bulbasaur",
            "forms": [{
                "name": "bulbasaur",
                "url": "https://pokeapi.co/api/v2/pokemon-form/1/",
            }],
        }
        species = {
            "name": "bulbasaur",
            "varieties": [{
                "is_default": True,
                "pokemon": {
                    "name": "bulbasaur",
                    "url": "https://pokeapi.co/api/v2/pokemon/1/",
                },
            }],
        }
        forms, terms, ambiguous_ids = builder.build_forms(
            species_id=1,
            species=species,
            default_pokemon=single,
            species_name_zh="妙蛙种子",
            cdn_base="https://example.invalid",
            default_move_sets={},
            default_abilities=[],
            obtain_locations_by_game={},
            obtain_locations_by_version={},
        )
        self.assertEqual(forms, [])
        self.assertEqual(terms, [])
        self.assertEqual(ambiguous_ids, set())

        alcremie = {
            "id": 869,
            "name": "alcremie",
            "types": [{"slot": 1, "type": {"name": "fairy"}}],
            "stats": [{"stat": {"name": "hp"}, "base_stat": 65}],
            "abilities": [],
            "moves": [],
            "height": 3,
            "weight": 5,
            "sprites": {"front_default": "https://example.invalid/base.png"},
            "forms": [
                {
                    "name": "alcremie-vanilla-cream-strawberry-sweet",
                    "url": "https://pokeapi.co/api/v2/pokemon-form/10168/",
                },
                {
                    "name": "alcremie-ruby-cream-strawberry-sweet",
                    "url": "https://pokeapi.co/api/v2/pokemon-form/10169/",
                },
            ],
        }
        form_payloads = {
            ref["url"]: {
                "id": 10168 + index,
                "name": ref["name"],
                "is_default": index == 0,
                "is_battle_only": False,
                "is_mega": False,
                "types": alcremie["types"],
                "sprites": {
                    "front_default": f"https://example.invalid/{index}.png"
                },
                "version_group": {"name": "sword-shield"},
            }
            for index, ref in enumerate(alcremie["forms"])
        }
        builder._get_json = lambda path: form_payloads[path]
        encounter = {
            "areaSlug": "route-1-area",
            "areaLabelZh": "1号道路",
            "pokemonId": 869,
            "speciesId": 869,
            "formKey": "alcremie",
            "formAmbiguous": False,
        }
        forms, _terms, ambiguous_ids = builder.build_forms(
            species_id=869,
            species={
                "name": "alcremie",
                "varieties": [{
                    "is_default": True,
                    "pokemon": {
                        "name": "alcremie",
                        "url": "https://pokeapi.co/api/v2/pokemon/869/",
                    },
                }],
            },
            default_pokemon=alcremie,
            species_name_zh="霜奶仙",
            cdn_base="https://example.invalid",
            default_move_sets={},
            default_abilities=[],
            obtain_locations_by_game={"sword-shield": [encounter]},
            obtain_locations_by_version={"sword": [encounter]},
        )
        self.assertEqual(len(forms), 2)
        self.assertEqual({form["formId"] for form in forms}, {10168, 10169})
        self.assertEqual(len({form["key"] for form in forms}), 2)
        self.assertEqual(set(builder.form_sprite_jobs), set())
        self.assertEqual(
            {form["localSpritePath"] for form in forms},
            {"sprites/869.png"},
        )
        self.assertEqual(ambiguous_ids, {869})
        for form in forms:
            location = form["obtainLocationsByVersion"]["sword"][0]
            self.assertTrue(location["formAmbiguous"])
            self.assertNotIn("formKey", location)

    def test_resume_hydrates_move_and_ability_caches(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            staging = Path(temp)
            (staging / "moves.json").write_text(
                json.dumps({"33": {"id": 33, "nameEn": "Tackle"}}),
                encoding="utf-8",
            )
            (staging / "abilities.json").write_text(
                json.dumps({
                    "65": {
                        "nameEn": "Overgrow",
                        "nameZh": "茂盛",
                        "descriptionZh": "",
                        "pokemonIds": [1],
                    },
                }),
                encoding="utf-8",
            )
            builder = dex_builder.PokeApiBuilder(delay_s=0)
            dex_builder.hydrate_builder_indexes_from_staging(builder, staging)
            self.assertIn(33, builder.move_cache)
            self.assertIn(65, builder.ability_index)
            self.assertIn(("overgrow", False), builder.ability_cache)
            self.assertIn(("overgrow", True), builder.ability_cache)

    def test_sample_detail_json_has_v5_fields(self) -> None:
        bundle_dir = REPO_ROOT / "dist" / "dex-v5-smoke" / "upload" / BUNDLE_CDN_PREFIX
        detail_path = bundle_dir / "details" / "1.json"
        if not detail_path.exists():
            self.skipTest(f"Smoke build not found at {detail_path}")

        detail = json.loads(detail_path.read_text(encoding="utf-8"))
        for key in (
            "abilities",
            "obtainLocations",
            "obtainLocationsByGame",
            "obtainLocationsByVersion",
            "moveSets",
            "baseHappiness",
            "captureRate",
            "evYield",
        ):
            self.assertIn(key, detail, f"missing {key}")

        self.assertIsInstance(detail["abilities"], list)
        self.assertIsInstance(detail["obtainLocations"], list)
        self.assertIsInstance(detail["obtainLocationsByGame"], dict)
        self.assertIsInstance(detail["obtainLocationsByVersion"], dict)
        self.assertIn("heartgold-soulsilver", detail["obtainLocationsByGame"])

        if detail["abilities"]:
            ability = detail["abilities"][0]
            for key in ("nameEn", "nameZh", "descriptionZh", "isHidden"):
                self.assertIn(key, ability)

        if detail["flavorEntries"]:
            flavor = detail["flavorEntries"][0]
            for key in (
                "gameEdition",
                "versionGroup",
                "version",
                "labelZh",
                "iconUrl",
                "text",
            ):
                self.assertIn(key, flavor, f"flavor missing {key}")

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

        games = json.loads((bundle_dir / "games.json").read_text(encoding="utf-8"))
        self.assertEqual(len(games), 23)
        self.assertIn("slug", games[0])
        self.assertIn("iconUrl", games[0])

        natures = json.loads((bundle_dir / "natures.json").read_text(encoding="utf-8"))
        self.assertEqual(len(natures), 25)

        egg_groups = json.loads(
            (bundle_dir / "egg_groups.json").read_text(encoding="utf-8")
        )
        self.assertEqual(len(egg_groups), 15)

        for index_name in (
            "status_conditions.json",
            "weather.json",
            "terrains.json",
            "items.json",
        ):
            payload = json.loads((bundle_dir / index_name).read_text(encoding="utf-8"))
            self.assertTrue(payload, index_name)

        manifest = json.loads(
            (REPO_ROOT / "dist" / "dex-v5-smoke" / "upload" / "bundle-manifest.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(manifest["bundleVersion"], BUNDLE_VERSION)
        self.assertEqual(manifest["schemaFeatures"]["pokemonForms"], 2)
        self.assertEqual(manifest["schemaFeatures"]["encounterFormIdentity"], 3)
        self.assertIn(f"/{BUNDLE_CDN_PREFIX}/bundle.tar.zst", manifest["archiveUrl"])


def validate_detail_dir(details_dir: Path) -> list[str]:
    errors: list[str] = []
    if details_dir.is_file():
        detail_files = [details_dir]
    else:
        detail_files = sorted(details_dir.glob("*.json"))
    for detail_file in detail_files:
        detail = json.loads(detail_file.read_text(encoding="utf-8"))
        for key in ("abilities", "obtainLocations", "obtainLocationsByGame"):
            if key not in detail:
                errors.append(f"{detail_file.name}: missing {key}")
        for key in ("baseHappiness", "captureRate", "evYield"):
            if key not in detail:
                errors.append(f"{detail_file.name}: missing {key}")
        if detail.get("flavorEntries"):
            flavor = detail["flavorEntries"][0]
            if "gameEdition" not in flavor:
                errors.append(f"{detail_file.name}: flavorEntries missing gameEdition")
        for form in detail.get("forms", []):
            for key in (
                "key",
                "pokemonId",
                "nameZh",
                "kind",
                "isDefault",
                "types",
                "heightDm",
                "weightHg",
            ):
                if key not in form:
                    errors.append(
                        f"{detail_file.name}: form missing {key}"
                    )
            if not form.get("isCosmetic") and not form.get("isDefault"):
                # Battle-relevant forms must carry their own profile. An empty
                # profile is preferable to silently borrowing the species one,
                # but a completed production bundle should not leave it empty.
                if not form.get("types"):
                    errors.append(
                        f"{detail_file.name}: battle form has no types"
                    )
    return errors


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        target = (
            Path(sys.argv[2])
            if len(sys.argv) > 2
            else REPO_ROOT / "dist" / "dex-v5-smoke" / "upload" / BUNDLE_CDN_PREFIX / "details"
        )
        errors = validate_detail_dir(target)
        if errors:
            print("\n".join(errors), file=sys.stderr)
            sys.exit(1)
        print(f"OK: {target}")
        sys.exit(0)
    unittest.main()
