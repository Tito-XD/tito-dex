#!/usr/bin/env python3
"""Copy compact zh catalog slices into Flutter assets for runtime lookup."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "data" / "l10n" / "zh"
ASSET_DIR = ROOT / "flutter" / "assets" / "l10n" / "zh"


def main() -> int:
    if not (SRC / "location_areas.json").is_file():
        print("ERROR: run tools/fetch_zh_catalog.py first", flush=True)
        return 1

    ASSET_DIR.mkdir(parents=True, exist_ok=True)

    location_areas = json.loads((SRC / "location_areas.json").read_text(encoding="utf-8"))
    labels: dict[str, str] = {}
    id_to_slug: dict[str, str] = {}
    for slug, entry in location_areas.items():
        label = entry.get("labelZh")
        if not label:
            continue
        labels[slug] = label
        area_id = entry.get("id")
        if area_id:
            labels[str(area_id)] = label
            id_to_slug[str(area_id)] = slug

    (ASSET_DIR / "location_area_labels.json").write_text(
        json.dumps(labels, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (ASSET_DIR / "location_area_id_to_slug.json").write_text(
        json.dumps(id_to_slug, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    # Compact entity lookups for runtime fallback (nameEn + nameZh).
    for name in ("moves", "abilities", "items", "species"):
        src = SRC / f"{name}.json"
        if not src.is_file():
            continue
        data = json.loads(src.read_text(encoding="utf-8"))
        compact = {
            key: {"en": v.get("nameEn", ""), "zh": v.get("nameZh", "")}
            for key, v in data.items()
            if isinstance(v, dict)
        }
        (ASSET_DIR / f"{name}_labels.json").write_text(
            json.dumps(compact, ensure_ascii=False, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )

    hgss_src = SRC / "hgss_map_ids.json"
    if hgss_src.is_file():
        hgss = json.loads(hgss_src.read_text(encoding="utf-8"))
        hgss_labels = {mid: entry["labelZh"] for mid, entry in hgss.items()}
        (ASSET_DIR / "hgss_map_labels.json").write_text(
            json.dumps(hgss_labels, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    manifest = SRC / "manifest.json"
    if manifest.is_file():
        shutil.copy2(manifest, ASSET_DIR / "manifest.json")

    print(
        f"Wrote {len(labels)} location label keys "
        f"({len(location_areas)} slugs + ids) → {ASSET_DIR}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
