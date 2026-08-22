#!/usr/bin/env python3
"""Build the reference/gameplay v20 overlay consumed by the foundation builder.

This is a local-only composition step.  It derives candidate files from an
immutable v19 staging tree, copies only changed/new relative staging objects,
and writes ``overlay-provenance.json``.  It never writes a release manifest,
archive, production CDN object, or Worker resource.
"""

from __future__ import annotations

import argparse
import json
import shutil
import tempfile
from argparse import Namespace
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import build_dex_bundle_v20_gameplay as gameplay
import patch_dex_bundle_v20_reference as reference


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "dist" / "dex-v20-reference-overlay"
PKHEX_COMMIT = "5c9e949c9f0fa932a1b63511b32c2bee5ce75b4e"
REFERENCE_PATHS = (
    "moves.json",
    "abilities.json",
    "items.json",
    "types.json",
    "status_conditions.json",
    "weather.json",
    "terrains.json",
    "dex_catalog.json",
    "reference_v20_sources.json",
    "reference_v20_audit.json",
    "move_version_matrix.json",
    "item_version_matrix.json",
    "POKEAPI_API_DATA_ATTRIBUTION.txt",
)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def _safe_output(output: Path, base_staging: Path) -> None:
    resolved = output.resolve()
    base = base_staging.resolve()
    if resolved in {Path(resolved.anchor), Path.home().resolve(), ROOT.resolve()}:
        raise ValueError("Refusing broad overlay output path")
    if resolved == base or resolved in base.parents or base in resolved.parents:
        raise ValueError("Overlay output and immutable v19 staging must not overlap")
    if (resolved / ".git").exists():
        raise ValueError("Refusing to replace a Git worktree")


def evidence(
    *,
    source_ids: list[str],
    method: str,
    confidence: str,
    level: str,
    checked_at: str,
    freshness_class: str,
    fallback: str,
    game_slugs: list[str] | None = None,
    version_groups: list[str] | None = None,
    generations: list[int] | None = None,
) -> dict[str, Any]:
    scope: dict[str, Any] = {"level": level}
    if game_slugs:
        scope["gameSlugs"] = game_slugs
    if version_groups:
        scope["versionGroups"] = version_groups
    if generations:
        scope["generations"] = generations
    return {
        "sourceIds": source_ids,
        "method": method,
        "confidence": confidence,
        "scope": scope,
        "freshness": {
            "class": freshness_class,
            "status": "current",
            "sourceAsOf": checked_at,
            "checkedAt": checked_at,
            "maxAgeDays": None,
            "fallbackPolicy": fallback,
        },
    }


def object_rule(
    path_pattern: str, priority: int, metadata: dict[str, Any]
) -> dict[str, Any]:
    return {
        "pathPattern": path_pattern,
        "priority": priority,
        "metadata": metadata,
        "fields": [],
    }


