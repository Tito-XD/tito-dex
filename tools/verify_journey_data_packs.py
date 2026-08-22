#!/usr/bin/env python3
"""Verify a complete Journey data-pack candidate before any R2 write."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
MAX_CATALOG_BYTES = 256 * 1024
MAX_PACK_BYTES = 4 * 1024 * 1024
MAX_PACK_ENTRIES = 1000
EXPECTED_BUCKET = "titodex-journey-content"
DEFAULT_CANONICAL_SOURCE = ROOT / "data" / "journey" / "progression_hints.json"

FAMILY_GAMES = {
    "dpp": ["diamond", "pearl", "platinum"],
    "hgss": ["heartgold", "soulsilver"],
    "bw": ["black", "white"],
    "bw2": ["black-2", "white-2"],
    "xy": ["x", "y"],
    "oras": ["omega-ruby", "alpha-sapphire"],
    "sm": ["sun", "moon"],
    "usum": ["ultra-sun", "ultra-moon"],
    "swsh": ["sword", "shield"],
    "bdsp": ["brilliant-diamond", "shining-pearl"],
    "pla": ["legends-arceus"],
    "sv": ["scarlet", "violet"],
}

GAME_GENERATIONS = {
    "diamond": 4,
    "pearl": 4,
    "platinum": 4,
    "heartgold": 4,
    "soulsilver": 4,
    "black": 5,
    "white": 5,
    "black-2": 5,
    "white-2": 5,
    "x": 6,
    "y": 6,
    "omega-ruby": 6,
    "alpha-sapphire": 6,
    "sun": 7,
    "moon": 7,
    "ultra-sun": 7,
    "ultra-moon": 7,
    "sword": 8,
    "shield": 8,
    "brilliant-diamond": 8,
    "shining-pearl": 8,
    "legends-arceus": 8,
    "scarlet": 9,
    "violet": 9,
}

PACK_ID = re.compile(r"^[a-z0-9][a-z0-9._-]{0,79}$")
FAMILY_ID = re.compile(r"^[a-z0-9][a-z0-9._-]{0,39}$")
VERSION = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$")
HINT_ID = re.compile(r"^[a-z0-9_-]+$")
ACTION_ID = re.compile(r"^[a-z0-9_]+$")
SHA256 = re.compile(r"^[a-f0-9]{64}$")
ISO_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
ISO_DATETIME = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$")


def canonical_json(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def verify_candidate_dir(
    root: Path,
    *,
    canonical_source: Path = DEFAULT_CANONICAL_SOURCE,
) -> dict[str, Any]:
    root = root.resolve()
    source = json.loads(canonical_source.read_text(encoding="utf-8"))
    _exact_keys(source, {"schemaVersion", "datasetVersion", "entries"}, "canonical source")
    if source["schemaVersion"] != 1 or not _integer(source["datasetVersion"], 1):
        raise ValueError("unsupported canonical Journey source")
    if not isinstance(source["entries"], list) or not source["entries"]:
        raise ValueError("canonical Journey source is empty")
    canonical_ids: set[str] = set()
    all_supported_games = set(GAME_GENERATIONS)
    for entry in source["entries"]:
        _validate_entry(entry, all_supported_games)
        if entry["id"] in canonical_ids:
            raise ValueError("canonical Journey source has duplicate IDs")
        canonical_ids.add(entry["id"])
    catalog_path = root / "catalog.json"
    plan_path = root / "journey-pack-upload-plan.json"
    if not catalog_path.is_file() or not plan_path.is_file():
        raise ValueError("candidate must contain catalog.json and upload plan")

    catalog_bytes = catalog_path.read_bytes()
    if not 2 <= len(catalog_bytes) <= MAX_CATALOG_BYTES:
        raise ValueError("catalog exceeds bounded size")
    catalog = _load_canonical_json(catalog_bytes, "catalog")
    _exact_keys(catalog, {"schemaVersion", "generatedAt", "packs"}, "catalog")
    if catalog["schemaVersion"] != 1:
        raise ValueError("unsupported catalog schemaVersion")
    if not _valid_datetime(catalog["generatedAt"]):
        raise ValueError("invalid catalog generatedAt")
    packs = catalog["packs"]
    if not isinstance(packs, list) or len(packs) > len(GAME_GENERATIONS):
        raise ValueError("invalid catalog packs")

    ids: set[str] = set()
    paths: set[str] = set()
    assigned_games: set[str] = set()
    verified_objects: list[dict[str, Any]] = []
    verified_packs: dict[str, tuple[dict[str, Any], dict[str, Any]]] = {}
    for descriptor in packs:
        _validate_descriptor(descriptor)
        pack_id = descriptor["id"]
        content_path = descriptor["contentPath"]
        if pack_id in ids or content_path in paths:
            raise ValueError("duplicate catalog id or contentPath")
        ids.add(pack_id)
        paths.add(content_path)
        if assigned_games.intersection(descriptor["games"]):
            raise ValueError("a game is assigned to more than one Journey pack")
        assigned_games.update(descriptor["games"])

        relative = content_path.removeprefix("/v1/journey-packs/")
        if relative == content_path or not relative.startswith("objects/"):
            raise ValueError("invalid pack contentPath")
        object_path = (root / relative).resolve()
        if root not in object_path.parents or not object_path.is_file():
            raise ValueError(f"missing pack object for {pack_id}")
        body = object_path.read_bytes()
        if len(body) != descriptor["sizeBytes"] or len(body) > MAX_PACK_BYTES:
            raise ValueError(f"pack size mismatch for {pack_id}")
        if hashlib.sha256(body).hexdigest() != descriptor["sha256"]:
            raise ValueError(f"pack hash mismatch for {pack_id}")
        pack = _load_canonical_json(body, f"pack {pack_id}")
        _validate_pack(pack, descriptor)
        if descriptor["gameFamily"] in verified_packs:
            raise ValueError("duplicate Journey game family")
        verified_packs[descriptor["gameFamily"]] = (descriptor, pack)
        verified_objects.append(
            {
                "sourcePath": relative,
                "objectKey": f"journey-packs/{relative}",
                "contentType": "application/json; charset=utf-8",
                "sha256": descriptor["sha256"],
                "sizeBytes": descriptor["sizeBytes"],
                "immutable": True,
            }
        )

    expected_families: dict[str, list[dict[str, Any]]] = {}
    expected_source_dates: list[str] = []
    for family, games in FAMILY_GAMES.items():
        game_set = set(games)
        selected = [
            entry
            for entry in source["entries"]
            if game_set.intersection(entry["games"])
        ]
        if not selected:
            continue
        if any(not set(entry["games"]).issubset(game_set) for entry in selected):
            raise ValueError("canonical Journey hint crosses pack families")
        expected_families[family] = selected
    if set(verified_packs) != set(expected_families):
        raise ValueError("catalog does not contain the complete canonical family set")
    for family, selected in expected_families.items():
        descriptor, pack = verified_packs[family]
        expected_date = max(
            source_row["accessedAt"]
            for entry in selected
            for source_row in entry["sources"]
        )
        expected_source_dates.append(expected_date)
        if (
            descriptor["id"] != f"journey-{family}"
            or descriptor["games"] != FAMILY_GAMES[family]
            or descriptor["version"] != str(source["datasetVersion"])
            or pack.get("sourceAsOf") != expected_date
            or pack["entries"] != selected
        ):
            raise ValueError(
                f"Journey pack {family} differs from the canonical reviewed source"
            )
    expected_generated_at = f"{max(expected_source_dates)}T00:00:00Z"
    if catalog["generatedAt"] != expected_generated_at:
        raise ValueError("catalog generatedAt does not match per-pack source dates")

    plan_bytes = plan_path.read_bytes()
    plan = _load_canonical_json(plan_bytes, "upload plan")
    _exact_keys(plan, {"schemaVersion", "bucket", "objects", "catalog"}, "upload plan")
    if plan["schemaVersion"] != 1 or plan["bucket"] != EXPECTED_BUCKET:
        raise ValueError("upload plan targets an unexpected schema or bucket")
    if plan["objects"] != verified_objects:
        raise ValueError("upload plan objects do not exactly match the catalog")
    expected_catalog_plan = {
        "sourcePath": "catalog.json",
        "objectKey": "journey-packs/catalog.json",
        "contentType": "application/json; charset=utf-8",
        "sha256": hashlib.sha256(catalog_bytes).hexdigest(),
        "sizeBytes": len(catalog_bytes),
        "uploadLast": True,
    }
    if plan["catalog"] != expected_catalog_plan:
        raise ValueError("catalog upload plan is not a catalog-last exact match")
    return {
        "catalog": catalog,
        "plan": plan,
        "packCount": len(packs),
        "entryCount": sum(item["entryCount"] for item in packs),
        "canonicalSource": canonical_source.name,
    }


def _validate_descriptor(value: Any) -> None:
    required = {
        "id",
        "gameFamily",
        "games",
        "version",
        "contentPath",
        "sizeBytes",
        "sha256",
        "titleZh",
        "entryCount",
        "bundleVersionRequired",
    }
    optional = {"descriptionZh", "minAppVersion"}
    _required_only_keys(value, required, optional, "catalog descriptor")
    _safe_segment(value["id"], PACK_ID, "pack id")
    _safe_segment(value["gameFamily"], FAMILY_ID, "game family")
    _safe_segment(value["version"], VERSION, "pack version")
    _valid_games(value["games"], "descriptor games")
    expected_path = (
        f"/v1/journey-packs/objects/{value['id']}/{value['version']}.json"
    )
    if value["contentPath"] != expected_path:
        raise ValueError("descriptor contentPath must derive from id/version")
    if not _integer(value["sizeBytes"], 2, MAX_PACK_BYTES):
        raise ValueError("invalid descriptor sizeBytes")
    if not isinstance(value["sha256"], str) or not SHA256.fullmatch(value["sha256"]):
        raise ValueError("invalid descriptor sha256")
    _bounded_string(value["titleZh"], 1, 80, "titleZh")
    if "descriptionZh" in value:
        _bounded_string(value["descriptionZh"], 1, 180, "descriptionZh")
    if not _integer(value["entryCount"], 1, MAX_PACK_ENTRIES):
        raise ValueError("invalid descriptor entryCount")
    if not _integer(value["bundleVersionRequired"], 20):
        raise ValueError("invalid bundleVersionRequired")
    if "minAppVersion" in value and not (
        isinstance(value["minAppVersion"], str)
        and re.fullmatch(r"\d+\.\d+\.\d+", value["minAppVersion"])
    ):
        raise ValueError("invalid minAppVersion")


def _validate_pack(pack: Any, descriptor: dict[str, Any]) -> None:
    required = {"schemaVersion", "id", "gameFamily", "games", "version", "entries"}
    _required_only_keys(pack, required, {"sourceAsOf"}, f"pack {descriptor['id']}")
    if pack["schemaVersion"] != 1:
        raise ValueError("unsupported pack schemaVersion")
    for field in ("id", "gameFamily", "games", "version"):
        if pack[field] != descriptor[field]:
            raise ValueError(f"pack {field} does not match catalog")
    if "sourceAsOf" in pack and not _valid_date(pack["sourceAsOf"]):
        raise ValueError("invalid pack sourceAsOf")
    entries = pack["entries"]
    if not isinstance(entries, list) or len(entries) != descriptor["entryCount"]:
        raise ValueError("pack entryCount does not match catalog")
    ids: set[str] = set()
    pack_games = set(descriptor["games"])
    for entry in entries:
        _validate_entry(entry, pack_games)
        if entry["id"] in ids:
            raise ValueError("duplicate Journey hint id within a pack")
        ids.add(entry["id"])


def _validate_entry(value: Any, pack_games: set[str]) -> None:
    _exact_keys(
        value,
        {
            "id",
            "games",
            "generation",
            "locations",
            "locationAliases",
            "destinationAliases",
            "subject",
            "requirements",
            "steps",
            "overviewZh",
            "sources",
        },
        "Journey hint",
    )
    if not isinstance(value["id"], str) or not HINT_ID.fullmatch(value["id"]):
        raise ValueError("invalid Journey hint id")
    games = _valid_games(value["games"], "hint games")
    if not set(games).issubset(pack_games):
        raise ValueError("Journey hint games escape its pack")
    if not _integer(value["generation"], 4, 9):
        raise ValueError("invalid Journey hint generation")
    if any(GAME_GENERATIONS[game] != value["generation"] for game in games):
        raise ValueError("Journey hint generation does not match its games")
    _string_list(value["locations"], "locations", unique=True)
    _string_list(value["locationAliases"], "locationAliases")
    _string_list(value["destinationAliases"], "destinationAliases")

    subject = value["subject"]
    _exact_keys(subject, {"type", "id", "labelZh", "aliases"}, "subject")
    if subject["type"] not in {
        "overworld_blocker",
        "story_blocker",
        "reference_topic",
    }:
        raise ValueError("invalid subject type")
    if not isinstance(subject["id"], str) or not HINT_ID.fullmatch(subject["id"]):
        raise ValueError("invalid subject id")
    _bounded_string(subject["labelZh"], 1, 80, "subject labelZh")
    _string_list(subject["aliases"], "subject aliases", min_items=1)

    if not isinstance(value["requirements"], list):
        raise ValueError("requirements must be an array")
    for requirement in value["requirements"]:
        _required_only_keys(
            requirement,
            {"type", "id", "labelZh", "reliability"},
            {"itemId"},
            "requirement",
        )
        if requirement["type"] not in {"badge", "key_item", "milestone"}:
            raise ValueError("invalid requirement type")
        if not isinstance(requirement["id"], str) or not HINT_ID.fullmatch(requirement["id"]):
            raise ValueError("invalid requirement id")
        _bounded_string(requirement["labelZh"], 1, 80, "requirement labelZh")
        if requirement["reliability"] not in {
            "save_verified",
            "not_currently_parsed",
        }:
            raise ValueError("invalid requirement reliability")
        if "itemId" in requirement and not _integer(requirement["itemId"], 1):
            raise ValueError("invalid requirement itemId")

    if not isinstance(value["steps"], list) or not value["steps"]:
        raise ValueError("steps must be a non-empty array")
    for step in value["steps"]:
        _exact_keys(
            step,
            {"order", "action", "targetId", "locationId", "instructionZh"},
            "step",
        )
        if not _integer(step["order"], 1):
            raise ValueError("invalid step order")
        if not isinstance(step["action"], str) or not ACTION_ID.fullmatch(step["action"]):
            raise ValueError("invalid step action")
        if not isinstance(step["targetId"], str) or not HINT_ID.fullmatch(step["targetId"]):
            raise ValueError("invalid step targetId")
        _bounded_string(step["locationId"], 1, 120, "step locationId")
        _bounded_string(step["instructionZh"], 1, 120, "step instructionZh")

    _bounded_string(value["overviewZh"], 1, 180, "overviewZh")
    if not isinstance(value["sources"], list) or not value["sources"]:
        raise ValueError("sources must be a non-empty array")
    for source in value["sources"]:
        _exact_keys(source, {"title", "url", "accessedAt"}, "source")
        _bounded_string(source["title"], 1, 180, "source title")
        _bounded_string(source["url"], 1, 600, "source URL")
        parsed = urlparse(source["url"])
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise ValueError("source URL must be HTTP(S)")
        if not _valid_date(source["accessedAt"]):
            raise ValueError("invalid source accessedAt")


def _load_canonical_json(body: bytes, label: str) -> Any:
    try:
        value = json.loads(body)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid JSON in {label}") from exc
    if body != canonical_json(value):
        raise ValueError(f"{label} must use canonical byte-stable JSON")
    return value


def _valid_games(value: Any, label: str) -> list[str]:
    if not isinstance(value, list) or not value or len(value) != len(set(value)):
        raise ValueError(f"{label} must be a non-empty unique array")
    if any(not isinstance(game, str) or game not in GAME_GENERATIONS for game in value):
        raise ValueError(f"{label} contains an unsupported game")
    return value


def _safe_segment(value: Any, pattern: re.Pattern[str], label: str) -> None:
    if not isinstance(value, str) or ".." in value or not pattern.fullmatch(value):
        raise ValueError(f"invalid {label}")


def _exact_keys(value: Any, expected: set[str], label: str) -> None:
    if not isinstance(value, dict) or set(value) != expected:
        raise ValueError(f"{label} has missing or unexpected fields")


def _required_only_keys(
    value: Any, required: set[str], optional: set[str], label: str
) -> None:
    if not isinstance(value, dict) or not required.issubset(value) or not set(value).issubset(required | optional):
        raise ValueError(f"{label} has missing or unexpected fields")


def _bounded_string(value: Any, minimum: int, maximum: int, label: str) -> None:
    if not isinstance(value, str) or not minimum <= len(value) <= maximum:
        raise ValueError(f"invalid {label}")


def _string_list(
    value: Any,
    label: str,
    *,
    min_items: int = 0,
    unique: bool = False,
) -> None:
    if not isinstance(value, list) or len(value) < min_items:
        raise ValueError(f"invalid {label}")
    if unique and len(value) != len(set(value)):
        raise ValueError(f"{label} must be unique")
    if any(not isinstance(item, str) or not 1 <= len(item) <= 80 for item in value):
        raise ValueError(f"invalid {label}")


def _integer(value: Any, minimum: int, maximum: int | None = None) -> bool:
    return (
        isinstance(value, int)
        and not isinstance(value, bool)
        and value >= minimum
        and (maximum is None or value <= maximum)
    )


def _valid_date(value: Any) -> bool:
    if not isinstance(value, str) or not ISO_DATE.fullmatch(value):
        return False
    try:
        from datetime import date

        return date.fromisoformat(value).isoformat() == value
    except ValueError:
        return False


def _valid_datetime(value: Any) -> bool:
    if not isinstance(value, str) or not ISO_DATETIME.fullmatch(value):
        return False
    try:
        from datetime import datetime

        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return True
    except ValueError:
        return False


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=Path)
    args = parser.parse_args()
    result = verify_candidate_dir(args.candidate)
    print(
        f"verified {result['packCount']} Journey packs / "
        f"{result['entryCount']} audited entries"
    )


if __name__ == "__main__":
    main()
