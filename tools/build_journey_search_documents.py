#!/usr/bin/env python3
"""Build audited AI Search documents and an R2 custom-metadata upload plan.

The generated chunk text is retrieval-only. The Worker accepts only the
document's ``hint_id`` metadata and always rebuilds answers from the reviewed
local JSON.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from tools.validate_journey_fact_pack import load_json, validate_supply_chain
except ModuleNotFoundError:  # Direct `python3 tools/...` execution.
    from validate_journey_fact_pack import load_json, validate_supply_chain


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "data/journey/progression_hints.json"
DEFAULT_REGISTRY = ROOT / "data/journey/sources/source_registry.json"
DEFAULT_LOCK = ROOT / "data/journey/sources/source_lock.json"
DEFAULT_FACT_PACK = ROOT / "data/journey/packs/hgss/facts.json"
R2_BUCKET_NAME = "titodex-journey-content"
AI_SEARCH_INCLUDE_PREFIX = "journey-search/"
CUSTOM_METADATA_FIELDS = (
    {"name": "hint_id", "type": "text"},
    {"name": "audited", "type": "boolean"},
    {"name": "game", "type": "text"},
    {"name": "generation", "type": "number"},
    {"name": "location_id", "type": "text"},
)


def build_documents(
    source: Path,
    output: Path,
    *,
    registry: Path = DEFAULT_REGISTRY,
    source_lock: Path = DEFAULT_LOCK,
    fact_pack: Path | None = None,
    fact_packs: list[Path] | None = None,
) -> dict:
    data = json.loads(source.read_text(encoding="utf-8"))
    if data.get("schemaVersion") != 1 or not isinstance(data.get("entries"), list):
        raise ValueError("unsupported progression-hint dataset")
    registry_value = load_json(registry)
    source_lock_value = load_json(source_lock)
    selected_packs = fact_packs
    if selected_packs is None:
        selected_packs = (
            [fact_pack]
            if fact_pack is not None
            else sorted((ROOT / "data/journey/packs").glob("*/facts.json"))
        )
    if not selected_packs:
        raise ValueError("at least one reviewed fact pack is required")
    approved_hint_ids: set[str] = set()
    for pack_path in selected_packs:
        reviewed_pack = load_json(pack_path)
        validate_supply_chain(
            registry_value,
            source_lock_value,
            reviewed_pack,
            release=True,
        )
        for fact in reviewed_pack["facts"]:
            if (
                fact.get("allowedForAiIndex") is True
                and fact.get("review", {}).get("status") == "approved"
            ):
                hint_id = fact.get("originHintId")
                if not isinstance(hint_id, str) or hint_id in approved_hint_ids:
                    raise ValueError("approved originHintId values must be unique")
                approved_hint_ids.add(hint_id)
    dataset_hint_ids = {entry.get("id") for entry in data["entries"]}
    if dataset_hint_ids != approved_hint_ids:
        raise ValueError("progression hints and approved AI-index facts differ")

    if output.exists():
        if not output.is_dir():
            raise ValueError("output path is not a directory")
        if any(output.iterdir()):
            raise ValueError("output directory must be empty")
    documents = output / "documents"
    documents.mkdir(parents=True)

    upload_entries = []
    for hint in data["entries"]:
        hint_id = hint["id"]
        games = hint["games"]
        locations = hint["locations"]
        for game in games:
            for location_id in locations:
                name = f"{hint_id}--{game}--{location_id}.md"
                relative_path = f"documents/{name}"
                body = _render_document(hint, game, location_id)
                (output / relative_path).write_text(body, encoding="utf-8")
                upload_entries.append(
                    {
                        "sourcePath": relative_path,
                        "objectKey": f"journey-search/v{data['datasetVersion']}/{name}",
                        "contentType": "text/markdown; charset=utf-8",
                        "customMetadata": {
                            "hint_id": hint_id,
                            "audited": "true",
                            "game": game,
                            "generation": str(hint["generation"]),
                            "location_id": location_id,
                        },
                    }
                )

    plan = {
        "schemaVersion": 1,
        "datasetVersion": data["datasetVersion"],
        "r2Bucket": R2_BUCKET_NAME,
        "aiSearchIncludePrefix": AI_SEARCH_INCLUDE_PREFIX,
        "customMetadataFields": list(CUSTOM_METADATA_FIELDS),
        "entries": upload_entries,
    }
    (output / "search-upload-plan.json").write_text(
        json.dumps(plan, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return plan


def _render_document(hint: dict, game: str, location_id: str) -> str:
    aliases = [
        *hint["locationAliases"],
        *hint["destinationAliases"],
        hint["subject"]["labelZh"],
        *hint["subject"]["aliases"],
    ]
    requirements = "；".join(item["labelZh"] for item in hint["requirements"])
    steps = "\n".join(
        f"{step['order']}. {step['instructionZh']}" for step in hint["steps"]
    )
    return (
        f"# {hint['subject']['labelZh']}\n\n"
        f"审核提示 ID：{hint['id']}\n"
        f"游戏：{game}\n"
        f"世代：{hint['generation']}\n"
        f"规范地点：{location_id}\n"
        f"模糊别名：{'、'.join(dict.fromkeys(aliases))}\n\n"
        f"{hint['overviewZh']}\n\n"
        f"前置条件：{requirements}\n\n"
        f"步骤：\n{steps}\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--lock", type=Path, default=DEFAULT_LOCK)
    parser.add_argument("--fact-pack", type=Path, action="append")
    args = parser.parse_args()
    build_documents(
        args.source,
        args.output,
        registry=args.registry,
        source_lock=args.lock,
        fact_packs=args.fact_pack,
    )


if __name__ == "__main__":
    main()
