#!/usr/bin/env python3
"""Generate normalized GPL-3.0 modern-game encounter overlays from PKHeX."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import tempfile
import unicodedata
import urllib.request
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PINNED_COMMIT = "5c9e949c9f0fa932a1b63511b32c2bee5ce75b4e"
POKEAPI = "https://pokeapi.co/api/v2"
DEFAULT_OUTPUT = ROOT / "data" / "encounters" / "pkhex"


def slugify(value: str) -> str:
    value = value.lower().replace("♀", "-f").replace("♂", "-m")
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", value)).strip("-")


def clean_location_label(value: str) -> str:
    return re.sub(r"\s*\(\d{5}\)$", "", value).strip()


def run_exporter(pkhex_root: Path, raw_path: Path) -> None:
    revision = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=pkhex_root, text=True
    ).strip()
    if revision != PINNED_COMMIT:
        raise RuntimeError(f"PKHeX must be checked out at {PINNED_COMMIT}, got {revision}")
    cli_home = Path(tempfile.gettempdir()) / "titodex-dotnet"
    cli_home.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "dotnet",
            "run",
            "--project",
            str(ROOT / "tools" / "pkhex_encounters" / "Exporter.csproj"),
            f"-p:PKHeXRoot={pkhex_root}",
            "--",
            str(raw_path),
        ],
        check=True,
        env={**__import__("os").environ, "DOTNET_CLI_HOME": str(cli_home)},
    )


class PokeApiFormMapper:
    def __init__(self, cache_dir: Path, *, offline: bool = False) -> None:
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.offline = offline
        mapping_path = ROOT / "data" / "forms" / "pkhex_encounter_mappings.json"
        self.verified = json.loads(mapping_path.read_text(encoding="utf-8"))
        self.species_names = {} if offline else self._load_species_names()

    def _json(self, url: str, cache_name: str) -> dict[str, Any]:
        path = self.cache_dir / cache_name
        if path.is_file():
            return json.loads(path.read_text(encoding="utf-8"))
        request = urllib.request.Request(
            url,
            headers={"User-Agent": "TitoDex-PKHeX-overlay-generator/1.0"},
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.loads(response.read().decode("utf-8"))
        path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        return payload

    def _load_species_names(self) -> dict[int, str]:
        payload = self._json(
            f"{POKEAPI}/pokemon-species?limit=1025", "species-list.json"
        )
        result: dict[int, str] = {}
        for item in payload["results"]:
            species_id = int(item["url"].rstrip("/").split("/")[-1])
            if species_id <= 1025:
                result[species_id] = item["name"]
        return result

    def map(
        self, species_id: int, species_name: str, form_index: int, form_name: str
    ) -> tuple[int | None, str | None]:
        species_slug = self.species_names.get(species_id) or slugify(species_name)
        form_name_slug = slugify(form_name)
        verified = self.verified.get(
            f"{species_id}:{form_name_slug or 'default'}"
        )
        if verified:
            return int(verified["pokemonId"]), str(verified["formKey"])
        if form_index == 0:
            return species_id, species_slug
        if self.offline:
            return None, None
        species = self._json(
            f"{POKEAPI}/pokemon-species/{species_id}", f"species-{species_id}.json"
        )
        varieties = species.get("varieties") or []

        candidates: list[tuple[int, str]] = []
        for variety in varieties:
            pokemon_ref = variety["pokemon"]
            pokemon_id = int(pokemon_ref["url"].rstrip("/").split("/")[-1])
            pokemon = self._json(
                f"{POKEAPI}/pokemon/{pokemon_id}", f"pokemon-{pokemon_id}.json"
            )
            for form_ref in pokemon.get("forms") or []:
                candidates.append((pokemon_id, str(form_ref["name"])))
            candidates.append((pokemon_id, str(pokemon_ref["name"])))

        target = set(slugify(form_name).split("-")) - {"form", "forme", "breed"}
        if not target:
            return None, None
        species_tokens = set(species_slug.split("-"))
        ranked: list[tuple[int, int, str]] = []
        for pokemon_id, key in set(candidates):
            key_tokens = set(key.split("-")) - species_tokens - {"form", "forme", "breed"}
            if target <= key_tokens or key_tokens <= target:
                ranked.append((len(target ^ key_tokens), pokemon_id, key))
        if not ranked:
            return None, None
        ranked.sort()
        best_score = ranked[0][0]
        best = {(pokemon_id, key) for score, pokemon_id, key in ranked if score == best_score}
        return next(iter(best)) if len(best) == 1 else (None, None)


def exact_versions(row: dict[str, Any]) -> list[str]:
    versions = row["versionHint"].split("+")
    location = int(row["location"])
    result: list[str] = []
    for version in versions:
        if version in {"sword", "shield"}:
            if 164 <= location <= 199:
                version = f"the-isle-of-armor-{version}"
            elif 200 <= location <= 255:
                version = f"the-crown-tundra-{version}"
        elif version in {"scarlet", "violet"}:
            if row["sourceField"] == "TeraDLC1" or 132 <= location <= 177:
                version = f"the-teal-mask-{version}"
            elif row["sourceField"] == "TeraDLC2" or 178 <= location <= 255:
                version = f"the-indigo-disk-{version}"
        result.append(version)
    return sorted(set(result))


def location_identity(row: dict[str, Any]) -> tuple[str, str]:
    if row["method"] == "raid" and row["sourceField"].startswith("Nest"):
        return "max-raid-den", "极巨团体战巢穴"
    if row["method"] == "raid" and row["sourceField"].startswith("Tera"):
        suffix = {
            "TeraBase": ("paldea", "帕底亚太晶结晶"),
            "TeraDLC1": ("kitakami", "北上乡太晶结晶"),
            "TeraDLC2": ("blueberry", "蓝莓学园太晶结晶"),
        }[row["sourceField"]]
        return f"tera-raid-{suffix[0]}", suffix[1]
    label_en = clean_location_label(row.get("areaNameEn") or "")
    label_zh = clean_location_label(row.get("areaLabelZh") or "")
    family = "za" if row["versionHint"] in {"legends-za", "mega-dimension"} else "modern"
    return (
        f"pkhex-{family}-{int(row['location']):05d}-{slugify(label_en) or 'location'}",
        label_zh or label_en or f"地点 {row['location']}",
    )


def aggregate(raw_rows: list[dict[str, Any]], mapper: PokeApiFormMapper) -> dict[str, dict[str, list[dict[str, Any]]]]:
    mappings: dict[tuple[int, int, str], tuple[int | None, str | None]] = {}
    grouped: dict[str, dict[tuple[Any, ...], dict[str, Any]]] = defaultdict(dict)
    for raw in raw_rows:
        species_id = int(raw["species"])
        form_index = int(raw["form"])
        form_name = str(raw.get("formNameEn") or "")
        map_key = (species_id, form_index, form_name)
        if map_key not in mappings:
            mappings[map_key] = mapper.map(
                species_id,
                str(raw.get("speciesNameEn") or species_id),
                form_index,
                form_name,
            )
        pokemon_id, form_key = mappings[map_key]
        area_slug, area_label = location_identity(raw)
        for version in exact_versions(raw):
            identity = (
                species_id,
                pokemon_id,
                form_key,
                area_slug,
                raw["method"],
                raw.get("teraType"),
                bool(raw.get("isAlpha")),
                bool(raw.get("isTitan")),
            )
            entry = grouped[version].get(identity)
            if entry is None:
                entry = {
                    "speciesId": species_id,
                    "formIndex": form_index,
                    "areaSlug": area_slug,
                    "areaLabelZh": area_label,
                    "minLevel": int(raw.get("levelMin") or 0),
                    "maxLevel": int(raw.get("levelMax") or 0),
                    "maxChance": 0,
                    "rateKind": "weight" if raw.get("rateValue") else "unknown",
                    "rateValue": int(raw.get("rateValue") or 0),
                    "methods": [raw["method"]],
                    "conditions": [],
                    "isAlpha": bool(raw.get("isAlpha")),
                    "isTitan": bool(raw.get("isTitan")),
                    "isRaid": raw["method"] == "raid",
                    "isFixedEncounter": raw["method"] == "fixed",
                    "formAmbiguous": pokemon_id is None or form_key is None,
                }
                if pokemon_id is not None and form_key is not None:
                    entry["pokemonId"] = pokemon_id
                    entry["formKey"] = form_key
                    entry["isDefaultForm"] = form_index == 0
                if raw.get("teraType"):
                    entry["teraType"] = raw["teraType"]
                grouped[version][identity] = entry
            else:
                levels_min = [v for v in (entry["minLevel"], int(raw.get("levelMin") or 0)) if v > 0]
                entry["minLevel"] = min(levels_min) if levels_min else 0
                entry["maxLevel"] = max(entry["maxLevel"], int(raw.get("levelMax") or 0))
                entry["rateValue"] = max(entry["rateValue"], int(raw.get("rateValue") or 0))

    result: dict[str, dict[str, list[dict[str, Any]]]] = {}
    for version, entries in grouped.items():
        buckets: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for entry in entries.values():
            key = str(entry.get("pokemonId") or f"species:{entry['speciesId']}")
            buckets[key].append(entry)
        result[version] = {
            key: sorted(value, key=lambda item: (item["areaLabelZh"], item["methods"]))
            for key, value in sorted(buckets.items())
        }
    return result


def write_overlays(overlays: dict[str, dict[str, list[dict[str, Any]]]], output: Path) -> None:
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    source = {
        "name": "PKHeX encounter data (normalized)",
        "url": f"https://github.com/kwsch/PKHeX/commit/{PINNED_COMMIT}",
        "commit": PINNED_COMMIT,
        "license": "GPL-3.0-or-later",
    }
    for version, encounters in sorted(overlays.items()):
        payload = {
            "schemaVersion": 4,
            "priority": 100,
            "version": version,
            "source": source,
            "encounters": encounters,
        }
        (output / f"{version}.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pkhex-root", type=Path, required=True)
    parser.add_argument(
        "--raw",
        type=Path,
        default=Path(tempfile.gettempdir()) / "titodex-pkhex-raw.json",
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--cache",
        type=Path,
        default=Path(tempfile.gettempdir()) / "titodex-pokeapi-cache",
    )
    parser.add_argument("--reuse-raw", action="store_true")
    parser.add_argument(
        "--offline",
        action="store_true",
        help="Use only pinned PKHeX names plus committed verified mappings; unknown forms stay ambiguous.",
    )
    args = parser.parse_args()
    if not args.reuse_raw or not args.raw.is_file():
        run_exporter(args.pkhex_root, args.raw)
    raw = json.loads(args.raw.read_text(encoding="utf-8"))
    if raw.get("sourceCommit") != PINNED_COMMIT:
        raise RuntimeError("raw export does not match pinned PKHeX commit")
    overlays = aggregate(raw["rows"], PokeApiFormMapper(args.cache, offline=args.offline))
    write_overlays(overlays, args.output)
    print(f"wrote {len(overlays)} exact-version overlays to {args.output}")


if __name__ == "__main__":
    main()
