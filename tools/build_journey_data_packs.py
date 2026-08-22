#!/usr/bin/env python3
"""Build immutable per-game Journey packs and a Worker-served catalog."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from verify_journey_data_packs import MAX_PACK_BYTES, verify_candidate_dir

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "data" / "journey" / "progression_hints.json"

FAMILIES: dict[str, dict[str, Any]] = {
    "dpp": {"games": ["diamond", "pearl", "platinum"], "title": "钻石／珍珠／白金"},
    "hgss": {"games": ["heartgold", "soulsilver"], "title": "心金／魂银"},
    "bw": {"games": ["black", "white"], "title": "黑／白"},
    "bw2": {"games": ["black-2", "white-2"], "title": "黑2／白2"},
    "xy": {"games": ["x", "y"], "title": "X／Y"},
    "oras": {"games": ["omega-ruby", "alpha-sapphire"], "title": "欧米伽红宝石／阿尔法蓝宝石"},
    "sm": {"games": ["sun", "moon"], "title": "太阳／月亮"},
    "usum": {"games": ["ultra-sun", "ultra-moon"], "title": "究极之日／究极之月"},
    "swsh": {"games": ["sword", "shield"], "title": "剑／盾"},
    "bdsp": {"games": ["brilliant-diamond", "shining-pearl"], "title": "晶灿钻石／明亮珍珠"},
    "pla": {"games": ["legends-arceus"], "title": "传说 阿尔宙斯"},
    "sv": {"games": ["scarlet", "violet"], "title": "朱／紫"},
}


def _canonical_json(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def build_packs(source: Path, output: Path) -> dict[str, Any]:
    value = json.loads(source.read_text(encoding="utf-8"))
    if value.get("schemaVersion") != 1 or not isinstance(value.get("entries"), list):
        raise ValueError("unsupported progression hints")
    dataset_version = int(value.get("datasetVersion") or 0)
    if dataset_version < 1:
        raise ValueError("datasetVersion is required")
    entries: list[dict[str, Any]] = value["entries"]
    seen_ids: set[str] = set()
    for entry in entries:
        entry_id = entry.get("id")
        if not isinstance(entry_id, str) or entry_id in seen_ids:
            raise ValueError("progression hint ids must be unique")
        seen_ids.add(entry_id)
    dates = [
        item.get("accessedAt", "")
        for entry in entries
        for item in entry.get("sources", [])
        if isinstance(item, dict)
    ]
    source_as_of = max((item for item in dates if item), default="1970-01-01")
    output.mkdir(parents=True, exist_ok=True)
    descriptors: list[dict[str, Any]] = []
    object_plan: list[dict[str, Any]] = []
    assigned_ids: set[str] = set()
    for family, meta in FAMILIES.items():
        games = list(meta["games"])
        selected = [entry for entry in entries if set(entry.get("games") or []) & set(games)]
        if not selected:
            continue
        for entry in selected:
            if not set(entry["games"]).issubset(games):
                raise ValueError(f"{entry['id']} crosses Journey pack families")
            if entry["id"] in assigned_ids:
                raise ValueError(f"{entry['id']} assigned to multiple packs")
            assigned_ids.add(entry["id"])
        pack_id = f"journey-{family}"
        version = str(dataset_version)
        pack = {
            "schemaVersion": 1,
            "id": pack_id,
            "gameFamily": family,
            "games": games,
            "version": version,
            "sourceAsOf": source_as_of,
            "entries": selected,
        }
        body = _canonical_json(pack)
        if len(body) > MAX_PACK_BYTES:
            raise ValueError(f"{pack_id} exceeds the 4 MiB Journey pack limit")
        relative = Path("objects") / pack_id / f"{version}.json"
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(body)
        digest = hashlib.sha256(body).hexdigest()
        descriptors.append({
            "id": pack_id,
            "gameFamily": family,
            "games": games,
            "version": version,
            "contentPath": f"/v1/journey-packs/{relative.as_posix()}",
            "sizeBytes": len(body),
            "sha256": digest,
            "titleZh": f"{meta['title']}旅程资料",
            "descriptionZh": "经审核的卡关提示与本地确定性回答资料。",
            "entryCount": len(selected),
            "bundleVersionRequired": 20,
        })
        object_plan.append({
            "sourcePath": relative.as_posix(),
            "objectKey": f"journey-packs/{relative.as_posix()}",
            "contentType": "application/json; charset=utf-8",
            "sha256": digest,
            "sizeBytes": len(body),
            "immutable": True,
        })
    if assigned_ids != seen_ids:
        raise ValueError(f"unassigned progression hints: {sorted(seen_ids - assigned_ids)}")
    catalog = {
        "schemaVersion": 1,
        "generatedAt": f"{source_as_of}T00:00:00Z",
        "packs": descriptors,
    }
    catalog_body = _canonical_json(catalog)
    (output / "catalog.json").write_bytes(catalog_body)
    plan = {
        "schemaVersion": 1,
        "bucket": "titodex-journey-content",
        "objects": object_plan,
        "catalog": {
            "sourcePath": "catalog.json",
            "objectKey": "journey-packs/catalog.json",
            "contentType": "application/json; charset=utf-8",
            "sha256": hashlib.sha256(catalog_body).hexdigest(),
            "sizeBytes": len(catalog_body),
            "uploadLast": True,
        },
    }
    (output / "journey-pack-upload-plan.json").write_bytes(_canonical_json(plan))
    verify_candidate_dir(output)
    return catalog


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    args = parser.parse_args()
    if args.output.exists() and any(args.output.iterdir()):
        raise SystemExit("output directory must be empty")
    build_packs(args.source, args.output)


if __name__ == "__main__":
    main()
