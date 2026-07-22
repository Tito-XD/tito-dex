#!/usr/bin/env python3
"""Audit PokeAPI encounter foreign keys against TitoDex location l10n data."""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG = ROOT / "data" / "l10n" / "zh" / "location_areas.json"

EXPECTED_REGIONS_BY_VERSION_GROUP: dict[str, set[str]] = {
    "red-blue": {"kanto"},
    "yellow": {"kanto"},
    "gold-silver": {"johto", "kanto"},
    "crystal": {"johto", "kanto"},
    "ruby-sapphire": {"hoenn"},
    "emerald": {"hoenn", "kanto"},
    "firered-leafgreen": {"kanto"},
    "diamond-pearl": {"sinnoh"},
    "platinum": {"sinnoh"},
    "heartgold-soulsilver": {"johto", "kanto"},
    "black-white": {"unova"},
    "black-2-white-2": {"unova"},
    "x-y": {"kalos"},
    "omega-ruby-alpha-sapphire": {"hoenn"},
    "sun-moon": {"alola"},
    "ultra-sun-ultra-moon": {"alola"},
    "lets-go-pikachu-lets-go-eevee": {"kanto"},
    "sword-shield": {"galar"},
    "the-isle-of-armor": {"galar"},
    "the-crown-tundra": {"galar"},
}

# PokeAPI's location table contains duplicate generic names across regions.
# These area IDs are semantically tied to the overridden region in encounter data.
REGION_OVERRIDES_BY_AREA_ID = {1194: "alola"}
CSV_SLUG_ALIASES_BY_AREA_ID = {1072: "berry-fields-area"}


def csv_path(csv_dir: Path, name: str) -> Path:
    direct = csv_dir / f"{name}.csv"
    prefixed = csv_dir / f"pokeapi-{name}.csv"
    if direct.is_file():
        return direct
    if prefixed.is_file():
        return prefixed
    raise ValueError(f"missing {name}.csv in {csv_dir}")


def rows(csv_dir: Path, name: str) -> list[dict[str, str]]:
    with csv_path(csv_dir, name).open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def int_or_none(value: str | None) -> int | None:
    return int(value) if value else None


