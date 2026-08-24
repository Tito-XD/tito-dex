#!/usr/bin/env python3
"""Build and verify bounded v20 reference shards for Worker retrieval.

The aggregate reference objects remain the App/runtime source of truth.  This
module writes a deterministic, strictly shaped serving projection so the
Journey Assistant never has to raise its existing aggregate-object limits.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
MAX_SHARD_BYTES = 64 * 1024
BUCKET_COUNT = 256
SHA40 = re.compile(r"^[0-9a-f]{40}$")
SLUG = re.compile(r"^[a-z0-9][a-z0-9-]{0,159}$")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def encode_json(payload: Any) -> bytes:
    return (json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n").encode()


def write_bounded_json(path: Path, payload: Any) -> int:
    body = encode_json(payload)
    if not 2 <= len(body) <= MAX_SHARD_BYTES:
        raise ValueError(f"reference shard {path} is {len(body)} bytes")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(body)
    return len(body)


def _text(value: Any, maximum: int = 800) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    return text[:maximum]


def _integer(value: Any, minimum: int = -1_000_000, maximum: int = 1_000_000) -> int | None:
    if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
        return None
    return value


def _strings(value: Any, maximum: int = 64) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item)[:120] for item in value if isinstance(item, str)][:maximum]


def _source_commit(record: dict[str, Any]) -> str:
    provenance = record.get("provenance")
    commit = provenance.get("sourceCommit") if isinstance(provenance, dict) else None
    return commit if isinstance(commit, str) and SHA40.fullmatch(commit) else ""


def _source_status(record: dict[str, Any], dataset_commit: str) -> str:
    return "pinned-pokeapi" if _source_commit(record) == dataset_commit else "retained-v19"


def _move_shard(key: str, record: dict[str, Any], dataset_commit: str) -> dict[str, Any]:
    entity_id = int(key)
    return {
        "schemaVersion": SCHEMA_VERSION,
        "kind": "move",
        "id": entity_id,
        "stableId": f"move:{entity_id}",
        "sourceCommit": dataset_commit,
        "sourceStatus": _source_status(record, dataset_commit),
        "slug": _text(record.get("slug"), 160),
        "nameZh": _text(record.get("nameZh"), 120),
        "nameEn": _text(record.get("nameEn"), 120),
        "type": _text(record.get("type"), 40),
        "typeZh": _text(record.get("typeZh"), 40),
        "category": _text(record.get("category"), 40),
        "categoryZh": _text(record.get("categoryZh"), 40),
        "power": _integer(record.get("power"), 0, 100_000),
        "accuracy": _integer(record.get("accuracy"), 0, 100_000),
        "pp": _integer(record.get("pp"), 0, 100_000),
        "priority": _integer(record.get("priority"), -20, 20),
        "target": _text(record.get("target"), 80),
        "targetZh": _text(record.get("targetZh"), 80),
        "generation": _integer(record.get("generation"), 1, 99),
        "descriptionZh": _text(record.get("descriptionZh"), 1200),
        "shortEffect": _text(record.get("shortEffect"), 1200),
        "availableVersionGroups": _strings(record.get("availableVersionGroups"), 64),
    }


def _ability_shard(key: str, record: dict[str, Any], dataset_commit: str) -> dict[str, Any]:
    entity_id = int(key)
    return {
        "schemaVersion": SCHEMA_VERSION,
        "kind": "ability",
        "id": entity_id,
        "stableId": f"ability:{entity_id}",
        "sourceCommit": dataset_commit,
        "sourceStatus": _source_status(record, dataset_commit),
        "slug": _text(record.get("slug"), 160),
        "nameZh": _text(record.get("nameZh"), 120),
        "nameEn": _text(record.get("nameEn"), 120),
        "generation": _integer(record.get("generation"), 1, 99),
        "descriptionZh": _text(record.get("descriptionZh"), 1200),
        "shortEffect": _text(record.get("shortEffect"), 1200),
    }


def _prices(value: Any) -> dict[str, dict[str, int]]:
    if not isinstance(value, dict) or len(value) > 64:
        return {}
    result: dict[str, dict[str, int]] = {}
    for group, raw in sorted(value.items()):
        if not isinstance(group, str) or not re.fullmatch(r"[a-z0-9-]{1,80}", group) or not isinstance(raw, dict):
            continue
        row = {
            key: amount
            for key in ("buy", "sell")
            if (amount := _integer(raw.get(key), 0, 1_000_000_000)) is not None
        }
        if row:
            result[group] = row
    return result


def _item_shard(key: str, record: dict[str, Any], dataset_commit: str) -> dict[str, Any]:
    entity_id = int(key)
    slug = _text(record.get("slug"), 160)
    if not slug or not SLUG.fullmatch(slug):
        raise ValueError(f"item {key} has invalid canonical slug")
    return {
        "schemaVersion": SCHEMA_VERSION,
        "kind": "item",
        "id": entity_id,
        "stableId": f"item:{slug}",
        "sourceCommit": dataset_commit,
        "sourceStatus": _source_status(record, dataset_commit),
        "slug": slug,
        "nameZh": _text(record.get("nameZh"), 120),
        "nameEn": _text(record.get("nameEn"), 120),
        "categoryZh": _text(record.get("categoryZh"), 80),
        "cost": _integer(record.get("cost"), 0, 1_000_000_000),
        "descriptionZh": _text(record.get("descriptionZh"), 1200),
        "effectZh": _text(record.get("effectZh"), 1200),
        "flingPower": _integer(record.get("flingPower"), 0, 100_000),
        "availableVersionGroups": _strings(record.get("availableVersionGroups"), 64),
        "availableGenerations": [
            value for value in (record.get("availableGenerations") or [])
            if _integer(value, 1, 99) is not None
        ][:32],
        "pricesByVersionGroup": _prices(record.get("pricesByVersionGroup")),
    }


PROJECTORS = {
    "moves": _move_shard,
    "abilities": _ability_shard,
    "items": _item_shard,
}


def slug_bucket(slug: str) -> str:
    return hashlib.sha256(slug.encode()).hexdigest()[:2]


def _collection_digest(rows: list[tuple[str, bytes]]) -> str:
    digest = hashlib.sha256()
    for relative, body in sorted(rows):
        digest.update(relative.encode())
        digest.update(b"\0")
        digest.update(hashlib.sha256(body).digest())
    return digest.hexdigest()


def build_reference_shards(staging: Path) -> dict[str, Any]:
    root = staging / "reference"
    if root.exists():
        shutil.rmtree(root)
    source_commit = _dataset_source_commit(staging)
    collections: dict[str, Any] = {}
    item_records: dict[str, dict[str, Any]] = {}
    for collection, projector in PROJECTORS.items():
        records = read_json(staging / f"{collection}.json")
        if not isinstance(records, dict):
            raise ValueError(f"{collection}.json must be an object")
        emitted: list[tuple[str, bytes]] = []
        for key, record in sorted(records.items(), key=lambda row: int(row[0])):
            if not re.fullmatch(r"[1-9]\d{0,5}", key) or not isinstance(record, dict):
                raise ValueError(f"invalid {collection} record {key}")
            shard = projector(key, record, source_commit)
            relative = f"reference/{collection}/{key}.json"
            body = encode_json(shard)
            write_bounded_json(staging / relative, shard)
            emitted.append((relative, body))
        collections[collection] = {
            "pathPattern": f"reference/{collection}/{{id}}.json",
            "count": len(emitted),
            "maximumObjectBytes": max(map(lambda row: len(row[1]), emitted), default=0),
            "setSha256": _collection_digest(emitted),
            "sourceStatusCounts": {
                status: sum(
                    1 for key, record in records.items()
                    if projector(key, record, source_commit)["sourceStatus"] == status
                )
                for status in ("pinned-pokeapi", "retained-v19")
            },
        }
        if collection == "items":
            item_records = records

    buckets: dict[str, dict[str, dict[str, Any]]] = {
        f"{value:02x}": {} for value in range(BUCKET_COUNT)
    }
    for key, record in item_records.items():
        slug = record.get("slug")
        name = record.get("nameZh")
        if not isinstance(slug, str) or not SLUG.fullmatch(slug) or not isinstance(name, str) or not name.strip():
            raise ValueError(f"item {key} cannot enter slug index")
        bucket = slug_bucket(slug)
        if slug in buckets[bucket]:
            raise ValueError(f"duplicate item slug {slug}")
        buckets[bucket][slug] = {"id": int(key), "nameZh": name.strip()[:120]}
    emitted_buckets: list[tuple[str, bytes]] = []
    for bucket, entries in sorted(buckets.items()):
        payload = {
            "schemaVersion": SCHEMA_VERSION,
            "kind": "item-slug-index",
            "bucket": bucket,
            "entries": dict(sorted(entries.items())),
        }
        relative = f"reference/item-slug-index/{bucket}.json"
        body = encode_json(payload)
        write_bounded_json(staging / relative, payload)
        emitted_buckets.append((relative, body))
    collections["itemSlugIndex"] = {
        "pathPattern": "reference/item-slug-index/{bucket}.json",
        "count": BUCKET_COUNT,
        "entryCount": len(item_records),
        "maximumObjectBytes": max(map(lambda row: len(row[1]), emitted_buckets)),
        "setSha256": _collection_digest(emitted_buckets),
    }
    audit = {
        "schemaVersion": SCHEMA_VERSION,
        "generator": "titodex-reference-shards-v1",
        "sourceCommit": source_commit,
        "maximumShardBytes": MAX_SHARD_BYTES,
        "collections": collections,
    }
    write_bounded_json(root / "reference_shards_audit.json", audit)
    return audit


def verify_reference_shards(staging: Path) -> dict[str, Any]:
    audit = read_json(staging / "reference/reference_shards_audit.json")
    if set(audit) != {"schemaVersion", "generator", "sourceCommit", "maximumShardBytes", "collections"}:
        raise ValueError("reference shard audit keys differ")
    if audit["schemaVersion"] != SCHEMA_VERSION or audit["generator"] != "titodex-reference-shards-v1":
        raise ValueError("invalid reference shard audit identity")
    if audit["maximumShardBytes"] != MAX_SHARD_BYTES or not SHA40.fullmatch(audit.get("sourceCommit", "")):
        raise ValueError("invalid reference shard audit bounds/provenance")
    expected = build_expected_reference_shards(staging)
    if audit != expected:
        raise ValueError("reference shard audit or complete shard set differs from aggregate source")
    return audit


def build_expected_reference_shards(staging: Path) -> dict[str, Any]:
    # Recompute in memory without mutating the tree.
    collections: dict[str, Any] = {}
    source_commit = _dataset_source_commit(staging)
    items: dict[str, dict[str, Any]] = {}
    for collection, projector in PROJECTORS.items():
        records = read_json(staging / f"{collection}.json")
        emitted: list[tuple[str, bytes]] = []
        for key, record in sorted(records.items(), key=lambda row: int(row[0])):
            shard = projector(key, record, source_commit)
            relative = f"reference/{collection}/{key}.json"
            path = staging / relative
            body = encode_json(shard)
            if not path.is_file() or path.read_bytes() != body or len(body) > MAX_SHARD_BYTES:
                raise ValueError(f"missing, altered, or oversized reference shard {relative}")
            emitted.append((relative, body))
        collections[collection] = {
            "pathPattern": f"reference/{collection}/{{id}}.json",
            "count": len(emitted),
            "maximumObjectBytes": max(map(lambda row: len(row[1]), emitted), default=0),
            "setSha256": _collection_digest(emitted),
            "sourceStatusCounts": {
                status: sum(
                    1 for key, record in records.items()
                    if projector(key, record, source_commit)["sourceStatus"] == status
                )
                for status in ("pinned-pokeapi", "retained-v19")
            },
        }
        if collection == "items":
            items = records
    bucket_entries = {f"{value:02x}": {} for value in range(BUCKET_COUNT)}
    for key, record in items.items():
        bucket_entries[slug_bucket(record["slug"])][record["slug"]] = {
            "id": int(key), "nameZh": record["nameZh"].strip()[:120]
        }
    emitted_buckets: list[tuple[str, bytes]] = []
    for bucket, entries in sorted(bucket_entries.items()):
        relative = f"reference/item-slug-index/{bucket}.json"
        body = encode_json({
            "schemaVersion": SCHEMA_VERSION, "kind": "item-slug-index",
            "bucket": bucket, "entries": dict(sorted(entries.items())),
        })
        path = staging / relative
        if not path.is_file() or path.read_bytes() != body or len(body) > MAX_SHARD_BYTES:
            raise ValueError(f"missing, altered, or oversized reference index {relative}")
        emitted_buckets.append((relative, body))
    collections["itemSlugIndex"] = {
        "pathPattern": "reference/item-slug-index/{bucket}.json",
        "count": BUCKET_COUNT,
        "entryCount": len(items),
        "maximumObjectBytes": max(map(lambda row: len(row[1]), emitted_buckets)),
        "setSha256": _collection_digest(emitted_buckets),
    }
    actual_files = {
        path.relative_to(staging / "reference").as_posix()
        for path in (staging / "reference").rglob("*.json")
    }
    expected_files = {
        f"{collection}/{key}.json"
        for collection in PROJECTORS
        for key in read_json(staging / f"{collection}.json")
    } | {f"item-slug-index/{value:02x}.json" for value in range(BUCKET_COUNT)} | {
        "reference_shards_audit.json"
    }
    if actual_files != expected_files:
        raise ValueError("reference shard tree has missing or unknown JSON objects")
    return {
        "schemaVersion": SCHEMA_VERSION,
        "generator": "titodex-reference-shards-v1",
        "sourceCommit": source_commit,
        "maximumShardBytes": MAX_SHARD_BYTES,
        "collections": collections,
    }


def _dataset_source_commit(staging: Path) -> str:
    source_path = staging / "reference_v20_sources.json"
    if source_path.is_file():
        sources = read_json(source_path)
        for source in sources.get("sources", []) if isinstance(sources, dict) else []:
            if isinstance(source, dict) and source.get("sourceId") == "pokeapi-api-data" and \
                    isinstance(source.get("commit"), str) and SHA40.fullmatch(source["commit"]):
                return source["commit"]
    for filename in ("moves.json", "abilities.json", "items.json"):
        records = read_json(staging / filename)
        for record in records.values():
            if isinstance(record, dict) and (commit := _source_commit(record)):
                return commit
    raise ValueError("reference shard projection lacks a pinned dataset source commit")