def build_provenance(*, generated_at: str, version_keys: dict[str, Any]) -> dict[str, Any]:
    source_lock = read_json(reference.SOURCE_LOCK)
    pokeapi = next(
        row for row in source_lock["sources"] if row["sourceId"] == "pokeapi-api-data"
    )
    gameplay_lock = read_json(gameplay.GAMEPLAY_SOURCE_LOCK)
    pkhex = next(
        row
        for row in gameplay_lock["sources"]
        if row["sourceId"] == "pkhex-overlay"
    )
    if pkhex["commit"] != PKHEX_COMMIT:
        raise ValueError("Gameplay source lock PKHeX commit is not the reviewed revision")
    groups = [row["key"] for row in version_keys["canonicalGroups"]]
    exact_versions = sorted(
        version
        for row in version_keys["canonicalGroups"]
        for version in row["exactVersions"]
    )
    progression_hints = read_json(gameplay.PROGRESSION_HINTS)
    progression_games = sorted(
        {
            game
            for entry in progression_hints["entries"]
            if any(
                requirement.get("type") == "key_item"
                for requirement in entry.get("requirements") or []
            )
            for game in entry["games"]
        }
    )
    versioned = evidence(
        source_ids=["pokeapi-api-data-v20", "titodex-v19-matrices-v20"],
        method="normalized",
        confidence="medium",
        level="versionGroup",
        version_groups=groups,
        checked_at=generated_at,
        freshness_class="versionSensitive",
        fallback="online-verify",
    )
    mechanics = evidence(
        source_ids=["titodex-reviewed-mechanics-v20"],
        method="reviewed",
        confidence="high",
        level="generation",
        generations=list(range(1, 10)),
        checked_at=generated_at,
        freshness_class="historical",
        fallback="local-evidence",
    )
    type_mechanics = evidence(
        source_ids=["pokeapi-api-data-v20", "titodex-reviewed-mechanics-v20"],
        method="normalized",
        confidence="high",
        level="generation",
        generations=list(range(1, 10)),
        checked_at=generated_at,
        freshness_class="historical",
        fallback="local-evidence",
    )
    obtain = evidence(
        source_ids=["pokeapi-api-data-v20", "pkhex-encounters-v20"],
        method="normalized",
        confidence="high",
        level="exactGame",
        game_slugs=exact_versions,
        checked_at=generated_at,
        freshness_class="versionSensitive",
        fallback="online-verify",
    )
    progression = evidence(
        source_ids=["titodex-reviewed-progression-v20"],
        method="reviewed",
        confidence="medium",
        level="exactGame",
        game_slugs=progression_games,
        checked_at=generated_at,
        freshness_class="historical",
        fallback="local-evidence",
    )
    generated = evidence(
        source_ids=["titodex-reference-generator-v20"],
        method="generated",
        confidence="high",
        level="unscoped",
        checked_at=generated_at,
        freshness_class="immutable",
        fallback="local-authoritative",
    )
    return {
        "schemaVersion": 1,
        "overlayId": "reference-gameplay-v20",
        "baseBundleVersion": 19,
        "sources": {
            "pokeapi-api-data-v20": {
                "title": "PokéAPI api-data (pinned)",
                "kind": "upstream",
                "revision": pokeapi["commit"],
                "retrievedAt": generated_at,
                "license": pokeapi["license"],
                "attributionRequired": True,
                "noticePaths": ["POKEAPI_API_DATA_ATTRIBUTION.txt"],
            },
            "pkhex-encounters-v20": {
                "title": "PKHeX encounter overlays (normalized, pinned)",
                "kind": "derived",
                "revision": pkhex["commit"],
                "retrievedAt": generated_at,
                "license": pkhex["license"],
                "attributionRequired": True,
                "noticePaths": ["PKHEX_ATTRIBUTION.md"],
            },
            "titodex-reviewed-mechanics-v20": {
                "title": "TitoDex reviewed mechanics",
                "kind": "manual",
                "revision": "reference-mechanics-schema-v1",
                "retrievedAt": generated_at,
                "license": "project-authored",
                "attributionRequired": False,
                "noticePaths": [],
            },
            "titodex-v19-matrices-v20": {
                "title": "TitoDex v19 audited version matrices",
                "kind": "bundle",
                "revision": "bundle-v19",
                "retrievedAt": generated_at,
                "license": "mixed; retained per-record source metadata",
                "attributionRequired": False,
                "noticePaths": [],
            },
            "titodex-reviewed-progression-v20": {
                "title": "TitoDex reviewed progression requirements",
                "kind": "manual",
                "revision": "dataset-v5",
                "retrievedAt": generated_at,
                "license": "project-authored facts with per-entry citations",
                "attributionRequired": False,
                "noticePaths": [],
            },
            "titodex-reference-generator-v20": {
                "title": "TitoDex reference/gameplay overlay generator",
                "kind": "derived",
                "revision": "overlay-schema-v1",
                "retrievedAt": generated_at,
                "license": "project source license",
                "attributionRequired": False,
                "noticePaths": [],
            },
        },
        "objects": [
            object_rule("moves.json", 50, versioned),
            object_rule("abilities.json", 50, versioned),
            object_rule("items.json", 50, versioned),
            object_rule("dex_catalog.json", 50, versioned),
            object_rule("move_version_matrix.json", 50, versioned),
            object_rule("item_version_matrix.json", 50, versioned),
            object_rule("types.json", 50, type_mechanics),
            object_rule("status_conditions.json", 50, mechanics),
            object_rule("weather.json", 50, mechanics),
            object_rule("terrains.json", 50, mechanics),
            object_rule("reference_v20_sources.json", 55, generated),
            object_rule("reference_v20_audit.json", 55, generated),
            object_rule("gameplay/obtain_methods.json", 60, obtain),
            object_rule("gameplay/evolution_methods.json", 60, versioned),
            object_rule("gameplay/learn_methods.json", 60, versioned),
            object_rule("gameplay/item_story_usage.json", 60, progression),
            object_rule("gameplay/version_coverage.json", 60, generated),
            object_rule("gameplay/game_version_keys.json", 60, generated),
            object_rule("gameplay/gameplay_sources.json", 60, generated),
            object_rule("gameplay/gameplay_v20_audit.json", 60, generated),
        ],
    }


