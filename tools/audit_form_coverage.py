#!/usr/bin/env python3
"""Audit TitoDex form coverage, identity safety, and nested bundle assets."""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import requests

FORM_KINDS = {"regional", "mega", "gigantamax", "battle", "form", "cosmetic"}
DEFAULT_OVERRIDES = Path(__file__).resolve().parents[1] / "data/forms/overrides.json"


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def form_keys(bundle_dir: Path) -> set[str]:
    keys: set[str] = set()
    for path in (bundle_dir / "details").glob("*.json"):
        detail = load_json(path)
        keys.update(str(form.get("key")) for form in detail.get("forms") or [])
    return keys


def fetch_pokeapi_counts() -> dict[str, int]:
    counts: dict[str, int] = {}
    for resource in ("pokemon-species", "pokemon", "pokemon-form"):
        response = requests.get(
            f"https://pokeapi.co/api/v2/{resource}?limit=1", timeout=30
        )
        response.raise_for_status()
        counts[resource] = int(response.json()["count"])
    return counts


def audit(
    bundle_dir: Path,
    previous_bundle: Path | None = None,
    overrides_path: Path = DEFAULT_OVERRIDES,
    pokeapi_counts: dict[str, int] | None = None,
) -> dict[str, Any]:
    details_dir = bundle_dir / "details"
    if not details_dir.is_dir():
        raise ValueError(f"expected extracted bundle root with details/: {bundle_dir}")

    kind_counts: Counter[str] = Counter()
    pokemon_ids: defaultdict[int, list[str]] = defaultdict(list)
    form_ids: defaultdict[int, list[str]] = defaultdict(list)
    keys: defaultdict[str, list[int]] = defaultdict(list)
    missing: defaultdict[str, list[str]] = defaultdict(list)
    invalid_defaults: list[int] = []
    single_form_species: list[int] = []
    inheritance_errors: list[str] = []
    unclassified: list[str] = []
    missing_assets: list[str] = []
    species_ids: set[int] = set()
    encounter = Counter()

    for detail_path in sorted(details_dir.glob("*.json")):
        detail = load_json(detail_path)
        species_id = int(detail.get("summary", {}).get("id") or detail_path.stem)
        species_ids.add(species_id)
        forms = detail.get("forms") or []
        if len(forms) == 1:
            single_form_species.append(species_id)
        if forms and sum(bool(form.get("isDefault")) for form in forms) != 1:
            invalid_defaults.append(species_id)

        for form in forms:
            key = str(form.get("key") or "")
            kind = str(form.get("kind") or "")
            keys[key].append(species_id)
            kind_counts[kind] += 1
            if form.get("pokemonId") is not None:
                pokemon_ids[int(form["pokemonId"])].append(key)
            if form.get("formId") is not None:
                form_ids[int(form["formId"])].append(key)
            if kind not in FORM_KINDS:
                unclassified.append(key)

            battle_related = not form.get("isDefault") and kind != "cosmetic"
            if battle_related and not form.get("types"):
                missing["battleTypes"].append(key)
            if battle_related and form.get("inheritsFromDefault"):
                inheritance_errors.append(key)
            for field in ("nameZh", "dataCompleteness", "sources"):
                if not form.get(field):
                    missing[field].append(key)
            if battle_related and not form.get("baseStats"):
                missing["battleBaseStats"].append(key)
            if not form.get("availableVersionGroups"):
                missing["availableVersionGroups"].append(key)

            local_sprite = form.get("localSpritePath")
            if local_sprite and not (bundle_dir / local_sprite).is_file():
                missing_assets.append(str(local_sprite))
            if local_sprite and local_sprite.startswith("sprites/forms/"):
                artwork = Path("artwork/forms") / Path(local_sprite).name
                if (bundle_dir / "artwork").is_dir() and not (
                    bundle_dir / artwork
                ).is_file():
                    missing_assets.append(str(artwork))

        encounter_maps = detail.get("obtainLocationsByVersion") or detail.get(
            "obtainLocationsByGame"
        ) or {}
        for entries in encounter_maps.values():
            for entry in entries:
                pokemon_id = entry.get("pokemonId")
                form_key = entry.get("formKey") or entry.get("formSlug")
                ambiguous = bool(entry.get("formAmbiguous")) or (
                    pokemon_id is None and not form_key
                )
                encounter["total"] += 1
                if ambiguous:
                    encounter["formAmbiguous"] += 1
                elif pokemon_id is not None and form_key:
                    encounter["formLinked"] += 1
                else:
                    encounter["identityMismatch"] += 1
                if entry.get("teraType"):
                    encounter["teraType"] += 1

    duplicate_keys = {key: ids for key, ids in keys.items() if len(ids) > 1}
    duplicate_form_ids = {
        str(form_id): values
        for form_id, values in form_ids.items()
        if len(values) > 1
    }
    duplicate_pokemon_ids = {
        str(pokemon_id): values
        for pokemon_id, values in pokemon_ids.items()
        if len(values) > 1
    }
    errors = {
        "singleFormSpecies": single_form_species,
        "invalidDefaultSpecies": invalid_defaults,
        "duplicateFormKeys": duplicate_keys,
        "duplicateFormIds": duplicate_form_ids,
        "inheritanceErrors": inheritance_errors,
        "unclassifiedForms": unclassified,
        "missingBattleTypes": missing["battleTypes"],
        "missingSources": missing["sources"],
        "missingAssets": sorted(set(missing_assets)),
        "encounterIdentityMismatchCount": encounter["identityMismatch"],
    }
    changes: dict[str, list[str]] = {}
    if previous_bundle is not None:
        previous = form_keys(previous_bundle)
        current = set(keys)
        changes = {
            "added": sorted(current - previous),
            "removed": sorted(previous - current),
        }
    overrides = load_json(overrides_path) if overrides_path.is_file() else {}

    return {
        "bundleSpeciesCount": len(species_ids),
        "bundlePokemonEntityCount": len(species_ids | set(pokemon_ids)),
        "bundlePokemonFormCount": sum(kind_counts.values()),
        "pokeApiCounts": pokeapi_counts or {},
        "kindCounts": dict(sorted(kind_counts.items())),
        "missing": {key: sorted(values) for key, values in sorted(missing.items())},
        "duplicatePokemonIds": duplicate_pokemon_ids,
        "encounter": dict(sorted(encounter.items())),
        "changes": changes,
        "pendingOverlayForms": sorted(overrides.get("pendingForms") or []),
        "errors": errors,
        "ok": not any(bool(value) for value in errors.values()),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", type=Path)
    parser.add_argument("--previous", type=Path)
    parser.add_argument("--overrides", type=Path, default=DEFAULT_OVERRIDES)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument(
        "--pokeapi",
        action="store_true",
        help="Also query current PokeAPI species/Pokémon/form counts",
    )
    args = parser.parse_args()
    report = audit(
        args.bundle_dir,
        args.previous,
        args.overrides,
        fetch_pokeapi_counts() if args.pokeapi else None,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if args.strict and not report["ok"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
