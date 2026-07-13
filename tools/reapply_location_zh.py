#!/usr/bin/env python3
"""Re-run location_zh_resolver on existing location_areas.json (no PokeAPI)."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N_DIR = ROOT / "data" / "l10n" / "zh"
AREAS_PATH = L10N_DIR / "location_areas.json"
UNRESOLVED_PATH = L10N_DIR / "location_areas_unresolved.json"
MANIFEST_PATH = L10N_DIR / "manifest.json"

UNRESOLVED_SOURCES = frozenset(
    {
        "english_fallback",
        "slug_title",
        "slug_title_name",
    }
)


def main() -> int:
    sys.path.insert(0, str(ROOT / "tools"))
    from location_zh_resolver import (  # noqa: WPS433
        load_location_names_en_zh,
        load_slug_overrides,
        resolve_location_area_zh,
    )

    if not AREAS_PATH.is_file():
        print(f"ERROR: missing {AREAS_PATH}", file=sys.stderr)
        return 1

    slug_overrides = load_slug_overrides()
    names_en_zh = load_location_names_en_zh()
    areas: dict[str, dict] = json.loads(AREAS_PATH.read_text(encoding="utf-8"))

    unresolved: list[str] = []
    changed = 0
    for slug, entry in areas.items():
        label_zh, source = resolve_location_area_zh(
            slug,
            area_name_en=entry.get("areaNameEn"),
            location_name_en=entry.get("locationNameEn"),
            slug_overrides=slug_overrides,
            names_en_zh=names_en_zh,
        )
        if source in UNRESOLVED_SOURCES:
            unresolved.append(slug)
        prev_label = entry.get("labelZh")
        prev_source = entry.get("source")
        if prev_label != label_zh or prev_source != source:
            changed += 1
        entry["labelZh"] = label_zh
        entry["source"] = source

    unresolved.sort()
    AREAS_PATH.write_text(
        json.dumps(areas, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    UNRESOLVED_PATH.write_text(
        json.dumps({"slugs": unresolved}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    manifest: dict = {}
    if MANIFEST_PATH.is_file():
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    counts = manifest.setdefault("counts", {})
    counts["locationAreas"] = len(areas)
    counts["locationAreasUnresolved"] = len(unresolved)
    manifest["generatedAt"] = datetime.now(timezone.utc).isoformat()
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(
        f"Reapplied zh labels: {len(areas)} areas, "
        f"{len(unresolved)} unresolved ({changed} entries changed)",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