def changed_from_base(candidate: Path, base: Path) -> bool:
    if not base.is_file():
        return True
    return candidate.read_bytes() != base.read_bytes()


def build_overlay(args: argparse.Namespace) -> dict[str, Any]:
    base_staging = args.base_staging.resolve()
    output = args.output.resolve()
    _safe_output(output, base_staging)
    base_manifest = read_json(base_staging / "manifest.json")
    if base_manifest.get("version") != 19 or base_manifest.get("complete") is not True:
        raise ValueError("Overlay requires an immutable complete v19 staging tree")
    generated_at = args.generated_at or datetime.now(timezone.utc).replace(
        microsecond=0
    ).isoformat()

    with tempfile.TemporaryDirectory(prefix="titodex-v20-reference-overlay-") as temp:
        candidate_root = Path(temp) / "candidate"
        reference.build(
            Namespace(
                base_staging=base_staging,
                base_root_manifest=args.base_root_manifest,
                api_data=args.api_data,
                source_lock=args.source_lock,
                mechanics=args.mechanics,
                output=candidate_root,
                published_at=generated_at,
                skip_archive=True,
            )
        )
        gameplay.build(
            Namespace(
                staging=candidate_root / "staging",
                api_data=args.api_data,
                source_lock=args.source_lock,
                gameplay_source_lock=args.gameplay_source_lock,
                version_keys=args.version_keys,
                progression_hints=args.progression_hints,
            )
        )

        if output.exists():
            shutil.rmtree(output)
        output.mkdir(parents=True)
        candidate_staging = candidate_root / "staging"
        copied: list[str] = []
        for relative in REFERENCE_PATHS:
            source = candidate_staging / relative
            if source.is_file() and changed_from_base(source, base_staging / relative):
                destination = output / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
                copied.append(relative)
        for source in sorted((candidate_staging / "gameplay").glob("*.json")):
            relative = source.relative_to(candidate_staging).as_posix()
            destination = output / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            copied.append(relative)
        pkhex_notice = candidate_staging / "PKHEX_ATTRIBUTION.md"
        if pkhex_notice.is_file():
            shutil.copy2(pkhex_notice, output / pkhex_notice.name)
            copied.append(pkhex_notice.name)

    provenance = build_provenance(
        generated_at=generated_at, version_keys=read_json(args.version_keys)
    )
    write_json(output / "overlay-provenance.json", provenance)
    report = {
        "overlayId": provenance["overlayId"],
        "baseBundleVersion": 19,
        "generatedAt": generated_at,
        "files": sorted(copied),
        "fileCount": len(copied),
        "containsManifest": any(Path(path).name == "manifest.json" for path in copied),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


def main() -> int:
    lock = read_json(reference.SOURCE_LOCK)
    source = next(
        row for row in lock["sources"] if row["sourceId"] == "pokeapi-api-data"
    )
    cache_home = Path.home() / ".cache"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-staging", type=Path, required=True)
    parser.add_argument(
        "--base-root-manifest", type=Path, default=reference.DEFAULT_BASE_ROOT_MANIFEST
    )
    parser.add_argument(
        "--api-data",
        type=Path,
        default=cache_home / "titodex" / "pokeapi-api-data" / source["commit"],
    )
    parser.add_argument("--source-lock", type=Path, default=reference.SOURCE_LOCK)
    parser.add_argument(
        "--gameplay-source-lock", type=Path, default=gameplay.GAMEPLAY_SOURCE_LOCK
    )
    parser.add_argument("--mechanics", type=Path, default=reference.MECHANICS_DATA)
    parser.add_argument("--version-keys", type=Path, default=gameplay.VERSION_KEYS)
    parser.add_argument(
        "--progression-hints", type=Path, default=gameplay.PROGRESSION_HINTS
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--generated-at")
    args = parser.parse_args()
    build_overlay(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