def audit(csv_dir: Path, catalog_path: Path) -> dict[str, Any]:
    areas = {int(row["id"]): row for row in rows(csv_dir, "location_areas")}
    locations = {int(row["id"]): row for row in rows(csv_dir, "locations")}
    regions = {int(row["id"]): row["identifier"] for row in rows(csv_dir, "regions")}
    versions = {int(row["id"]): row for row in rows(csv_dir, "versions")}
    version_groups = {
        int(row["id"]): row for row in rows(csv_dir, "version_groups")
    }
    pokemon = {int(row["id"]): row for row in rows(csv_dir, "pokemon")}
    encounters = rows(csv_dir, "encounters")
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    catalog_by_id = {
        int(entry["id"]): (slug, entry)
        for slug, entry in catalog.items()
        if isinstance(entry, dict) and entry.get("id")
    }

    missing_area_ids: set[int] = set()
    missing_version_ids: set[int] = set()
    missing_pokemon_ids: set[int] = set()
    catalog_missing_ids: set[int] = set()
    catalog_slug_mismatches: list[dict[str, Any]] = []
    referenced_area_ids: set[int] = set()
    referenced_pokemon_ids: set[int] = set()
    rows_by_version: Counter[str] = Counter()
    rows_by_version_group: Counter[str] = Counter()
    rows_by_region: Counter[str] = Counter()
    regions_by_version_group: dict[str, set[str]] = defaultdict(set)
    areas_by_version_group_region: dict[tuple[str, str], set[str]] = defaultdict(set)

    def official_area_slug(area: dict[str, str]) -> str:
        location = locations.get(int(area["location_id"]))
        location_slug = location["identifier"] if location else f"location-{area['location_id']}"
        area_slug = area.get("identifier") or "area"
        return f"{location_slug}-{area_slug}"

    for encounter in encounters:
        area_id = int(encounter["location_area_id"])
        version_id = int(encounter["version_id"])
        pokemon_id = int(encounter["pokemon_id"])
        referenced_area_ids.add(area_id)
        referenced_pokemon_ids.add(pokemon_id)

        area = areas.get(area_id)
        version = versions.get(version_id)
        if area is None:
            missing_area_ids.add(area_id)
        if version is None:
            missing_version_ids.add(version_id)
        if pokemon_id not in pokemon:
            missing_pokemon_ids.add(pokemon_id)
        if area_id not in catalog_by_id:
            catalog_missing_ids.add(area_id)

        version_name = version["identifier"] if version else f"#{version_id}"
        rows_by_version[version_name] += 1
        version_group_name = "unknown"
        if version:
            group = version_groups.get(int(version["version_group_id"]))
            if group:
                version_group_name = group["identifier"]
        rows_by_version_group[version_group_name] += 1

        region_name = REGION_OVERRIDES_BY_AREA_ID.get(area_id, "unassigned")
        if area:
            location = locations.get(int(area["location_id"]))
            region_id = int_or_none(location.get("region_id") if location else None)
            if region_id is not None and area_id not in REGION_OVERRIDES_BY_AREA_ID:
                region_name = regions.get(region_id, f"#{region_id}")
        rows_by_region[region_name] += 1
        regions_by_version_group[version_group_name].add(region_name)
        if area:
            areas_by_version_group_region[(version_group_name, region_name)].add(
                official_area_slug(area)
            )

    for area_id in sorted(referenced_area_ids & catalog_by_id.keys()):
        official_slug = CSV_SLUG_ALIASES_BY_AREA_ID.get(
            area_id, official_area_slug(areas[area_id])
        )
        catalog_slug = catalog_by_id[area_id][0]
        if official_slug != catalog_slug:
            catalog_slug_mismatches.append(
                {
                    "id": area_id,
                    "officialSlug": official_slug,
                    "catalogSlug": catalog_slug,
                }
            )

    unexpected_regions: dict[str, list[str]] = {}
    unexpected_region_areas: dict[str, dict[str, list[str]]] = {}
    for group, actual_regions in sorted(regions_by_version_group.items()):
        expected = EXPECTED_REGIONS_BY_VERSION_GROUP.get(group)
        if expected is None:
            continue
        unexpected = actual_regions - expected - {"unassigned"}
        if unexpected:
            unexpected_regions[group] = sorted(unexpected)
            unexpected_region_areas[group] = {
                region: sorted(areas_by_version_group_region[(group, region)])
                for region in sorted(unexpected)
            }

    non_default_pokemon_ids = {
        pokemon_id
        for pokemon_id in referenced_pokemon_ids
        if pokemon_id in pokemon and pokemon[pokemon_id].get("is_default") == "0"
    }
    return {
        "encounterRowCount": len(encounters),
        "referencedAreaCount": len(referenced_area_ids),
        "referencedPokemonCount": len(referenced_pokemon_ids),
        "referencedNonDefaultPokemonCount": len(non_default_pokemon_ids),
        "missingLocationAreaIds": sorted(missing_area_ids),
        "missingVersionIds": sorted(missing_version_ids),
        "missingPokemonIds": sorted(missing_pokemon_ids),
        "catalogMissingAreaIds": sorted(catalog_missing_ids),
        "catalogSlugMismatches": catalog_slug_mismatches,
        "rowsByVersion": dict(sorted(rows_by_version.items())),
        "rowsByVersionGroup": dict(sorted(rows_by_version_group.items())),
        "rowsByRegion": dict(sorted(rows_by_region.items())),
        "regionsByVersionGroup": {
            group: sorted(region_names)
            for group, region_names in sorted(regions_by_version_group.items())
        },
        "unexpectedRegionsByVersionGroup": unexpected_regions,
        "unexpectedRegionAreasByVersionGroup": unexpected_region_areas,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv_dir", type=Path, help="PokeAPI data/v2/csv directory")
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()
    report = audit(args.csv_dir, args.catalog)
    if args.as_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        for key in (
            "encounterRowCount",
            "referencedAreaCount",
            "referencedPokemonCount",
            "referencedNonDefaultPokemonCount",
            "missingLocationAreaIds",
            "missingVersionIds",
            "missingPokemonIds",
            "catalogMissingAreaIds",
            "catalogSlugMismatches",
            "unexpectedRegionsByVersionGroup",
            "unexpectedRegionAreasByVersionGroup",
        ):
            print(f"{key}: {report[key]}")
        print("regionsByVersionGroup:")
        for group, region_names in report["regionsByVersionGroup"].items():
            print(f"  {group}: {', '.join(region_names)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
