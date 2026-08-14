#!/usr/bin/env python3
"""Validate Journey source provenance and reviewed fact-pack inputs offline."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REGISTRY = ROOT / "data/journey/sources/source_registry.json"
DEFAULT_LOCK = ROOT / "data/journey/sources/source_lock.json"
DEFAULT_PACK = ROOT / "data/journey/packs/hgss/facts.json"
AUTO_IMPORT_ALLOWLIST = {"pokeapi-api-data", "wikidata"}
SHA256 = re.compile(r"^[a-f0-9]{64}$")


def load_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: root must be an object")
    return value


def default_fact_packs() -> list[Path]:
    return sorted((ROOT / "data/journey/packs").glob("*/facts.json"))


def validate_supply_chain(
    registry: dict,
    source_lock: dict,
    pack: dict,
    *,
    release: bool = False,
) -> None:
    if registry.get("schemaVersion") != 1:
        raise ValueError("unsupported source registry schema")
    sources = registry.get("sources")
    if not isinstance(sources, list) or not sources:
        raise ValueError("source registry must contain sources")
    by_source = _unique_by(sources, "sourceId", "source")

    for source_id, source in by_source.items():
        license_info = source.get("license")
        if not isinstance(license_info, dict) or not all(
            license_info.get(field) for field in ("expression", "name", "url")
        ):
            raise ValueError(f"{source_id}: complete license metadata is required")
        uses = source.get("allowedUses")
        if not isinstance(uses, list) or not uses or len(uses) != len(set(uses)):
            raise ValueError(f"{source_id}: allowedUses must be a non-empty unique list")
        acquisition = source.get("acquisition")
        if not isinstance(acquisition, dict):
            raise ValueError(f"{source_id}: acquisition policy is required")
        automated = acquisition.get("automatedImport") is True
        if automated and source_id not in AUTO_IMPORT_ALLOWLIST:
            raise ValueError(f"{source_id}: automated import is not allowlisted")
        if automated != (acquisition.get("mode") == "pinned_auto_import"):
            raise ValueError(f"{source_id}: automated import mode is inconsistent")

    if source_lock.get("schemaVersion") != 1:
        raise ValueError("unsupported source lock schema")
    locks = source_lock.get("locks")
    if not isinstance(locks, list) or not locks:
        raise ValueError("source lock must contain locks")
    by_lock = _unique_by(locks, "lockId", "source lock")
    for lock_id, lock in by_lock.items():
        if lock.get("sourceId") not in by_source:
            raise ValueError(f"{lock_id}: unknown sourceId")
        revision = lock.get("revision")
        if not isinstance(revision, dict) or not all(
            revision.get(field) for field in ("kind", "id", "permalink")
        ):
            raise ValueError(f"{lock_id}: source revision is required")
        digest = lock.get("contentSha256")
        if not isinstance(digest, str) or not SHA256.fullmatch(digest):
            raise ValueError(f"{lock_id}: invalid content SHA-256")
        legacy = revision.get("kind") == "unlocked_legacy"
        if release and (legacy or digest == "0" * 64):
            raise ValueError(f"{lock_id}: unlocked legacy source cannot be released")

    if pack.get("schemaVersion") != 1:
        raise ValueError("unsupported fact pack schema")
    if not pack.get("licenseExpression"):
        raise ValueError("fact pack licenseExpression is required")
    facts = pack.get("facts")
    if not isinstance(facts, list) or not facts:
        raise ValueError("fact pack must contain facts")
    by_fact = _unique_by(facts, "factId", "fact")
    pack_games = set(pack.get("games") or [])
    for fact_id, fact in by_fact.items():
        lock_ids = fact.get("sourceLockIds")
        if not isinstance(lock_ids, list) or not lock_ids:
            raise ValueError(f"{fact_id}: sourceLockIds are required")
        unknown = set(lock_ids) - by_lock.keys()
        if unknown:
            raise ValueError(f"{fact_id}: unknown source locks {sorted(unknown)}")
        if not set(fact.get("games") or []).issubset(pack_games):
            raise ValueError(f"{fact_id}: fact games are outside the pack")

        authoring = fact.get("authoring")
        if not isinstance(authoring, dict) or not authoring.get("authorIds"):
            raise ValueError(f"{fact_id}: authoring fields are required")
        method = authoring.get("method")
        copied = authoring.get("copiedText")
        required_use = {
            "titodex_original": "fact_check",
            "structured_import": "structured_data",
            "licensed_text_adaptation": "text_adaptation",
        }.get(method)
        if required_use is None or not isinstance(copied, bool):
            raise ValueError(f"{fact_id}: invalid authoring method")
        if method == "titodex_original" and copied:
            raise ValueError(f"{fact_id}: original fact cannot declare copied text")
        if method == "licensed_text_adaptation" and not copied:
            raise ValueError(f"{fact_id}: adapted text must declare copied text")
        for lock_id in lock_ids:
            source = by_source[by_lock[lock_id]["sourceId"]]
            if required_use not in source["allowedUses"]:
                raise ValueError(
                    f"{fact_id}: source {source['sourceId']} does not allow {required_use}"
                )
            if (
                fact.get("allowedForAiIndex") is True
                and method != "titodex_original"
                and "ai_index" not in source["allowedUses"]
            ):
                raise ValueError(f"{fact_id}: imported/adapted source forbids AI indexing")

        review = fact.get("review")
        if not isinstance(review, dict) or not all(
            field in review
            for field in ("status", "reviewerIds", "reviewedAt", "fixtureIds", "notes")
        ):
            raise ValueError(f"{fact_id}: review fields are required")
        if fact.get("allowedForAiIndex") is not False and review.get("status") != "approved":
            raise ValueError(f"{fact_id}: only approved facts may be AI indexed")
        if release and (
            review.get("status") != "approved"
            or not review.get("reviewerIds")
            or not review.get("reviewedAt")
        ):
            raise ValueError(f"{fact_id}: approved reviewer sign-off is required")


def _unique_by(items: list, key: str, label: str) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for item in items:
        if not isinstance(item, dict) or not item.get(key):
            raise ValueError(f"{label}: {key} is required")
        value = item[key]
        if value in result:
            raise ValueError(f"duplicate {label} {value}")
        result[value] = item
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--lock", type=Path, default=DEFAULT_LOCK)
    parser.add_argument("--pack", type=Path, action="append")
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    registry = load_json(args.registry)
    source_lock = load_json(args.lock)
    for pack_path in args.pack or default_fact_packs():
        validate_supply_chain(
            registry,
            source_lock,
            load_json(pack_path),
            release=args.release,
        )


if __name__ == "__main__":
    main()
