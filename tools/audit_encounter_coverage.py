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
        }
        for group in group_order
    }
    referenced_slugs: set[str] = set()
    source_counts: Counter[str] = Counter()
    unknown_groups: Counter[str] = Counter()
    detail_count = 0

    for detail_path in sorted(details_dir.glob("*.json")):
        detail = load_json(detail_path)
        detail_count += 1
        by_game = detail.get("obtainLocationsByGame") or {}
        for group, locations in by_game.items():
            if group not in stats:
                unknown_groups[group] += 1
                continue
            if locations:
                stats[group]["speciesWithLocations"] += 1
            stats[group]["locationEntries"] += len(locations)
            for entry in locations:
                slug = str(entry.get("areaSlug") or "")
                label = str(entry.get("areaLabelZh") or "")
                if not slug:
                    continue
                referenced_slugs.add(slug)
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
            }
        )

    referenced_unresolved: list[dict[str, str]] = []
    for slug in referenced_slugs:
        catalog_match = catalog_by_id.get(slug)
        canonical_slug = catalog_match[0] if catalog_match else slug
        entry = catalog.get(slug) or (catalog_match[1] if catalog_match else {})
        if not is_unresolved_label(
            slug,
            str(entry.get("labelZh") or ""),
            entry.get("source"),
        ):
            continue
        referenced_unresolved.append(
            {
                "slug": canonical_slug,
                "id": str(entry.get("id") or (slug if slug.isdigit() else "")),
                "areaNameEn": str(entry.get("areaNameEn") or ""),
                "locationNameEn": str(entry.get("locationNameEn") or ""),
                "labelZh": str(entry.get("labelZh") or ""),
                "source": str(entry.get("source") or "missing_catalog"),
            }
        )
    referenced_unresolved.sort(key=lambda entry: entry["slug"])
    return {
        "detailCount": detail_count,
        "gameGroups": rows,
        "referencedAreaCount": len(referenced_slugs),
        "referencedUnresolvedAreaCount": len(referenced_unresolved),
        "referencedUnresolvedAreas": referenced_unresolved,
        "catalogSourceReferenceCounts": dict(sorted(source_counts.items())),
        "unknownGroups": dict(sorted(unknown_groups.items())),
    }


def print_table(report: dict[str, Any]) -> None:
    print(
        "version group                            species  entries  areas  unresolved"
    )
    print("-" * 79)
    for row in report["gameGroups"]:
        print(
            f"{row['versionGroup']:<40}"
            f"{row['speciesWithLocations']:>7}"
            f"{row['locationEntries']:>9}"
            f"{row['distinctAreaCount']:>7}"
            f"{row['unresolvedAreaCount']:>12}"
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
    args = parser.parse_args()

    report = audit(args.bundle_dir, args.catalog)
    if args.as_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print_table(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
