#!/usr/bin/env python3
"""Audit per-game encounter coverage and Chinese location labels in a dex bundle."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG = ROOT / "data" / "l10n" / "zh" / "location_areas.json"
UNRESOLVED_SOURCES = {"english_fallback"}
CHINESE_RE = re.compile(r"[\u3400-\u9fff]")
REQUIRED_MODERN_VERSIONS = {
    "brilliant-diamond",
    "shining-pearl",
    "legends-arceus",
    "sword",
    "shield",
    "the-isle-of-armor-sword",
    "the-isle-of-armor-shield",
    "the-crown-tundra-sword",
    "the-crown-tundra-shield",
    "scarlet",
    "violet",
    "the-teal-mask-scarlet",
    "the-teal-mask-violet",
    "the-indigo-disk-scarlet",
    "the-indigo-disk-violet",
    "legends-za",
    "mega-dimension",
}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def is_unresolved_label(slug: str, label: str, source: str | None) -> bool:
    return (
        not label
        or label == slug
        or label.isdigit()
        or source in UNRESOLVED_SOURCES
        or CHINESE_RE.search(label) is None
    )


def audit(bundle_dir: Path, catalog_path: Path) -> dict[str, Any]:
    details_dir = bundle_dir / "details"
    games_path = bundle_dir / "games.json"
    if not details_dir.is_dir() or not games_path.is_file():
        raise ValueError(f"expected extracted bundle root with details/ and games.json: {bundle_dir}")

    catalog = load_json(catalog_path) if catalog_path.is_file() else {}
    catalog_by_id = {
        str(entry["id"]): (slug, entry)
        for slug, entry in catalog.items()
        if isinstance(entry, dict) and entry.get("id") is not None
    }
    games = load_json(games_path)
    group_order = [
        game["versionGroup"]
        for game in games
        if game.get("versionGroup") and game.get("encounterVersions")
    ]
    group_labels = {
        game["versionGroup"]: game["labelZh"]
        for game in games
        if game.get("versionGroup")
    }

    stats: dict[str, dict[str, Any]] = {
        group: {
            "versionGroup": group,
            "labelZh": group_labels.get(group, group),
            "speciesWithLocations": 0,
            "locationEntries": 0,
            "distinctAreaSlugs": set(),
            "unresolvedAreaSlugs": set(),
            "formLinkedEntries": 0,
            "formAmbiguousEntries": 0,
            "formIdentityMismatchEntries": 0,
            "teraEntries": 0,
            "specialStateEntries": 0,
        }
        for group in group_order
    }
    referenced_slugs: set[str] = set()
    source_counts: Counter[str] = Counter()
    unknown_groups: Counter[str] = Counter()
    detail_count = 0
    exact_version_counts: Counter[str] = Counter()
    observed_labels: defaultdict[str, set[str]] = defaultdict(set)

    for detail_path in sorted(details_dir.glob("*.json")):
        detail = load_json(detail_path)
        detail_count += 1
        by_game = detail.get("obtainLocationsByGame") or {}
        for version, locations in (detail.get("obtainLocationsByVersion") or {}).items():
            exact_version_counts[version] += len(locations)
        for group, locations in by_game.items():
            if group not in stats:
                unknown_groups[group] += 1
                continue
            if locations:
                stats[group]["speciesWithLocations"] += 1
            stats[group]["locationEntries"] += len(locations)
            for entry in locations:
                form_key = entry.get("formKey") or entry.get("formSlug")
                pokemon_id = entry.get("pokemonId")
                form_ambiguous = bool(entry.get("formAmbiguous")) or (
                    pokemon_id is None and not form_key
                )
                if pokemon_id is not None and form_key:
                    stats[group]["formLinkedEntries"] += 1
                if form_ambiguous:
                    stats[group]["formAmbiguousEntries"] += 1
                elif (pokemon_id is None) != (not form_key):
                    stats[group]["formIdentityMismatchEntries"] += 1
                if entry.get("teraType"):
                    stats[group]["teraEntries"] += 1
                if any(
                    entry.get(key)
                    for key in (
                        "isAlpha",
                        "isTitan",
                        "isTotem",
                        "isRaid",
                        "isFixedEncounter",
                    )
                ):
                    stats[group]["specialStateEntries"] += 1
                slug = str(entry.get("areaSlug") or "")
                label = str(entry.get("areaLabelZh") or "")
                if not slug:
                    continue
                referenced_slugs.add(slug)
                if label:
                    observed_labels[slug].add(label)
                stats[group]["distinctAreaSlugs"].add(slug)
                catalog_match = catalog_by_id.get(slug)
                canonical_slug = catalog_match[0] if catalog_match else slug
                catalog_entry = catalog.get(slug) or (catalog_match[1] if catalog_match else {})
                source = catalog_entry.get("source")
                effective_label = str(catalog_entry.get("labelZh") or label)
                source_counts[source or "missing_catalog"] += 1
                if is_unresolved_label(slug, effective_label, source):
                    stats[group]["unresolvedAreaSlugs"].add(canonical_slug)

    rows: list[dict[str, Any]] = []
    for group in group_order:
        row = stats[group]
        rows.append(
            {
                "versionGroup": group,
                "labelZh": row["labelZh"],
                "speciesWithLocations": row["speciesWithLocations"],
                "locationEntries": row["locationEntries"],
                "distinctAreaCount": len(row["distinctAreaSlugs"]),
                "unresolvedAreaCount": len(row["unresolvedAreaSlugs"]),
                "unresolvedAreaSlugs": sorted(row["unresolvedAreaSlugs"]),
                "formLinkedEntries": row["formLinkedEntries"],
                "formAmbiguousEntries": row["formAmbiguousEntries"],
                "formIdentityMismatchEntries": row["formIdentityMismatchEntries"],
                "teraEntries": row["teraEntries"],
                "specialStateEntries": row["specialStateEntries"],
            }
        )

    referenced_unresolved: list[dict[str, str]] = []
    for slug in referenced_slugs:
        catalog_match = catalog_by_id.get(slug)
        canonical_slug = catalog_match[0] if catalog_match else slug
        entry = catalog.get(slug) or (catalog_match[1] if catalog_match else {})
        observed_label = next(
            (
                label
                for label in sorted(observed_labels.get(slug, set()))
                if CHINESE_RE.search(label)
            ),
            "",
        )
        effective_label = str(entry.get("labelZh") or observed_label)
        if not is_unresolved_label(slug, effective_label, entry.get("source")):
            continue
        referenced_unresolved.append(
            {
                "slug": canonical_slug,
                "id": str(entry.get("id") or (slug if slug.isdigit() else "")),
                "areaNameEn": str(entry.get("areaNameEn") or ""),
                "locationNameEn": str(entry.get("locationNameEn") or ""),
                "labelZh": effective_label,
                "source": str(entry.get("source") or "missing_catalog"),
            }
        )
    referenced_unresolved.sort(key=lambda entry: entry["slug"])
    manifest_path = bundle_dir / "manifest.json"
    manifest = load_json(manifest_path) if manifest_path.is_file() else {}
    missing_required_versions = sorted(
        version for version in REQUIRED_MODERN_VERSIONS if exact_version_counts[version] <= 0
    )
    champions_not_applicable = "champions" in (
        (manifest.get("encounterCoverage") or {}).get("notApplicable") or []
    )
    return {
        "detailCount": detail_count,
        "gameGroups": rows,
        "referencedAreaCount": len(referenced_slugs),
        "referencedUnresolvedAreaCount": len(referenced_unresolved),
        "referencedUnresolvedAreas": referenced_unresolved,
        "catalogSourceReferenceCounts": dict(sorted(source_counts.items())),
        "unknownGroups": dict(sorted(unknown_groups.items())),
        "exactVersionEntryCounts": dict(sorted(exact_version_counts.items())),
        "missingRequiredModernVersions": missing_required_versions,
        "championsNotApplicable": champions_not_applicable,
        "ok": not referenced_unresolved
        and not missing_required_versions
        and champions_not_applicable,
    }


def print_table(report: dict[str, Any]) -> None:
    print(
        "version group                            species  entries  areas  unresolved  linked  ambiguous"
    )
    print("-" * 99)
    for row in report["gameGroups"]:
        print(
            f"{row['versionGroup']:<40}"
            f"{row['speciesWithLocations']:>7}"
            f"{row['locationEntries']:>9}"
            f"{row['distinctAreaCount']:>7}"
            f"{row['unresolvedAreaCount']:>12}"
            f"{row['formLinkedEntries']:>8}"
            f"{row['formAmbiguousEntries']:>11}"
        )
    print()
    print(
        f"details={report['detailCount']} "
        f"referenced areas={report['referencedAreaCount']} "
        f"unresolved referenced areas={report['referencedUnresolvedAreaCount']}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", type=Path, help="Extracted bundle root")
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    report = audit(args.bundle_dir, args.catalog)
    if args.as_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print_table(report)
    return 1 if args.strict and not report["ok"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
