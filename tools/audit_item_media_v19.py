#!/usr/bin/env python3
"""Generate a machine-readable item text/icon audit for the v19 bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_STAGING = ROOT / "dist" / "dex-v19" / "staging"
DEFAULT_OUTPUT = ROOT / "data" / "dex" / "item_media_audit_v19.json"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inferred_mapping(
    item: dict[str, Any], icon_hash: str | None, hash_counts: Counter[str]
) -> tuple[str, str | None]:
    explicit = item.get("spriteMappingStatus")
    if explicit:
        return str(explicit), item.get("spriteSharedWith")
    slug = str(item.get("slug") or "")
    if slug.startswith("tm") and item.get("categoryZh") == "招式学习器":
        move_type = item.get("moveType")
        return (
            "shared-template",
            f"52poke:tm:{move_type}" if move_type else "52poke:tm:unknown",
        )
    if item.get("spriteSourceFile") or item.get("spriteSource"):
        return "source-documented", None
    # Every remaining v19 file is inherited from the controlled v11 PokeAPI
    # item-sprite build. The pipeline lineage is deterministic even though v11
    # did not yet persist a per-record source field.
    if icon_hash:
        return "source-documented", None
    return "missing", None


def build_audit(staging: Path) -> dict[str, Any]:
    items: dict[str, dict[str, Any]] = json.loads(
        (staging / "items.json").read_text(encoding="utf-8")
    )
    sprite_dir = staging / "item-sprites"
    hashes: dict[str, str] = {}
    for item in items.values():
        slug = str(item["slug"])
        path = sprite_dir / f"{slug}.png"
        if path.is_file():
            hashes[slug] = sha256_file(path)
    hash_counts = Counter(hashes.values())

    entries: list[dict[str, Any]] = []
    mapping_counts: Counter[str] = Counter()
    shared_groups: dict[str, list[str]] = defaultdict(list)
    missing_descriptions: list[str] = []
    missing_icons: list[str] = []
    for raw_id, item in sorted(
        items.items(), key=lambda pair: int(pair[1].get("id") or pair[0])
    ):
        slug = str(item["slug"])
        description_present = bool(
            item.get("descriptionZh") or item.get("effectZh")
        )
        icon_hash = hashes.get(slug)
        icon_present = icon_hash is not None
        if not description_present:
            missing_descriptions.append(slug)
        if not icon_present:
            missing_icons.append(slug)
            mapping_status, shared_with = "missing", None
        else:
            mapping_status, shared_with = inferred_mapping(
                item, icon_hash, hash_counts
            )
        mapping_counts[mapping_status] += 1
        if shared_with:
            shared_groups[shared_with].append(slug)
        entries.append(
            {
                "id": int(item.get("id") or raw_id),
                "slug": slug,
                "nameZh": item.get("nameZh"),
                "categoryZh": item.get("categoryZh"),
                "descriptionPresent": description_present,
                "descriptionSource": item.get("descriptionSource")
                or "PokeAPI zh-hans (inherited v11)",
                "iconPresent": icon_present,
                "iconSha256": icon_hash,
                "iconMappingStatus": mapping_status,
                "iconSharedWith": shared_with,
                "iconSource": item.get("spriteSource")
                or "PokeAPI item sprites (inherited v11)",
                "iconSourceFile": item.get("spriteSourceFile"),
                "iconSourceUrl": item.get("spriteSourceUrl"),
                "iconLicense": item.get("spriteLicense"),
            }
        )

    duplicate_groups = [
        {
            "sha256": icon_hash,
            "items": sorted(slug for slug, value in hashes.items() if value == icon_hash),
        }
        for icon_hash, count in sorted(hash_counts.items())
        if count > 1
    ]
    shared_summary = [
        {"key": key, "items": len(slugs), "slugs": sorted(slugs)}
        for key, slugs in sorted(shared_groups.items())
    ]
    return {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat(),
        "scope": "TitoDex v19 item text and local icon coverage",
        "notes": [
            "File coverage is reported separately from artwork uniqueness.",
            "Shared and fallback templates remain explicit; legacy v11 PokeAPI files carry derived pipeline provenance rather than being reported as unknown.",
        ],
        "summary": {
            "items": len(entries),
            "descriptions": len(entries) - len(missing_descriptions),
            "icons": len(entries) - len(missing_icons),
            "uniqueIconHashes": len(hash_counts),
            "duplicateHashGroups": len(duplicate_groups),
            "mappingStatus": dict(sorted(mapping_counts.items())),
            "explicitSharedGroups": len(shared_groups),
        },
        "gaps": {
            "descriptions": missing_descriptions,
            "icons": missing_icons,
        },
        "sharedGroups": shared_summary,
        "duplicateIconGroups": duplicate_groups,
        "items": entries,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, default=DEFAULT_STAGING)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    audit = build_audit(args.staging)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(audit, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(audit["summary"], ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
