#!/usr/bin/env python3
"""Build version-scoped v20 gameplay sidecars without changing manifests.

The input is a v20 reference candidate produced by
``patch_dex_bundle_v20_reference.py``.  The tool verifies the same pinned
PokéAPI/api-data checkout, consumes the repository-pinned PKHeX overlays and
reviewed progression requirements, and writes only ``staging/gameplay/*.json``.
Unknown gift/trade/transfer facts remain explicit unknowns.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from build_dex_v20_gameplay_shards import write_species_shards
from patch_dex_bundle_v20_reference import (
    DEFAULT_OUTPUT,
    SOURCE_LOCK,
    fetch_source_checkout,
    read_json,
    ref_id,
    ref_name,
    write_json,
)


ROOT = Path(__file__).resolve().parents[1]
VERSION_KEYS = ROOT / "data" / "dex" / "game_version_keys_v20.json"
GAMEPLAY_SOURCE_LOCK = ROOT / "data" / "dex" / "gameplay_v20_sources.json"
PROGRESSION_HINTS = ROOT / "data" / "journey" / "progression_hints.json"
OVERLAY_ROOT = ROOT / "data" / "encounters"
PKHEX_NOTICE = OVERLAY_ROOT / "PKHEX_LICENSE.md"


def ensure_api_subtrees(api_root: Path) -> None:
    required = (
        api_root / "data" / "api" / "v2" / "pokemon" / "1" / "index.json",
        api_root / "data" / "api" / "v2" / "pokemon" / "1" / "encounters" / "index.json",
    )
    if all(path.is_file() for path in required):
        return
    if not (api_root / ".git").is_dir():
        raise FileNotFoundError("Pinned api-data checkout lacks the pokemon subtree")
    subprocess.run(
        ["git", "sparse-checkout", "add", "/data/api/v2/pokemon/"],
        cwd=api_root,
        check=True,
    )
    if not all(path.is_file() for path in required):
        raise FileNotFoundError("Unable to materialize pinned api-data pokemon subtree")


class VersionKeys:
    def __init__(self, payload: dict[str, Any]) -> None:
        self.groups = {row["key"]: row for row in payload["canonicalGroups"]}
        if len(self.groups) != len(payload["canonicalGroups"]):
            raise ValueError("Duplicate canonical version group")
        self.aliases = dict(payload.get("aliases") or {})
        self.exact_to_group: dict[str, str] = {}
        for group, row in self.groups.items():
            self.aliases.setdefault(group, group)
            for version in row["exactVersions"]:
                if version in self.exact_to_group:
                    raise ValueError(f"Duplicate exact version key: {version}")
                self.exact_to_group[version] = group
        for alias, target in self.aliases.items():
            if target not in self.groups and target not in self.exact_to_group:
                raise ValueError(f"Alias {alias!r} has unknown target {target!r}")

    def normalize(self, key: str) -> str:
        return self.aliases.get(key, key)

    def group_for(self, exact_or_group: str) -> str | None:
        key = self.normalize(exact_or_group)
        if key in self.groups:
            return key
        return self.exact_to_group.get(key)


def load_overlay_encounters(
    keys: VersionKeys,
    expected_source: dict[str, Any] | None = None,
) -> dict[str, dict[tuple[int, str, str], dict[str, Any]]]:
    """Index only species/area/mode identities actually present in an overlay.

    Merely having an overlay for a version must not bless every encounter row
    in the v19 detail object.  The identity-level index keeps provenance exact
    and lets the pinned PokéAPI fallback verify remaining rows independently.
    """

    indexed: dict[str, dict[tuple[int, str, str], dict[str, Any]]] = defaultdict(
        dict
    )
    priorities: dict[str, dict[tuple[int, str, str], int]] = defaultdict(dict)
    # Only the repository-pinned PKHeX overlays are allowed here.  Older
    # hand-maintained encounter files without a source commit are deliberately
    # excluded and can still be verified independently by the pinned API data.
    for path in sorted((OVERLAY_ROOT / "pkhex").glob("*.json")):
        payload = read_json(path)
        version = keys.normalize(str(payload.get("version") or ""))
        if not version or version not in keys.exact_to_group:
            continue
        source = payload.get("source") or {}
        if expected_source is not None:
            if source.get("commit") != expected_source["commit"]:
                raise ValueError(f"PKHeX overlay commit mismatch: {path}")
            if source.get("license") != expected_source["license"]:
                raise ValueError(f"PKHeX overlay license mismatch: {path}")
        source_record = {
            "sourceId": "pkhex-overlay",
            "commit": source.get("commit"),
            "license": source.get("license"),
            "overlay": path.relative_to(ROOT).as_posix(),
        }
        priority = int(payload.get("priority") or 0)
        for species_key, entries in (payload.get("encounters") or {}).items():
            try:
                species_id = int(species_key)
            except (TypeError, ValueError):
                continue
            for entry in entries or []:
                area_slug = str(entry.get("areaSlug") or "")
                if not area_slug:
                    continue
                identity = (species_id, area_slug, encounter_mode(entry))
                if priority >= priorities[version].get(identity, -1):
                    indexed[version][identity] = source_record
                    priorities[version][identity] = priority
    return dict(indexed)


def pinned_encounter_pairs(
    api_root: Path, species_id: int
) -> set[tuple[str, str, str]]:
    path = (
        api_root
        / "data"
        / "api"
        / "v2"
        / "pokemon"
        / str(species_id)
        / "encounters"
        / "index.json"
    )
    if not path.is_file():
        return set()
    pairs: set[tuple[str, str, str]] = set()
    for area in read_json(path):
        area_slug = ref_name(area.get("location_area"))
        if not area_slug:
            continue
        for version in area.get("version_details", []):
            version_slug = ref_name(version.get("version"))
            if version_slug:
                # The PokéAPI encounter endpoint represents regular location
                # encounters; fixed and raid claims require a reviewed overlay.
                pairs.add((version_slug, area_slug, "wild"))
    return pairs


def encounter_mode(entry: dict[str, Any]) -> str:
    if entry.get("isRaid"):
        return "raid"
    if entry.get("isFixedEncounter"):
        return "fixed"
    return "wild"


def compact_encounter(
    entry: dict[str, Any],
    *,
    exact_version: str,
    version_group: str,
    source: dict[str, Any],
) -> dict[str, Any]:
    return {
        "method": encounter_mode(entry),
        "exactVersion": exact_version,
        "versionGroup": version_group,
        "areaSlug": entry.get("areaSlug"),
        "areaLabelZh": entry.get("areaLabelZh"),
        "minLevel": entry.get("minLevel"),
        "maxLevel": entry.get("maxLevel"),
        "rateKind": entry.get("rateKind", "unknown"),
        "rateValue": entry.get("rateValue"),
        "encounterMethods": sorted(set(entry.get("methods") or [])),
        "conditions": sorted(set(entry.get("conditions") or [])),
        "formStableId": (
            f"pokemon-form:{entry['formKey']}" if entry.get("formKey") else None
        ),
        "isAlpha": bool(entry.get("isAlpha")),
        "isTitan": bool(entry.get("isTitan")),
        "isRaid": bool(entry.get("isRaid")),
        "isFixedEncounter": bool(entry.get("isFixedEncounter")),
        "source": source,
    }


def flatten_chain(chain: dict[str, Any]) -> list[tuple[dict[str, Any], int | None]]:
    rows: list[tuple[dict[str, Any], int | None]] = []

    def walk(node: dict[str, Any], parent: int | None) -> None:
        index = len(rows)
        rows.append((node, parent))
        for child in node.get("children") or []:
            walk(child, index)

    walk(chain, None)
    return rows


def is_trade_only(node: dict[str, Any]) -> bool:
    triggers = node.get("triggers") or []
    return bool(triggers) and all(trigger.get("trigger") == "trade" for trigger in triggers)


def plan_chain(
    chain: dict[str, Any],
    catchable: set[int],
    *,
    supports_breeding: bool,
) -> dict[int, str]:
    rows = flatten_chain(chain)
    result: list[str] = []
    for node, parent_index in rows:
        species_id = int(node["id"])
        if species_id in catchable:
            result.append("direct")
        elif parent_index is not None and result[parent_index] != "unknown":
            result.append("trade" if is_trade_only(node) else "evolution")
        else:
            result.append("unknown")
    if supports_breeding and result and result[0] == "unknown" and any(
        method != "unknown" for method in result[1:]
    ):
        result[0] = "egg"
        for index, (node, parent_index) in enumerate(rows[1:], start=1):
            if result[index] == "unknown" and parent_index is not None:
                parent_method = result[parent_index]
                if parent_method != "unknown":
                    result[index] = "trade" if is_trade_only(node) else "evolution"
    return {int(node["id"]): result[index] for index, (node, _) in enumerate(rows)}


def item_stable_by_slug(items: dict[str, dict[str, Any]]) -> dict[str, str]:
    return {
        row["slug"]: row.get("stableId") or f"item:{row['id']}"
        for row in items.values()
    }


def normalize_trigger(
    trigger: dict[str, Any],
    *,
    items_by_slug: dict[str, str],
    moves_by_slug: dict[str, str],
    pokemon_by_slug: dict[str, str],
) -> dict[str, Any]:
    normalized = dict(trigger)
    for key in ("item", "heldItem"):
        slug = trigger.get(key)
        if slug:
            normalized[f"{key}StableId"] = items_by_slug.get(slug)
            normalized[f"{key}Resolution"] = (
                "resolved" if slug in items_by_slug else "unknown"
            )
    move_slug = trigger.get("knownMove")
    if move_slug:
        normalized["knownMoveStableId"] = moves_by_slug.get(move_slug)
        normalized["knownMoveResolution"] = (
            "resolved" if move_slug in moves_by_slug else "unknown"
        )
    trade_species = trigger.get("tradeSpecies")
    if trade_species:
        normalized["tradeSpeciesStableId"] = pokemon_by_slug.get(trade_species)
        normalized["tradeSpeciesResolution"] = (
            "resolved" if trade_species in pokemon_by_slug else "unknown"
        )
    return normalized


def build_evolution_transitions(
    chains: dict[int, dict[str, Any]],
    *,
    keys: VersionKeys,
    species_generation: dict[int, int],
    items_by_slug: dict[str, str],
    moves_by_slug: dict[str, str],
    pokemon_by_slug: dict[str, str],
) -> list[dict[str, Any]]:
    transitions: dict[tuple[int, int], dict[str, Any]] = {}
    for chain in chains.values():
        rows = flatten_chain(chain)
        for node, parent_index in rows:
            if parent_index is None:
                continue
            parent = rows[parent_index][0]
            from_id, to_id = int(parent["id"]), int(node["id"])
            seen: set[str] = set()
            triggers = []
            for trigger in node.get("triggers") or []:
                normalized = normalize_trigger(
                    trigger,
                    items_by_slug=items_by_slug,
                    moves_by_slug=moves_by_slug,
                    pokemon_by_slug=pokemon_by_slug,
                )
                identity = json.dumps(normalized, ensure_ascii=False, sort_keys=True)
                if identity not in seen:
                    seen.add(identity)
                    triggers.append(normalized)
            applicability = {}
            for group, config in keys.groups.items():
                if config.get("notApplicable") or species_generation.get(to_id, 99) > int(
                    config["generation"]
                ):
                    applicability[group] = "notApplicable"
                else:
                    # PokeAPI evolution chains combine alternatives across
                    # games; without an exact-game source this must stay unknown.
                    applicability[group] = "unknown"
            transitions[(from_id, to_id)] = {
                "stableId": f"evolution:{from_id}:{to_id}",
                "fromPokemonStableId": f"pokemon:{from_id}",
                "toPokemonStableId": f"pokemon:{to_id}",
                "triggers": triggers,
                "applicabilityByVersionGroup": applicability,
                "source": {
                    "sourceId": "pokeapi-api-data",
                    "scope": "global chain; exact-game applicability unknown",
                },
            }
    return [transitions[key] for key in sorted(transitions)]


def machine_links_for_move(
    move: dict[str, Any], version_group: str
) -> list[dict[str, Any]]:
    links = []
    for machine in move.get("machines") or []:
        if machine.get("versionGroup") != version_group:
            continue
        item_id = machine.get("itemId")
        links.append(
            {
                "machineStableId": f"machine:{machine['machineId']}",
                "itemStableId": f"item:{item_id}" if item_id is not None else None,
                "kind": machine.get("kind", "machine"),
                "number": machine.get("number"),
                "recipeStatus": "unknown",
            }
        )
    return links


def build_learnsets(
    *,
    api_root: Path,
    keys: VersionKeys,
    moves: dict[str, dict[str, Any]],
    species_ids: list[int],
) -> tuple[dict[str, Any], dict[str, Any], Counter[str]]:
    by_species: dict[str, Any] = {}
    machine_mappings: dict[str, dict[str, list[dict[str, Any]]]] = defaultdict(dict)
    method_counts: Counter[str] = Counter()
    for species_id in species_ids:
        path = api_root / "data" / "api" / "v2" / "pokemon" / str(species_id) / "index.json"
        if not path.is_file():
            by_species[str(species_id)] = {
                "stableId": f"pokemon:{species_id}",
                "sourceStatus": "unknown",
                "byVersionGroup": {},
            }
            continue
        pokemon = read_json(path)
        grouped: dict[str, dict[str, Any]] = defaultdict(
            lambda: {
                "levelUp": [],
                "machine": [],
                "egg": [],
                "tutor": [],
                "other": [],
            }
        )
        seen: set[tuple[str, int, str, int]] = set()
        for move_entry in pokemon.get("moves") or []:
            move_id = ref_id(move_entry.get("move"))
            if move_id is None or str(move_id) not in moves:
                continue
            for detail in move_entry.get("version_group_details") or []:
                group = keys.group_for(ref_name(detail.get("version_group")) or "")
                if group is None or group == "champions":
                    continue
                method = ref_name(detail.get("move_learn_method")) or "unknown"
                level = int(detail.get("level_learned_at") or 0)
                identity = (group, move_id, method, level)
                if identity in seen:
                    continue
                seen.add(identity)
                move = moves[str(move_id)]
                move_stable_id = move.get("stableId") or f"move:{move_id}"
                bucket = grouped[group]
                if method == "machine":
                    bucket["machine"].append(move_stable_id)
                    machine_mappings[group].setdefault(
                        move_stable_id, machine_links_for_move(move, group)
                    )
                elif method == "level-up":
                    bucket["levelUp"].append(
                        {
                            "moveStableId": move_stable_id,
                            **({"level": level} if level > 0 else {}),
                        }
                    )
                elif method == "egg":
                    bucket["egg"].append(move_stable_id)
                elif method == "tutor":
                    bucket["tutor"].append(move_stable_id)
                else:
                    bucket["other"].append(
                        {"moveStableId": move_stable_id, "method": method}
                    )
                method_counts[method] += 1
        normalized_groups = {}
        for group, buckets in sorted(grouped.items()):
            normalized = {
                "levelUp": sorted(
                    buckets["levelUp"],
                    key=lambda row: (row.get("level", 0), row["moveStableId"]),
                ),
                "machine": sorted(set(buckets["machine"])),
                "egg": sorted(set(buckets["egg"])),
                "tutor": sorted(set(buckets["tutor"])),
            }
            if buckets["other"]:
                normalized["other"] = sorted(
                    buckets["other"],
                    key=lambda row: (row["method"], row["moveStableId"]),
                )
            normalized_groups[group] = normalized
        by_species[str(species_id)] = {
            "stableId": f"pokemon:{species_id}",
            "sourceStatus": "covered",
            "byVersionGroup": normalized_groups,
        }
    return by_species, dict(sorted(machine_mappings.items())), method_counts


def build_story_item_links(
    hints: dict[str, Any],
    items: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    items_by_slug = {row["slug"]: row for row in items.values()}
    items_by_source_id = {str(row.get("id")): row for row in items.values()}
    links: list[dict[str, Any]] = []
    unresolved: list[dict[str, Any]] = []
    for entry in hints["entries"]:
        for requirement in entry.get("requirements") or []:
            if requirement.get("type") != "key_item":
                continue
            item = items_by_slug.get(requirement["id"])
            if item is None and requirement.get("itemId") is not None:
                item = items_by_source_id.get(str(requirement["itemId"]))
            if item is None:
                unresolved.append(
                    {"hintId": entry["id"], "requirementId": requirement["id"]}
                )
                continue
            links.append(
                {
                    "stableId": f"story-item:{entry['id']}:{requirement['id']}",
                    "itemStableId": item.get("stableId") or f"item:{item['id']}",
                    "requirementId": requirement["id"],
                    "requirementLabelZh": requirement["labelZh"],
                    "hintId": entry["id"],
                    "games": entry["games"],
                    "generation": entry["generation"],
                    "subjectStableId": f"journey-subject:{entry['subject']['id']}",
                    "locationIds": entry["locations"],
                    "reliability": requirement["reliability"],
                    "evidenceTitles": [source["title"] for source in entry["sources"]],
                    "source": {
                        "sourceId": "reviewed-progression-requirement",
                        "datasetVersion": hints["datasetVersion"],
                    },
                }
            )
    return {
        "schemaVersion": 1,
        "links": links,
        "unresolved": unresolved,
        "guardrail": (
            "Only reviewed key_item requirements are included; held items are "
            "never interpreted as story usage."
        ),
    }


def build(args: argparse.Namespace) -> dict[str, Any]:
    staging = args.staging.resolve()
    if read_json(staging / "manifest.json").get("version") != 20:
        raise ValueError("Gameplay sidecars require a v20 reference candidate")
    source_lock = read_json(args.source_lock)
    pokeapi_source = next(
        source
        for source in source_lock["sources"]
        if source["sourceId"] == "pokeapi-api-data"
    )
    api_root = fetch_source_checkout(args.api_data, pokeapi_source)
    ensure_api_subtrees(api_root)
    gameplay_source_lock = read_json(args.gameplay_source_lock)
    pkhex_source = next(
        source
        for source in gameplay_source_lock["sources"]
        if source["sourceId"] == "pkhex-overlay"
    )
    keys = VersionKeys(read_json(args.version_keys))
    if len(keys.groups) != 23:
        raise ValueError(f"Expected 23 canonical game groups, got {len(keys.groups)}")

    summaries = read_json(staging / "summaries.json")
    species_generation = {int(row["id"]): int(row["generation"]) for row in summaries}
    pokemon_by_slug: dict[str, str] = {}
    for species_id in species_generation:
        pokemon_path = (
            api_root / "data" / "api" / "v2" / "pokemon" / str(species_id) / "index.json"
        )
        if pokemon_path.is_file():
            slug = str(read_json(pokemon_path).get("name") or "")
            if slug:
                pokemon_by_slug[slug] = f"pokemon:{species_id}"
    species_ids = sorted(species_generation)
    moves = read_json(staging / "moves.json")
    items = read_json(staging / "items.json")
    move_by_slug = {
        row["slug"]: row.get("stableId") or f"move:{row['id']}" for row in moves.values()
    }
    item_by_slug = item_stable_by_slug(items)
    overlay_encounters = load_overlay_encounters(keys, pkhex_source)

    direct_by_species: dict[str, Any] = {}
    shard_encounters_by_species: dict[str, dict[str, list[dict[str, Any]]]] = {}
    catchable_by_exact: dict[str, set[int]] = defaultdict(set)
    direct_mode_counts: Counter[str] = Counter()
    unverified_encounters = 0
    unverified_by_version: Counter[str] = Counter()
    chains: dict[int, dict[str, Any]] = {}
    for species_id in species_ids:
        detail = read_json(staging / "details" / f"{species_id}.json")
        chain = detail.get("evolutionChain")
        if chain:
            chains.setdefault(int(chain["id"]), chain)
        pinned_pairs = pinned_encounter_pairs(api_root, species_id)
        by_version: dict[str, list[dict[str, Any]]] = {}
        shard_by_version: dict[str, list[dict[str, Any]]] = {}
        for raw_version, entries in (detail.get("obtainLocationsByVersion") or {}).items():
            exact_version = keys.normalize(raw_version)
            group = keys.group_for(exact_version)
            if group is None or group == "champions":
                continue
            resolved_entries = []
            for entry in entries:
                area_slug = str(entry.get("areaSlug") or "")
                overlay_source = overlay_encounters.get(exact_version, {}).get(
                    (species_id, area_slug, encounter_mode(entry))
                )
                if overlay_source is not None:
                    source = overlay_source
                elif (exact_version, area_slug, encounter_mode(entry)) in pinned_pairs:
                    source = {
                        "sourceId": "pokeapi-api-data",
                        "commit": pokeapi_source["commit"],
                        "license": pokeapi_source["license"],
                    }
                else:
                    unverified_encounters += 1
                    unverified_by_version[exact_version] += 1
                    continue
                compact = compact_encounter(
                    entry,
                    exact_version=exact_version,
                    version_group=group,
                    source=source,
                )
                resolved_entries.append(compact)
                direct_mode_counts[compact["method"]] += 1
            if resolved_entries:
                shard_by_version[exact_version] = resolved_entries
                source_rows: dict[str, dict[str, Any]] = {}
                for row in resolved_entries:
                    source = row["source"]
                    identity = json.dumps(source, ensure_ascii=False, sort_keys=True)
                    source_rows.setdefault(identity, source)
                by_version[exact_version] = {
                    "methods": sorted({row["method"] for row in resolved_entries}),
                    "encounterCount": len(resolved_entries),
                    "detailRef": (
                        f"details/{species_id}.json#"
                        f"/obtainLocationsByVersion/{exact_version}"
                    ),
                    "sources": list(source_rows.values()),
                }
                catchable_by_exact[exact_version].add(species_id)
        direct_by_species[str(species_id)] = {
            "stableId": f"pokemon:{species_id}",
            "byExactVersion": by_version,
        }
        shard_encounters_by_species[str(species_id)] = dict(sorted(shard_by_version.items()))

    catchable_by_group: dict[str, set[int]] = {}
    for group, config in keys.groups.items():
        catchable: set[int] = set()
        for exact in config["exactVersions"]:
            catchable.update(catchable_by_exact.get(exact, set()))
        catchable_by_group[group] = catchable

    route_counts: Counter[str] = Counter()
    derived_route_counts: Counter[str] = Counter()
    route_unknown_by_group: Counter[str] = Counter()
    route_by_species: dict[str, dict[str, str]] = {
        str(species_id): {} for species_id in species_ids
    }
    for group, config in keys.groups.items():
        if config.get("notApplicable"):
            for species_id in species_ids:
                route_by_species[str(species_id)][group] = "notApplicable"
                direct_by_species[str(species_id)].setdefault(
                    "derivedFamilyRouteByVersionGroup", {}
                )[group] = "notApplicable"
                route_counts["notApplicable"] += 1
                derived_route_counts["notApplicable"] += 1
            continue
        group_plan: dict[int, str] = {}
        for chain in chains.values():
            group_plan.update(
                plan_chain(
                    chain,
                    catchable_by_group[group],
                    supports_breeding=bool(config["supportsBreeding"]),
                )
            )
        for species_id in species_ids:
            if species_generation[species_id] > int(config["generation"]):
                method = "notApplicable"
            else:
                method = group_plan.get(species_id, "unknown")
            # Only direct rows are exact-source confirmed.  Family reachability
            # is useful evidence, but stays a separate candidate field because
            # PokeAPI chains combine triggers from multiple games.
            verified_method = (
                method if method in {"direct", "notApplicable"} else "unknown"
            )
            route_by_species[str(species_id)][group] = verified_method
            direct_by_species[str(species_id)].setdefault(
                "derivedFamilyRouteByVersionGroup", {}
            )[group] = method
            route_counts[verified_method] += 1
            derived_route_counts[method] += 1
            if verified_method == "unknown":
                route_unknown_by_group[group] += 1
    for species_id, routes in route_by_species.items():
        direct_by_species[species_id]["verifiedRouteByVersionGroup"] = routes

    learnsets, machine_mappings, learn_method_counts = build_learnsets(
        api_root=api_root,
        keys=keys,
        moves=moves,
        species_ids=species_ids,
    )
    transitions = build_evolution_transitions(
        chains,
        keys=keys,
        species_generation=species_generation,
        items_by_slug=item_by_slug,
        moves_by_slug=move_by_slug,
        pokemon_by_slug=pokemon_by_slug,
    )
    story_links = build_story_item_links(read_json(args.progression_hints), items)
    shard_report = write_species_shards(
        staging / "gameplay" / "species",
        species_ids=species_ids,
        obtain_by_species=direct_by_species,
        encounters_by_species=shard_encounters_by_species,
        learn_by_species=learnsets,
        transitions=transitions,
        pokeapi_commit=pokeapi_source["commit"],
        pkhex_commit=pkhex_source["commit"],
    )

    coverage: dict[str, Any] = {}
    hint_games = {
        game
        for entry in read_json(args.progression_hints)["entries"]
        for game in entry["games"]
    }
    learned_groups = {
        group
        for species in learnsets.values()
        for group in species["byVersionGroup"]
    }
    for group, config in keys.groups.items():
        if config.get("notApplicable"):
            coverage[group] = {
                mode: "notApplicable"
                for mode in (
                    "wild",
                    "fixed",
                    "raid",
                    "gift",
                    "inGameTrade",
                    "egg",
                    "evolution",
                    "transfer",
                    "unavailable",
                    "learnMethods",
                    "itemStoryUsage",
                    "exactTriggerApplicability",
                )
            }
            continue
        exact = set(config["exactVersions"])
        encounter_methods = {
            method
            for species in direct_by_species.values()
            for version, summary in species["byExactVersion"].items()
            if version in exact
            for method in summary["methods"]
        }
        exact_base_games = exact & hint_games
        coverage[group] = {
            "wild": "covered" if "wild" in encounter_methods else "unknown",
            "fixed": "covered" if "fixed" in encounter_methods else "unknown",
            "raid": "covered" if "raid" in encounter_methods else "unknown",
            "gift": "unknown",
            "inGameTrade": "unknown",
            "egg": "unknown" if config["supportsBreeding"] else "notApplicable",
            "evolution": "unknown",
            "transfer": "unknown",
            "unavailable": "unknown",
            "learnMethods": "covered" if group in learned_groups else "unknown",
            "itemStoryUsage": "covered" if exact_base_games else "unknown",
            "exactTriggerApplicability": "unknown",
        }

    gameplay_dir = staging / "gameplay"
    gameplay_dir.mkdir(parents=True, exist_ok=True)
    obtain_payload = {
        "schemaVersion": 1,
        "sourceCommit": pokeapi_source["commit"],
        "species": direct_by_species,
        "modeDefinitions": {
            "wild": "exact species/area pair verified by a pinned allowed source",
            "fixed": "exact fixed encounter pair verified by a pinned allowed source",
            "raid": "exact raid encounter pair verified by a pinned allowed source",
            "gift": "unknown unless an exact-game reviewed source is added",
            "inGameTrade": "unknown unless an exact-game reviewed source is added",
            "egg": "breeding support is known, but species obtainability by egg remains unknown",
            "evolution": (
                "global family evidence is retained; exact trigger "
                "applicability remains unknown"
            ),
            "transfer": "unknown unless an exact-game reviewed source is added",
            "unavailable": "unknown is not treated as confirmed unavailable",
        },
        "routePolicy": {
            "verifiedRouteByVersionGroup": "Only direct, notApplicable, or unknown",
            "derivedFamilyRouteByVersionGroup": (
                "Non-authoritative family reachability hint; exact evolution "
                "applicability remains unknown"
            ),
        },
    }
    evolution_payload = {
        "schemaVersion": 1,
        "transitions": transitions,
        "guardrail": (
            "Global PokeAPI triggers are preserved; exact-game trigger "
            "applicability remains unknown unless separately reviewed."
        ),
    }
    learn_payload = {
        "schemaVersion": 1,
        "sourceCommit": pokeapi_source["commit"],
        "species": learnsets,
        "machineMappingsByVersionGroup": machine_mappings,
        "machineRecipeGuardrail": (
            "Machine identities are covered; crafting ingredient recipes "
            "remain unknown because the pinned source has no recipe table."
        ),
    }
    coverage_payload = {
        "schemaVersion": 1,
        "canonicalVersionGroups": list(keys.groups),
        "aliases": keys.aliases,
        "coverage": coverage,
    }
    audit = {
        "schemaVersion": 1,
        "canonicalVersionGroups": len(keys.groups),
        "exactVersions": len(keys.exact_to_group),
        "overlayVersions": len(overlay_encounters),
        "species": len(species_ids),
        "verifiedDirectSpeciesVersionPairs": sum(
            len(species["byExactVersion"]) for species in direct_by_species.values()
        ),
        "directEncounterRowsByMode": dict(sorted(direct_mode_counts.items())),
        "unverifiedEncounterRowsDropped": unverified_encounters,
        "unverifiedEncounterRowsByVersion": dict(sorted(unverified_by_version.items())),
        "routeDistribution": dict(sorted(route_counts.items())),
        "derivedFamilyRouteDistribution": dict(sorted(derived_route_counts.items())),
        "unknownRoutesByVersionGroup": dict(sorted(route_unknown_by_group.items())),
        "evolutionTransitions": len(transitions),
        "learnMethodRows": dict(sorted(learn_method_counts.items())),
        "storyItemLinks": len(story_links["links"]),
        "storyItemUnresolved": story_links["unresolved"],
        "speciesShards": shard_report["shardCount"],
        "maximumSpeciesShardBytes": shard_report["maximumShardBytes"],
        "coverageStatusDistribution": dict(
            sorted(
                Counter(
                    status
                    for group in coverage.values()
                    for field, status in group.items()
                    if field != "exactTriggerApplicability"
                ).items()
            )
        ),
    }
    write_json(gameplay_dir / "obtain_methods.json", obtain_payload, compact=True)
    write_json(gameplay_dir / "evolution_methods.json", evolution_payload, compact=True)
    write_json(gameplay_dir / "learn_methods.json", learn_payload, compact=True)
    write_json(gameplay_dir / "item_story_usage.json", story_links)
    write_json(gameplay_dir / "version_coverage.json", coverage_payload)
    write_json(gameplay_dir / "gameplay_v20_audit.json", audit)
    shutil.copyfile(args.version_keys, gameplay_dir / "game_version_keys.json")
    shutil.copyfile(args.gameplay_source_lock, gameplay_dir / "gameplay_sources.json")
    if PKHEX_NOTICE.is_file():
        shutil.copyfile(PKHEX_NOTICE, staging / "PKHEX_ATTRIBUTION.md")
    print(json.dumps(audit, ensure_ascii=False, indent=2))
    return audit


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, default=DEFAULT_OUTPUT / "staging")
    parser.add_argument("--api-data", type=Path, required=True)
    parser.add_argument("--source-lock", type=Path, default=SOURCE_LOCK)
    parser.add_argument(
        "--gameplay-source-lock", type=Path, default=GAMEPLAY_SOURCE_LOCK
    )
    parser.add_argument("--version-keys", type=Path, default=VERSION_KEYS)
    parser.add_argument("--progression-hints", type=Path, default=PROGRESSION_HINTS)
    args = parser.parse_args()
    build(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
