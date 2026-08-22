#!/usr/bin/env python3
"""Strictly verify a local Dex bundle v20 candidate without publishing it."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import tarfile
from pathlib import Path
from typing import Any, Iterable

import zstandard

from build_dex_v20_candidate import (
    ARCHIVE_NAME,
    BASE_BUNDLE_VERSION,
    BUNDLE_VERSION,
    CDN_PREFIX,
    build_entity_index,
    read_json,
    sha256_file,
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _walk_values(payload: Any, key: str) -> Iterable[Any]:
    if isinstance(payload, dict):
        for child_key, value in payload.items():
            if child_key == key:
                yield value
            yield from _walk_values(value, key)
    elif isinstance(payload, list):
        for value in payload:
            yield from _walk_values(value, key)


def _verify_archive(staging: Path, archive: Path) -> None:
    expected = {
        path.relative_to(staging).as_posix(): sha256_file(path)
        for path in staging.rglob("*")
        if path.is_file()
    }
    seen: dict[str, str] = {}
    with archive.open("rb") as raw:
        with zstandard.ZstdDecompressor().stream_reader(raw) as decompressed:
            with tarfile.open(fileobj=decompressed, mode="r|") as bundle:
                for member in bundle:
                    require(member.isfile(), f"archive contains non-file member: {member.name}")
                    path = Path(member.name)
                    require(
                        not path.is_absolute() and ".." not in path.parts,
                        f"unsafe archive member: {member.name}",
                    )
                    extracted = bundle.extractfile(member)
                    require(extracted is not None, f"cannot read archive member: {member.name}")
                    digest = hashlib.sha256()
                    for chunk in iter(lambda: extracted.read(1024 * 1024), b""):
                        digest.update(chunk)
                    require(member.name not in seen, f"duplicate archive member: {member.name}")
                    seen[member.name] = digest.hexdigest()
    require(set(seen) == set(expected), "archive file list does not mirror staging")
    mismatches = sorted(name for name in expected if expected[name] != seen[name])
    require(not mismatches, f"archive content mismatches: {mismatches[:10]}")


def _verify_provenance(staging: Path, payload: dict[str, Any]) -> None:
    require(payload.get("schemaVersion") == 1, "unsupported provenance schema")
    require(payload.get("bundleVersion") == BUNDLE_VERSION, "provenance version mismatch")
    sources = payload.get("sources")
    rules = payload.get("objects")
    require(isinstance(sources, dict) and sources, "provenance sources are empty")
    require(isinstance(rules, list) and rules, "provenance object rules are empty")

    for source_id, source in sources.items():
        require(isinstance(source, dict), f"invalid source: {source_id}")
        required = {
            "title",
            "kind",
            "revision",
            "license",
            "attributionRequired",
            "noticePaths",
        }
        require(required <= set(source), f"source {source_id} is incomplete")
        notices = source.get("noticePaths")
        require(isinstance(notices, list), f"source {source_id} notices must be an array")
        if source.get("attributionRequired"):
            require(bool(notices), f"source {source_id} requires an attribution notice")
        for notice in notices:
            notice_path = staging / str(notice)
            require(notice_path.is_file(), f"missing attribution notice: {notice}")
            require(notice_path.stat().st_size > 0, f"empty attribution notice: {notice}")

    def verify_evidence(evidence: Any, where: str) -> None:
        require(isinstance(evidence, dict), f"invalid provenance evidence at {where}")
        source_ids = evidence.get("sourceIds")
        require(isinstance(source_ids, list) and source_ids, f"missing source IDs at {where}")
        unknown = sorted(set(source_ids) - set(sources))
        require(not unknown, f"unknown provenance sources at {where}: {unknown}")
        scope = evidence.get("scope")
        freshness = evidence.get("freshness")
        require(isinstance(scope, dict) and scope.get("level"), f"missing scope at {where}")
        scope_requirements = {
            "exactGame": "gameSlugs",
            "versionGroup": "versionGroups",
            "generation": "generations",
        }
        scope_key = scope_requirements.get(scope.get("level"))
        if scope_key:
            require(
                isinstance(scope.get(scope_key), list) and bool(scope[scope_key]),
                f"scope {scope.get('level')} lacks {scope_key} at {where}",
            )
        require(isinstance(freshness, dict), f"missing freshness at {where}")
        require(freshness.get("checkedAt"), f"missing freshness check time at {where}")
        require(freshness.get("fallbackPolicy"), f"missing fallback policy at {where}")
        if freshness.get("status") in {"current", "dated", "inherited"}:
            require(freshness.get("sourceAsOf"), f"missing sourceAsOf at {where}")

    for index, rule in enumerate(rules):
        require(isinstance(rule, dict), f"invalid provenance rule #{index}")
        pattern = rule.get("pathPattern")
        require(isinstance(pattern, str) and pattern, f"missing path pattern #{index}")
        require(isinstance(rule.get("priority"), int), f"missing rule priority #{index}")
        verify_evidence(rule.get("metadata"), f"rule {pattern}")
        fields = rule.get("fields")
        require(isinstance(fields, list), f"invalid field rules for {pattern}")
        for field in fields:
            require(
                isinstance(field, dict)
                and str(field.get("pointerPattern") or "").startswith("/"),
                f"invalid field pointer for {pattern}",
            )
            verify_evidence(field.get("metadata"), f"{pattern}{field['pointerPattern']}")

    data_files = sorted(
        path.relative_to(staging).as_posix()
        for path in staging.rglob("*.json")
    )
    unmatched = [
        path
        for path in data_files
        if not any(fnmatch.fnmatchcase(path, str(rule["pathPattern"])) for rule in rules)
    ]
    require(not unmatched, f"JSON objects without provenance: {unmatched[:10]}")

    for sensitive in ("moves.json", "abilities.json", "items.json"):
        matching = [
            rule
            for rule in rules
            if fnmatch.fnmatchcase(sensitive, str(rule["pathPattern"]))
        ]
        chosen = max(matching, key=lambda rule: int(rule["priority"]))
        policy = chosen["metadata"]["freshness"]["fallbackPolicy"]
        require(
            policy in {"local-evidence", "online-verify", "offline-warning"},
            f"version-sensitive {sensitive} must not be globally local-authoritative",
        )


def _verify_entity_index(staging: Path, payload: dict[str, Any]) -> None:
    require(payload.get("schemaVersion") == 1, "unsupported entity index schema")
    require(payload.get("bundleVersion") == BUNDLE_VERSION, "entity index version mismatch")
    entities = payload.get("entities")
    require(isinstance(entities, list), "entity index entities must be an array")
    stable_ids = [entity.get("stableId") for entity in entities]
    require(len(stable_ids) == len(set(stable_ids)), "duplicate stable entity IDs")
    expected = build_entity_index(staging, generated_at=str(payload.get("generatedAt")))
    require(payload == expected, "entity index is stale relative to final runtime data/l10n")

    expected_kinds = {"pokemon", "move", "ability", "item"}
    require(
        set(payload["audit"]["runtimeCounts"]) == expected_kinds,
        "entity index runtime kinds are incomplete",
    )
    for entity in entities:
        require(entity.get("kind") in expected_kinds, "invalid entity kind")
        require(str(entity.get("nameZh") or "").strip() != "", "empty Chinese entity name")
        require(str(entity.get("nameEn") or "").strip() != "", "empty English entity name")
        if entity["kind"] == "item":
            require(
                entity["stableId"] == f"item:{entity['slug']}",
                "item stable IDs must use their slug",
            )
        else:
            require(
                entity["stableId"] == f"{entity['kind']}:{entity['id']}",
                f"{entity['kind']} stable IDs must use numeric IDs",
            )
        ref = entity.get("ref") or {}
        ref_path = staging / str(ref.get("path") or "")
        pointer = str(ref.get("pointer") or "")
        require(ref_path.is_file(), f"entity ref path is missing: {ref_path}")
        require(pointer.startswith("/"), f"entity ref pointer is invalid: {pointer}")
        target = read_json(ref_path)
        token = pointer[1:].replace("~1", "/").replace("~0", "~")
        try:
            resolved = target[int(token)] if isinstance(target, list) else target[token]
        except (IndexError, KeyError, TypeError, ValueError) as exc:
            raise ValueError(f"entity ref cannot be resolved: {entity['stableId']}") from exc
        require(
            int(resolved.get("id") or entity["id"]) == entity["id"],
            f"entity ref resolves to the wrong record: {entity['stableId']}",
        )


def _verify_runtime_relations(staging: Path) -> None:
    summaries = read_json(staging / "summaries.json")
    catalog = read_json(staging / "dex_catalog.json")
    moves = read_json(staging / "moves.json")
    abilities = read_json(staging / "abilities.json")
    items = read_json(staging / "items.json")
    require(isinstance(summaries, list), "summaries.json must be an array")
    species_ids = {int(summary["id"]) for summary in summaries}
    require(len(species_ids) == len(summaries), "duplicate species IDs")
    require(catalog.get("summaries") == summaries, "dex_catalog summaries are stale")
    require(catalog.get("moves") == moves, "dex_catalog moves are stale")
    require(catalog.get("abilities") == abilities, "dex_catalog abilities are stale")

    move_ids = {int(move_id) for move_id in moves}
    ability_ids = {int(ability_id) for ability_id in abilities}
    item_slugs = {str(item.get("slug")) for item in items.values()}
    ability_names = {
        str(ability.get("nameEn") or "").casefold()
        for ability in abilities.values()
    } | {
        str(ability.get("nameZh") or "").casefold()
        for ability in abilities.values()
    }

    detail_paths = sorted((staging / "details").glob("*.json"))
    require(len(detail_paths) == len(summaries), "detail count does not match summaries")
    summaries_by_id = {int(row["id"]): row for row in summaries}
    referenced_moves: set[int] = set()
    for path in detail_paths:
        species_id = int(path.stem)
        require(species_id in species_ids, f"orphan detail: {path.name}")
        detail = read_json(path)
        require(
            detail.get("summary") == summaries_by_id[species_id],
            f"detail summary drift: {path.name}",
        )
        for raw in _walk_values(detail, "moveId"):
            move_id = int(raw)
            referenced_moves.add(move_id)
            require(move_id in move_ids, f"unknown move #{move_id} in {path.name}")
        for held in detail.get("heldItems") or []:
            slug = str(held.get("slug") or "")
            require(slug in item_slugs, f"unknown held item {slug!r} in {path.name}")
        for ability in detail.get("abilities") or []:
            names = {
                str(ability.get("nameEn") or "").casefold(),
                str(ability.get("nameZh") or "").casefold(),
            }
            require(bool(names & ability_names), f"unknown ability in {path.name}: {ability}")
        for raw in _walk_values(detail.get("evolutionChain"), "id"):
            require(int(raw) in species_ids, f"unknown evolution species #{raw} in {path.name}")

    for move_id, learners in (catalog.get("moveLearners") or {}).items():
        require(int(move_id) in move_ids, f"moveLearners references unknown move #{move_id}")
        unknown = sorted(set(map(int, learners)) - species_ids)
        require(not unknown, f"moveLearners #{move_id} has unknown species: {unknown[:10]}")
    for ability_id, pokemon_ids in (catalog.get("abilityPokemonIds") or {}).items():
        require(int(ability_id) in ability_ids, f"ability index references unknown #{ability_id}")
        unknown = sorted(set(map(int, pokemon_ids)) - species_ids)
        require(not unknown, f"ability #{ability_id} has unknown species: {unknown[:10]}")
    for ability_id, ability in abilities.items():
        unknown = sorted(set(map(int, ability.get("pokemonIds") or [])) - species_ids)
        require(not unknown, f"ability #{ability_id} has unknown pokemonIds: {unknown[:10]}")

    games = read_json(staging / "games.json")
    version_groups = {str(game["versionGroup"]) for game in games}
    move_matrix_path = staging / "move_version_matrix.json"
    if move_matrix_path.is_file():
        matrix = read_json(move_matrix_path)
        for move_id, groups in (matrix.get("moves") or {}).items():
            require(int(move_id) in move_ids, f"move matrix references unknown move #{move_id}")
            unknown = sorted(set(map(str, groups)) - version_groups)
            require(not unknown, f"move #{move_id} has unknown version groups: {unknown}")
    item_matrix_path = staging / "item_version_matrix.json"
    if item_matrix_path.is_file():
        matrix = read_json(item_matrix_path)
        for item_id, entry in (matrix.get("items") or {}).items():
            require(str(item_id) in items, f"item matrix references unknown item #{item_id}")
            unknown = sorted(set(map(str, entry.get("versionGroups") or [])) - version_groups)
            require(not unknown, f"item #{item_id} has unknown version groups: {unknown}")


def verify_candidate(root: Path) -> dict[str, Any]:
    staging = root / "staging"
    versioned = root / "upload" / CDN_PREFIX
    pending_path = root / "release-manifest" / "bundle-manifest.v20.candidate.json"
    require(staging.is_dir(), "candidate staging directory is missing")
    require(versioned.is_dir(), "candidate v5 upload directory is missing")
    require(pending_path.is_file(), "pending v20 manifest is missing")
    require(
        not (root / "upload" / "bundle-manifest.json").exists(),
        "candidate must not contain a publishable root manifest",
    )

    manifest = read_json(staging / "manifest.json")
    pending = read_json(pending_path)
    require(manifest.get("version") == BUNDLE_VERSION, "staging is not v20")
    require(manifest.get("baseBundleVersion") == BASE_BUNDLE_VERSION, "v19 lineage missing")
    require(manifest.get("releaseState") == "candidate", "staging is not marked candidate")
    require(pending.get("bundleVersion") == BUNDLE_VERSION, "pending manifest is not v20")
    require(pending.get("baseBundleVersion") == BASE_BUNDLE_VERSION, "pending v19 lineage missing")
    require(pending.get("releaseState") == "candidate", "pending manifest is not candidate")
    require("archiveUrl" not in pending, "candidate manifest must not embed a production URL")
    require(pending.get("archiveFile") == ARCHIVE_NAME, "candidate archive name mismatch")
    require(manifest.get("schemaFeatures", {}).get("stableEntityIndex") == 1, "entity schema flag missing")
    require(manifest.get("schemaFeatures", {}).get("provenance") == 1, "provenance schema flag missing")

    summaries = read_json(staging / "summaries.json")
    if manifest.get("complete") is True:
        require(len(summaries) == 1025, "complete TitoDex bundle must contain 1025 species")
    require(manifest.get("pokemonCount") == len(summaries), "pokemonCount mismatch")
    require(manifest.get("moveCount") == len(read_json(staging / "moves.json")), "moveCount mismatch")
    require(manifest.get("abilityCount") == len(read_json(staging / "abilities.json")), "abilityCount mismatch")
    require(manifest.get("itemCount") == len(read_json(staging / "items.json")), "itemCount mismatch")

    _verify_runtime_relations(staging)
    entity_index = read_json(staging / "entity_index.json")
    _verify_entity_index(staging, entity_index)
    _verify_provenance(staging, read_json(staging / "provenance.json"))
    require(manifest.get("entityCounts") == entity_index["audit"]["runtimeCounts"], "manifest entity counts mismatch")

    archive = versioned / ARCHIVE_NAME
    require(archive.is_file(), "candidate archive is missing")
    require(pending.get("archiveSha256") == sha256_file(archive), "pending archive SHA mismatch")
    require(pending.get("archiveSizeBytes") == archive.stat().st_size, "pending archive size mismatch")
    _verify_archive(staging, archive)

    loose_files = {
        path.relative_to(versioned).as_posix(): sha256_file(path)
        for path in versioned.rglob("*")
        if path.is_file() and path.name != ARCHIVE_NAME
    }
    staging_files = {
        path.relative_to(staging).as_posix(): sha256_file(path)
        for path in staging.rglob("*")
        if path.is_file()
    }
    require(loose_files == staging_files, "loose v5 objects do not mirror staging")

    attribution_files = sorted(staging.glob("*_ATTRIBUTION.txt"))
    require(attribution_files, "bundle has no attribution notices")
    require(all(path.stat().st_size > 0 for path in attribution_files), "empty attribution notice")
    return {
        "bundleVersion": BUNDLE_VERSION,
        "baseBundleVersion": BASE_BUNDLE_VERSION,
        "species": len(summaries),
        "entities": len(entity_index["entities"]),
        "phantomLabelCounts": manifest.get("phantomLabelCounts"),
        "duplicateNameGroups": len(entity_index["audit"]["duplicateNames"]),
        "archiveSha256": pending["archiveSha256"],
        "archiveSizeBytes": pending["archiveSizeBytes"],
        "publishableRootManifestPresent": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify_candidate(args.candidate), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
