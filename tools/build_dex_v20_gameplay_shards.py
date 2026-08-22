#!/usr/bin/env python3
"""Write and verify bounded per-species v20 gameplay shards.

The large aggregate gameplay sidecars remain the audit source of truth.  These
shards are a deterministic serving projection for the Journey Assistant so a
single question never needs to download and parse the aggregate objects.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
MAX_SPECIES_ID = 1025
MAX_SHARD_BYTES = 1024 * 1024
SHA40 = re.compile(r"^[0-9a-f]{40}$")
ROUTE_VALUES = {"direct", "evolution", "egg", "trade", "notApplicable", "unknown"}
VERIFIED_ROUTE_VALUES = {"direct", "notApplicable", "unknown"}
ENCOUNTER_METHODS = {"wild", "fixed", "raid"}
LEARN_BUCKETS = {"levelUp", "machine", "egg", "tutor", "other"}


def _exact_keys(value: dict[str, Any], expected: set[str], label: str) -> None:
    if set(value) != expected:
        raise ValueError(f"{label} keys differ: {sorted(set(value) ^ expected)}")


def _stable_id(value: Any, prefix: str, *, label: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(rf"{re.escape(prefix)}:[1-9]\d{{0,4}}", value):
        raise ValueError(f"invalid {label}")
    return value


def _validate_source(value: Any) -> None:
    if not isinstance(value, dict):
        raise ValueError("encounter source must be an object")
    allowed = {"sourceId", "commit", "license", "overlay"}
    if set(value) - allowed or not isinstance(value.get("sourceId"), str):
        raise ValueError("invalid encounter source")
    commit = value.get("commit")
    if commit is not None and (not isinstance(commit, str) or not SHA40.fullmatch(commit)):
        raise ValueError("invalid encounter source commit")
    for key in ("license", "overlay"):
        if key in value and not isinstance(value[key], str):
            raise ValueError(f"invalid encounter source {key}")


def _validate_encounter(
    value: Any,
    exact_version: str,
    *,
    pokeapi_commit: str,
    pkhex_commit: str,
) -> None:
    if not isinstance(value, dict):
        raise ValueError("encounter must be an object")
    expected = {
        "method", "exactVersion", "versionGroup", "areaSlug", "areaLabelZh",
        "minLevel", "maxLevel", "rateKind", "rateValue", "encounterMethods",
        "conditions", "formStableId", "isAlpha", "isTitan", "isRaid",
        "isFixedEncounter", "source",
    }
    _exact_keys(value, expected, "encounter")
    if value["method"] not in ENCOUNTER_METHODS or value["exactVersion"] != exact_version:
        raise ValueError("invalid encounter identity")
    for key in ("versionGroup", "areaSlug", "rateKind"):
        if not isinstance(value[key], str) or not value[key]:
            raise ValueError(f"invalid encounter {key}")
    if not isinstance(value["areaLabelZh"], str) or len(value["areaLabelZh"]) > 160:
        raise ValueError("invalid encounter area label")
    for key in ("minLevel", "maxLevel"):
        if value[key] is not None and (
            not isinstance(value[key], int) or isinstance(value[key], bool) or not 1 <= value[key] <= 100
        ):
            raise ValueError(f"invalid encounter {key}")
    if value["rateValue"] is not None and (
        not isinstance(value["rateValue"], (int, float)) or isinstance(value["rateValue"], bool)
        or not 0 <= value["rateValue"] <= 1_000_000_000
    ):
        raise ValueError("invalid encounter rate")
    for key in ("encounterMethods", "conditions"):
        if not isinstance(value[key], list) or len(value[key]) > 32 or not all(
            isinstance(item, str) and len(item) <= 160 for item in value[key]
        ):
            raise ValueError(f"invalid encounter {key}")
    form_id = value["formStableId"]
    if form_id is not None and (
        not isinstance(form_id, str) or not re.fullmatch(r"pokemon-form:[a-z0-9-]{1,100}", form_id)
    ):
        raise ValueError("invalid form stable id")
    if not all(isinstance(value[key], bool) for key in ("isAlpha", "isTitan", "isRaid", "isFixedEncounter")):
        raise ValueError("invalid encounter flags")
    _validate_source(value["source"])
    expected_commit = (
        pokeapi_commit
        if value["source"]["sourceId"] == "pokeapi-api-data"
        else pkhex_commit
        if value["source"]["sourceId"] == "pkhex-overlay"
        else None
    )
    if expected_commit is None or value["source"].get("commit") != expected_commit:
        raise ValueError("encounter source is not bound to shard provenance")


def _validate_obtain(
    value: Any,
    species_id: int,
    *,
    pokeapi_commit: str,
    pkhex_commit: str,
) -> None:
    if not isinstance(value, dict):
        raise ValueError("obtain must be an object")
    _exact_keys(
        value,
        {"stableId", "byExactVersion", "verifiedRouteByVersionGroup", "derivedFamilyRouteByVersionGroup"},
        "obtain",
    )
    if _stable_id(value["stableId"], "pokemon", label="obtain stable id") != f"pokemon:{species_id}":
        raise ValueError("obtain species mismatch")
    exact_rows = value["byExactVersion"]
    if not isinstance(exact_rows, dict) or len(exact_rows) > 51:
        raise ValueError("invalid exact-version encounter map")
    for exact, encounters in exact_rows.items():
        if not isinstance(exact, str) or not re.fullmatch(r"[a-z0-9-]{1,60}", exact):
            raise ValueError("invalid exact version")
        if not isinstance(encounters, list) or not 1 <= len(encounters) <= 4096:
            raise ValueError("invalid encounter rows")
        for encounter in encounters:
            _validate_encounter(
                encounter,
                exact,
                pokeapi_commit=pokeapi_commit,
                pkhex_commit=pkhex_commit,
            )
    for key, allowed in (
        ("verifiedRouteByVersionGroup", VERIFIED_ROUTE_VALUES),
        ("derivedFamilyRouteByVersionGroup", ROUTE_VALUES),
    ):
        routes = value[key]
        if not isinstance(routes, dict) or not 1 <= len(routes) <= 32:
            raise ValueError(f"invalid {key}")
        if not all(
            isinstance(group, str) and re.fullmatch(r"[a-z0-9-]{1,80}", group)
            and route in allowed
            for group, route in routes.items()
        ):
            raise ValueError(f"invalid {key} row")


def _validate_learn(value: Any, species_id: int) -> None:
    if not isinstance(value, dict):
        raise ValueError("learn must be an object")
    _exact_keys(value, {"stableId", "sourceStatus", "byVersionGroup"}, "learn")
    if _stable_id(value["stableId"], "pokemon", label="learn stable id") != f"pokemon:{species_id}":
        raise ValueError("learn species mismatch")
    if value["sourceStatus"] not in {"covered", "unknown"}:
        raise ValueError("invalid learn source status")
    groups = value["byVersionGroup"]
    if not isinstance(groups, dict) or len(groups) > 32:
        raise ValueError("invalid learn groups")
    for group, buckets in groups.items():
        if not isinstance(group, str) or not re.fullmatch(r"[a-z0-9-]{1,80}", group) or not isinstance(buckets, dict):
            raise ValueError("invalid learn group")
        if not {"levelUp", "machine", "egg", "tutor"} <= set(buckets) <= LEARN_BUCKETS:
            raise ValueError("invalid learn buckets")
        total = sum(len(rows) for rows in buckets.values() if isinstance(rows, list))
        if total > 4096:
            raise ValueError("learn group is too large")
        for bucket, rows in buckets.items():
            if not isinstance(rows, list):
                raise ValueError("learn bucket must be an array")
            for row in rows:
                if bucket in {"machine", "egg", "tutor"}:
                    _stable_id(row, "move", label="move stable id")
                elif not isinstance(row, dict) or set(row) - {"moveStableId", "level", "method"}:
                    raise ValueError("invalid structured learn row")
                else:
                    _stable_id(row.get("moveStableId"), "move", label="move stable id")
                    if "level" in row and (
                        not isinstance(row["level"], int) or isinstance(row["level"], bool)
                        or not 1 <= row["level"] <= 100
                    ):
                        raise ValueError("invalid learn level")
                    if bucket == "other" and (
                        not isinstance(row.get("method"), str) or not row["method"]
                    ):
                        raise ValueError("invalid other learn method")


def _validate_evolution(value: Any, species_id: int) -> None:
    if not isinstance(value, list) or len(value) > 64:
        raise ValueError("invalid evolution rows")
    for row in value:
        if not isinstance(row, dict):
            raise ValueError("evolution row must be an object")
        _exact_keys(
            row,
            {"stableId", "fromPokemonStableId", "toPokemonStableId", "triggers", "applicabilityByVersionGroup", "source"},
            "evolution row",
        )
        from_id = int(_stable_id(row["fromPokemonStableId"], "pokemon", label="from species").split(":")[1])
        to_id = int(_stable_id(row["toPokemonStableId"], "pokemon", label="to species").split(":")[1])
        if species_id not in {from_id, to_id} or row["stableId"] != f"evolution:{from_id}:{to_id}":
            raise ValueError("evolution identity mismatch")
        if not isinstance(row["triggers"], list) or len(row["triggers"]) > 16 or not all(
            isinstance(trigger, dict) and len(trigger) <= 40 for trigger in row["triggers"]
        ):
            raise ValueError("invalid evolution triggers")
        applicability = row["applicabilityByVersionGroup"]
        if not isinstance(applicability, dict) or not 1 <= len(applicability) <= 32 or not all(
            status in {"unknown", "notApplicable"} for status in applicability.values()
        ):
            raise ValueError("invalid evolution applicability")
        source = row["source"]
        if not isinstance(source, dict) or source.get("sourceId") != "pokeapi-api-data":
            raise ValueError("invalid evolution source")


def validate_shard(payload: Any, *, expected_species_id: int | None = None) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise ValueError("shard must be an object")
    _exact_keys(payload, {"schemaVersion", "speciesId", "pokemonStableId", "provenance", "obtain", "learn", "evolutions"}, "shard")
    species_id = payload["speciesId"]
    if not isinstance(species_id, int) or isinstance(species_id, bool) or not 1 <= species_id <= MAX_SPECIES_ID:
        raise ValueError("invalid species id")
    if expected_species_id is not None and species_id != expected_species_id:
        raise ValueError("shard path/species mismatch")
    if payload["schemaVersion"] != SCHEMA_VERSION or payload["pokemonStableId"] != f"pokemon:{species_id}":
        raise ValueError("invalid shard identity")
    provenance = payload["provenance"]
    if not isinstance(provenance, dict):
        raise ValueError("invalid shard provenance")
    _exact_keys(provenance, {"generator", "pokeapiCommit", "pkhexCommit"}, "shard provenance")
    if provenance["generator"] != "titodex-gameplay-shards-v1" or not all(
        isinstance(provenance[key], str) and SHA40.fullmatch(provenance[key])
        for key in ("pokeapiCommit", "pkhexCommit")
    ):
        raise ValueError("invalid shard provenance values")
    _validate_obtain(
        payload["obtain"],
        species_id,
        pokeapi_commit=provenance["pokeapiCommit"],
        pkhex_commit=provenance["pkhexCommit"],
    )
    _validate_learn(payload["learn"], species_id)
    _validate_evolution(payload["evolutions"], species_id)
    return payload


def write_species_shards(
    output_dir: Path,
    *,
    species_ids: list[int],
    obtain_by_species: dict[str, Any],
    encounters_by_species: dict[str, dict[str, list[dict[str, Any]]]],
    learn_by_species: dict[str, Any],
    transitions: list[dict[str, Any]],
    pokeapi_commit: str,
    pkhex_commit: str,
) -> dict[str, int]:
    if not SHA40.fullmatch(pokeapi_commit) or not SHA40.fullmatch(pkhex_commit):
        raise ValueError("shard source commits must be lowercase SHA-1 values")
    by_species_evolution: dict[int, list[dict[str, Any]]] = {species_id: [] for species_id in species_ids}
    for transition in transitions:
        from_id = int(str(transition["fromPokemonStableId"]).split(":")[1])
        to_id = int(str(transition["toPokemonStableId"]).split(":")[1])
        for species_id in {from_id, to_id}:
            if species_id in by_species_evolution:
                by_species_evolution[species_id].append(transition)
    output_dir.mkdir(parents=True, exist_ok=True)
    maximum = 0
    for species_id in species_ids:
        key = str(species_id)
        obtain = dict(obtain_by_species[key])
        obtain["byExactVersion"] = encounters_by_species.get(key, {})
        payload = {
            "schemaVersion": SCHEMA_VERSION,
            "speciesId": species_id,
            "pokemonStableId": f"pokemon:{species_id}",
            "provenance": {
                "generator": "titodex-gameplay-shards-v1",
                "pokeapiCommit": pokeapi_commit,
                "pkhexCommit": pkhex_commit,
            },
            "obtain": obtain,
            "learn": learn_by_species[key],
            "evolutions": by_species_evolution[species_id],
        }
        validate_shard(payload, expected_species_id=species_id)
        encoded = (json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")
        if len(encoded) > MAX_SHARD_BYTES:
            raise ValueError(f"gameplay shard {species_id} exceeds {MAX_SHARD_BYTES} bytes")
        (output_dir / f"{species_id}.json").write_bytes(encoded)
        maximum = max(maximum, len(encoded))
    return {"shardCount": len(species_ids), "maximumShardBytes": maximum}


def verify_shard_tree(root: Path, *, expected_species_ids: list[int]) -> dict[str, int]:
    expected = {f"{species_id}.json" for species_id in expected_species_ids}
    actual = {path.name for path in root.glob("*.json") if path.is_file()}
    if actual != expected:
        raise ValueError(f"gameplay shard set differs: missing={sorted(expected-actual)} extra={sorted(actual-expected)}")
    maximum = 0
    for species_id in expected_species_ids:
        path = root / f"{species_id}.json"
        size = path.stat().st_size
        if not 2 <= size <= MAX_SHARD_BYTES:
            raise ValueError(f"invalid gameplay shard size: {path}")
        validate_shard(json.loads(path.read_text(encoding="utf-8")), expected_species_id=species_id)
        maximum = max(maximum, size)
    return {"shardCount": len(expected_species_ids), "maximumShardBytes": maximum}
