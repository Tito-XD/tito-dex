#!/usr/bin/env python3
"""Build an isolated Dex bundle v20 candidate from a read-only v19 staging tree.

This tool never uploads.  It deliberately keeps the prospective root manifest
outside ``upload/`` so the generic uploader cannot switch production by
accident.  The v19 source tree is fingerprinted before and after the build.
"""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import re
import shutil
import tarfile
import unicodedata
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import zstandard


ROOT = Path(__file__).resolve().parents[1]
BUNDLE_VERSION = 20
BASE_BUNDLE_VERSION = 19
CDN_PREFIX = "v5"
DEFAULT_BASE = ROOT / "dist" / "dex-v19" / "staging"
DEFAULT_BASE_ROOT_MANIFEST = (
    ROOT / "dist" / "dex-v19" / "upload" / "bundle-manifest.json"
)
DEFAULT_OUTPUT = ROOT / "dist" / "dex-v20-candidate"
ARCHIVE_NAME = "bundle-v20.tar.zst"
KIND_ORDER = {"pokemon": 0, "move": 1, "ability": 2, "item": 3}
LABEL_FILES = {
    "pokemon": "species_labels.json",
    "move": "moves_labels.json",
    "ability": "abilities_labels.json",
    "item": "items_labels.json",
}
RUNTIME_FILES = {
    "pokemon": "summaries.json",
    "move": "moves.json",
    "ability": "abilities.json",
    "item": "items.json",
}


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any, *, compact: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    separators = (",", ":") if compact else None
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=None if compact else 2,
                   separators=separators)
        + "\n",
        encoding="utf-8",
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tree_fingerprint(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        relative = path.relative_to(root).as_posix().encode("utf-8")
        digest.update(len(relative).to_bytes(4, "big"))
        digest.update(relative)
        digest.update(path.stat().st_size.to_bytes(8, "big"))
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    return digest.hexdigest()


def directory_size(root: Path) -> int:
    return sum(path.stat().st_size for path in root.rglob("*") if path.is_file())


def normalized_name(value: Any) -> str:
    text = unicodedata.normalize("NFKC", str(value or "")).casefold()
    text = text.replace("♀", " female ").replace("♂", " male ")
    return re.sub(r"[^\w\u3400-\u9fff]+", "", text, flags=re.UNICODE)


def slugify(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = text.replace("♀", "-f").replace("♂", "-m")
    text = text.encode("ascii", "ignore").decode("ascii").lower()
    slug = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    if not slug:
        raise ValueError(f"cannot derive slug from {value!r}")
    return slug


def _runtime_payloads(staging: Path) -> dict[str, dict[str, dict[str, Any]]]:
    summaries = read_json(staging / "summaries.json")
    if not isinstance(summaries, list):
        raise ValueError("summaries.json must be an array")
    return {
        "pokemon": {str(row["id"]): row for row in summaries},
        "move": read_json(staging / "moves.json"),
        "ability": read_json(staging / "abilities.json"),
        "item": read_json(staging / "items.json"),
    }


def _canonical_entity(
    kind: str, runtime_id: str, payload: dict[str, Any]
) -> dict[str, Any]:
    numeric_id = int(payload.get("id") or runtime_id)
    name_zh = str(payload.get("nameZh") or "").strip()
    name_en = str(payload.get("nameEn") or "").strip()
    if not name_zh or not name_en:
        raise ValueError(f"{kind} #{runtime_id} has an empty canonical name")
    slug = (
        str(payload.get("slug") or "").strip().lower()
        if kind == "item"
        else slugify(name_en)
    )
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", slug):
        raise ValueError(f"{kind} #{runtime_id} has invalid slug {slug!r}")
    stable_key = slug if kind == "item" else str(numeric_id)
    ref_path = RUNTIME_FILES[kind]
    pointer = f"/{numeric_id - 1}" if kind == "pokemon" else f"/{runtime_id}"
    return {
        "stableId": f"{kind}:{stable_key}",
        "kind": kind,
        "id": numeric_id,
        "slug": slug,
        "nameZh": name_zh,
        "nameEn": name_en,
        "ref": {"path": ref_path, "pointer": pointer},
    }


def _label_record(label_id: str, payload: Any) -> dict[str, str]:
    if isinstance(payload, dict):
        return {
            "labelId": str(label_id),
            "nameZh": str(payload.get("zh") or "").strip(),
            "nameEn": str(payload.get("en") or "").strip(),
        }
    return {"labelId": str(label_id), "nameZh": str(payload or "").strip(), "nameEn": ""}


def _match_labels(
    kind: str,
    entities: list[dict[str, Any]],
    labels: dict[str, Any],
) -> tuple[dict[str, list[dict[str, str]]], set[str], list[str]]:
    """Return stable-id label matches, matched label IDs and direct conflicts."""
    by_runtime_id = {str(entity["id"]): entity for entity in entities}
    by_zh: dict[str, list[dict[str, Any]]] = defaultdict(list)
    by_en: dict[str, list[dict[str, Any]]] = defaultdict(list)
    by_slug: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for entity in entities:
        by_zh[normalized_name(entity["nameZh"])].append(entity)
        by_en[normalized_name(entity["nameEn"])].append(entity)
        by_slug[normalized_name(entity["slug"])].append(entity)

    matches: dict[str, list[dict[str, str]]] = defaultdict(list)
    matched_ids: set[str] = set()
    conflicts: list[str] = []
    for label_id, raw in labels.items():
        label = _label_record(str(label_id), raw)
        direct = by_runtime_id.get(str(label_id))
        candidates: dict[str, dict[str, Any]] = {}
        for name, lookup in (
            (label["nameZh"], by_zh),
            (label["nameEn"], by_en),
            (label["nameEn"], by_slug),
        ):
            key = normalized_name(name)
            if key:
                for entity in lookup.get(key, []):
                    candidates[entity["stableId"]] = entity

        chosen: dict[str, Any] | None = None
        if kind != "item" and direct is not None:
            chosen = direct
        elif direct is not None and direct["stableId"] in candidates:
            chosen = direct
        elif len(candidates) == 1:
            chosen = next(iter(candidates.values()))

        if chosen is None:
            continue
        matches[chosen["stableId"]].append(label)
        matched_ids.add(str(label_id))
        if kind != "item" and direct is not None:
            zh_diff = (
                label["nameZh"]
                and normalized_name(label["nameZh"])
                != normalized_name(chosen["nameZh"])
            )
            en_diff = (
                label["nameEn"]
                and normalized_name(label["nameEn"])
                != normalized_name(chosen["nameEn"])
            )
            if zh_diff or en_diff:
                conflicts.append(chosen["stableId"])
    return matches, matched_ids, sorted(set(conflicts))


def _duplicates(entities: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    buckets: dict[tuple[str, str, str], list[str]] = defaultdict(list)
    display: dict[tuple[str, str, str], str] = {}
    for entity in entities:
        for language, key in (("zh", "nameZh"), ("en", "nameEn")):
            normalized = normalized_name(entity[key])
            bucket = (entity["kind"], language, normalized)
            buckets[bucket].append(entity["stableId"])
            display[bucket] = entity[key]
    result = []
    for bucket, stable_ids in sorted(buckets.items()):
        if len(stable_ids) < 2:
            continue
        kind, language, _ = bucket
        result.append(
            {
                "kind": kind,
                "language": language,
                "name": display[bucket],
                "stableIds": sorted(stable_ids),
            }
        )
    return result


def build_entity_index(
    staging: Path, *, generated_at: str
) -> dict[str, Any]:
    runtime = _runtime_payloads(staging)
    l10n_root = staging / "l10n" / "zh"
    entities: list[dict[str, Any]] = []
    runtime_counts: dict[str, int] = {}
    label_counts: dict[str, int] = {}
    phantom: dict[str, list[dict[str, str]]] = {}
    without_label: dict[str, list[str]] = {}
    conflicts: dict[str, list[str]] = {}

    for kind in ("pokemon", "move", "ability", "item"):
        canonical = [
            _canonical_entity(kind, runtime_id, payload)
            for runtime_id, payload in sorted(
                runtime[kind].items(), key=lambda pair: int(pair[0])
            )
        ]
        labels = read_json(l10n_root / LABEL_FILES[kind])
        matches, matched_label_ids, kind_conflicts = _match_labels(
            kind, canonical, labels
        )
        for entity in canonical:
            aliases_zh = sorted(
                {
                    record["nameZh"]
                    for record in matches.get(entity["stableId"], [])
                    if record["nameZh"]
                    and record["nameZh"] != entity["nameZh"]
                }
            )
            aliases_en = sorted(
                {
                    record["nameEn"]
                    for record in matches.get(entity["stableId"], [])
                    if record["nameEn"]
                    and record["nameEn"] != entity["nameEn"]
                }
            )
            if aliases_zh:
                entity["aliasesZh"] = aliases_zh
            if aliases_en:
                entity["aliasesEn"] = aliases_en
            entities.append(entity)

        runtime_counts[kind] = len(canonical)
        label_counts[kind] = len(labels)
        phantom[kind] = [
            _label_record(label_id, labels[label_id])
            for label_id in sorted(
                set(labels) - matched_label_ids,
                key=lambda value: (not str(value).isdigit(), int(value) if str(value).isdigit() else str(value)),
            )
        ]
        matched_stable_ids = set(matches)
        without_label[kind] = sorted(
            entity["stableId"]
            for entity in canonical
            if entity["stableId"] not in matched_stable_ids
        )
        conflicts[kind] = kind_conflicts

    entities.sort(key=lambda entity: (KIND_ORDER[entity["kind"]], entity["id"], entity["stableId"]))
    stable_ids = [entity["stableId"] for entity in entities]
    if len(stable_ids) != len(set(stable_ids)):
        raise ValueError("entity index produced duplicate stable IDs")
    return {
        "schemaVersion": 1,
        "bundleVersion": BUNDLE_VERSION,
        "generatedAt": generated_at,
        "entities": entities,
        "audit": {
            "runtimeCounts": runtime_counts,
            "labelCounts": label_counts,
            "phantomLabels": phantom,
            "runtimeWithoutLabel": without_label,
            "labelNameConflicts": conflicts,
            "duplicateNames": _duplicates(entities),
        },
    }


def _evidence(
    *,
    source: str,
    method: str,
    confidence: str,
    level: str,
    freshness_class: str,
    status: str,
    checked_at: str,
    source_as_of: str | None,
    fallback: str,
    version_groups: Iterable[str] = (),
) -> dict[str, Any]:
    freshness: dict[str, Any] = {
        "class": freshness_class,
        "status": status,
        "checkedAt": checked_at,
        "maxAgeDays": None,
        "fallbackPolicy": fallback,
    }
    if source_as_of:
        freshness["sourceAsOf"] = source_as_of
    scope: dict[str, Any] = {"level": level}
    if level == "versionGroup":
        groups = sorted(set(map(str, version_groups)))
        if not groups:
            raise ValueError("versionGroup provenance requires at least one version group")
        scope["versionGroups"] = groups
    return {
        "sourceIds": [source],
        "method": method,
        "confidence": confidence,
        "scope": scope,
        "freshness": freshness,
    }


def build_provenance(
    staging: Path,
    *,
    generated_at: str,
    base_manifest: dict[str, Any],
    overlays: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    source_as_of = str(base_manifest.get("downloadedAt") or "") or None
    version_groups = sorted(
        {
            str(game["versionGroup"])
            for game in read_json(staging / "games.json")
            if game.get("versionGroup")
        }
    )
    notices = sorted(
        path.relative_to(staging).as_posix()
        for path in staging.glob("*_ATTRIBUTION.txt")
    )
    inherited = _evidence(
        source="titodex-v19-baseline",
        method="copied",
        confidence="unknown",
        level="unscoped",
        freshness_class="versionSensitive",
        status="inherited",
        checked_at=generated_at,
        source_as_of=source_as_of,
        fallback="online-verify",
    )
    stable = _evidence(
        source="titodex-v19-baseline",
        method="reviewed",
        confidence="high",
        level="franchiseStable",
        freshness_class="stable",
        status="inherited",
        checked_at=generated_at,
        source_as_of=source_as_of,
        fallback="local-authoritative",
    )
    scoped = _evidence(
        source="titodex-v19-baseline",
        method="copied",
        confidence="medium",
        level="versionGroup",
        freshness_class="versionSensitive",
        status="inherited",
        checked_at=generated_at,
        source_as_of=source_as_of,
        fallback="local-evidence",
        version_groups=version_groups,
    )
    generated = _evidence(
        source="titodex-v20-foundation",
        method="derived",
        confidence="high",
        level="franchiseStable",
        freshness_class="immutable",
        status="current",
        checked_at=generated_at,
        source_as_of=generated_at,
        fallback="local-authoritative",
    )
    rules = [
        {"pathPattern": "*.json", "priority": 0, "metadata": inherited, "fields": []},
        {"pathPattern": "details/*.json", "priority": 0, "metadata": inherited, "fields": []},
        {"pathPattern": "l10n/**/*.json", "priority": 0, "metadata": inherited, "fields": []},
        {"pathPattern": "maps/**/*.json", "priority": 0, "metadata": inherited, "fields": []},
        {"pathPattern": "config/**/*.json", "priority": 0, "metadata": inherited, "fields": []},
        {
            "pathPattern": "summaries.json",
            "priority": 10,
            "metadata": inherited,
            "fields": [
                {"pointerPattern": "/*/id", "metadata": stable},
                {"pointerPattern": "/*/name*", "metadata": stable},
                {"pointerPattern": "/*/types", "metadata": stable},
            ],
        },
        {
            "pathPattern": "details/*.json",
            "priority": 10,
            "metadata": inherited,
            "fields": [
                {"pointerPattern": "/summary", "metadata": stable},
                {"pointerPattern": "/baseStats", "metadata": stable},
                {"pointerPattern": "/moveSet*", "metadata": scoped},
                {"pointerPattern": "/obtainLocations*", "metadata": scoped},
                {"pointerPattern": "/heldItems", "metadata": scoped},
                {"pointerPattern": "/evolutionChain", "metadata": scoped},
            ],
        },
        {
            "pathPattern": "moves.json",
            "priority": 10,
            "metadata": scoped,
            "fields": [
                {"pointerPattern": "/*/id", "metadata": stable},
                {"pointerPattern": "/*/name*", "metadata": stable},
                {"pointerPattern": "/*/type", "metadata": stable},
            ],
        },
        {
            "pathPattern": "abilities.json",
            "priority": 10,
            "metadata": scoped,
            "fields": [
                {"pointerPattern": "/*/name*", "metadata": stable},
            ],
        },
        {
            "pathPattern": "items.json",
            "priority": 10,
            "metadata": scoped,
            "fields": [
                {"pointerPattern": "/*/slug", "metadata": stable},
                {"pointerPattern": "/*/name*", "metadata": stable},
            ],
        },
        {"pathPattern": "entity_index.json", "priority": 100, "metadata": generated, "fields": []},
        {"pathPattern": "provenance.json", "priority": 100, "metadata": generated, "fields": []},
        {"pathPattern": "manifest.json", "priority": 100, "metadata": generated, "fields": []},
    ]
    sources = {
        "titodex-v19-baseline": {
            "title": "TitoDex verified Dex bundle v19 baseline",
            "kind": "bundle",
            "revision": "bundle-v19",
            **({"retrievedAt": source_as_of} if source_as_of else {}),
            "license": "mixed; see bundled notices",
            "attributionRequired": bool(notices),
            "noticePaths": notices,
        },
        "titodex-v20-foundation": {
            "title": "TitoDex v20 deterministic foundation generator",
            "kind": "derived",
            "revision": "schema-v1",
            "retrievedAt": generated_at,
            "license": "project source license",
            "attributionRequired": False,
            "noticePaths": [],
        },
    }
    for overlay in overlays or []:
        for source_id, source in overlay["sources"].items():
            if source_id in sources and sources[source_id] != source:
                raise ValueError(f"overlay source ID conflicts with existing source: {source_id}")
            sources[source_id] = source
        rules.extend(overlay["objects"])
    return {
        "schemaVersion": 1,
        "bundleVersion": BUNDLE_VERSION,
        "generatedAt": generated_at,
        "sources": sources,
        "objects": rules,
    }


def apply_overlays(
    staging: Path, overlay_dirs: Iterable[Path]
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    fragments: list[dict[str, Any]] = []
    report: list[dict[str, Any]] = []
    forbidden = {
        "manifest.json",
        "entity_index.json",
        "provenance.json",
        "bundle-manifest.json",
        "bundle-manifest.v20.candidate.json",
    }
    for overlay_dir in overlay_dirs:
        metadata_path = overlay_dir / "overlay-provenance.json"
        if not metadata_path.is_file():
            raise ValueError(f"overlay lacks overlay-provenance.json: {overlay_dir}")
        fragment = read_json(metadata_path)
        required = {"schemaVersion", "overlayId", "baseBundleVersion", "sources", "objects"}
        if not isinstance(fragment, dict) or set(fragment) != required:
            raise ValueError(f"invalid overlay provenance shape: {overlay_dir}")
        if fragment["schemaVersion"] != 1 or fragment["baseBundleVersion"] != BASE_BUNDLE_VERSION:
            raise ValueError(f"overlay is not based on bundle v19: {overlay_dir}")
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", str(fragment["overlayId"])):
            raise ValueError(f"invalid overlay ID: {fragment['overlayId']!r}")
        if not isinstance(fragment["sources"], dict) or not fragment["sources"]:
            raise ValueError(f"overlay has no sources: {overlay_dir}")
        if not isinstance(fragment["objects"], list) or not fragment["objects"]:
            raise ValueError(f"overlay has no object provenance: {overlay_dir}")
        source_ids = set(fragment["sources"])
        notice_paths = {
            str(notice)
            for source in fragment["sources"].values()
            if isinstance(source, dict)
            for notice in source.get("noticePaths") or []
        }
        for rule in fragment["objects"]:
            priority = rule.get("priority") if isinstance(rule, dict) else None
            if not isinstance(priority, int) or not 20 <= priority <= 99:
                raise ValueError(f"overlay rule priority must be 20..99: {overlay_dir}")
            evidence = rule.get("metadata") or {}
            unknown_sources = set(evidence.get("sourceIds") or []) - source_ids
            if unknown_sources:
                raise ValueError(f"overlay rule uses unknown sources: {sorted(unknown_sources)}")
        files = sorted(
            path
            for path in overlay_dir.rglob("*")
            if path.is_file() and path != metadata_path
        )
        if not files:
            raise ValueError(f"overlay has no data files: {overlay_dir}")
        for source in files:
            if source.is_symlink():
                raise ValueError(f"overlay symlinks are forbidden: {source}")
            relative = source.relative_to(overlay_dir).as_posix()
            if Path(relative).name in forbidden or Path(relative).suffix == ".zst":
                raise ValueError(f"overlay cannot replace generated/release object: {relative}")
            if relative not in notice_paths and not any(
                fnmatch.fnmatchcase(relative, str(rule.get("pathPattern") or ""))
                for rule in fragment["objects"]
            ):
                raise ValueError(f"overlay file lacks object provenance: {relative}")
            destination = staging / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
        fragments.append(fragment)
        report.append({"overlayId": fragment["overlayId"], "files": len(files)})
    return fragments, report


def repair_derived_catalog(staging: Path) -> list[str]:
    summaries = read_json(staging / "summaries.json")
    moves = read_json(staging / "moves.json")
    abilities = read_json(staging / "abilities.json")
    catalog_path = staging / "dex_catalog.json"
    catalog = read_json(catalog_path)
    repaired: list[str] = []
    for key, expected in (
        ("summaries", summaries),
        ("moves", moves),
        ("abilities", abilities),
    ):
        if catalog.get(key) != expected:
            catalog[key] = expected
            repaired.append(f"dex_catalog.json#/{key}")
    if repaired:
        write_json(catalog_path, catalog, compact=True)
    return repaired


def _safe_output(base: Path, output: Path) -> None:
    base_resolved = base.resolve()
    output_resolved = output.resolve()
    if output_resolved == base_resolved:
        raise ValueError("v20 output must not be the v19 base")
    if output_resolved in base_resolved.parents or base_resolved in output_resolved.parents:
        raise ValueError("v20 output and v19 base must not contain one another")
    if output_resolved == Path(output_resolved.anchor):
        raise ValueError("refusing to use a filesystem root as output")
    if output_resolved in {ROOT.resolve(), Path.home().resolve()}:
        raise ValueError("refusing to replace the repository or home directory")
    if (output_resolved / ".git").exists():
        raise ValueError("refusing to replace a Git worktree")


def create_deterministic_archive(
    source: Path, archive: Path, *, generated_at: str
) -> None:
    epoch = int(datetime.fromisoformat(generated_at.replace("Z", "+00:00")).timestamp())
    archive.parent.mkdir(parents=True, exist_ok=True)
    with archive.open("wb") as raw:
        with zstandard.ZstdCompressor(level=19).stream_writer(raw) as compressed:
            with tarfile.open(fileobj=compressed, mode="w|") as tar:
                for path in sorted(item for item in source.rglob("*") if item.is_file()):
                    info = tar.gettarinfo(str(path), arcname=path.relative_to(source).as_posix())
                    info.uid = info.gid = 0
                    info.uname = info.gname = ""
                    info.mtime = epoch
                    with path.open("rb") as handle:
                        tar.addfile(info, handle)


def build_candidate(
    *,
    base_staging: Path,
    base_root_manifest: Path,
    output: Path,
    generated_at: str | None = None,
    build_archive: bool = True,
    overlay_dirs: Iterable[Path] = (),
) -> dict[str, Any]:
    _safe_output(base_staging, output)
    if not base_staging.is_dir():
        raise FileNotFoundError(f"missing v19 staging tree: {base_staging}")
    if not base_root_manifest.is_file():
        raise FileNotFoundError(f"missing v19 root manifest: {base_root_manifest}")
    base_manifest = read_json(base_staging / "manifest.json")
    base_root = read_json(base_root_manifest)
    if int(base_manifest.get("version") or 0) != BASE_BUNDLE_VERSION:
        raise ValueError("base staging manifest must be bundle v19")
    if int(base_root.get("bundleVersion") or 0) != BASE_BUNDLE_VERSION:
        raise ValueError("base root manifest must be bundle v19")
    if base_root.get("cdnPrefix") != CDN_PREFIX or base_root.get("complete") is not True:
        raise ValueError("base root manifest must be complete on the v5 prefix")

    generated_at = generated_at or datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    overlay_dirs = tuple(overlay_dirs)
    for overlay_dir in overlay_dirs:
        overlay_resolved = overlay_dir.resolve()
        if output.resolve() == overlay_resolved or output.resolve() in overlay_resolved.parents:
            raise ValueError("overlay must not be inside the disposable output directory")
    before = tree_fingerprint(base_staging)
    if output.exists():
        shutil.rmtree(output)
    staging = output / "staging"
    shutil.copytree(base_staging, staging)
    for archive in staging.glob("bundle*.tar.zst"):
        archive.unlink()

    overlay_fragments, overlay_report = apply_overlays(staging, overlay_dirs)
    repairs = repair_derived_catalog(staging)
    entity_index = build_entity_index(staging, generated_at=generated_at)
    write_json(staging / "entity_index.json", entity_index)
    provenance = build_provenance(
        staging,
        generated_at=generated_at,
        base_manifest=base_manifest,
        overlays=overlay_fragments,
    )
    write_json(staging / "provenance.json", provenance)

    manifest = read_json(staging / "manifest.json")
    runtime_counts = entity_index["audit"]["runtimeCounts"]
    schema_features = dict(manifest.get("schemaFeatures") or {})
    schema_features.update({"stableEntityIndex": 1, "provenance": 1})
    if (staging / "reference_v20_audit.json").is_file():
        reference_sources = read_json(staging / "reference_v20_sources.json")
        pokeapi_source = next(
            source
            for source in reference_sources["sources"]
            if source.get("sourceId") == "pokeapi-api-data"
        )
        schema_features.update(
            {
                "referenceStableIds": 1,
                "moveDetails": 2,
                "abilityDetails": 2,
                "itemDetails": 2,
                "generationMechanics": 1,
            }
        )
        manifest.update(
            {
                "referenceDataAudit": "reference_v20_audit.json",
                "referenceDataSources": "reference_v20_sources.json",
                "referenceDataSourceCommit": pokeapi_source["commit"],
                "referenceDataReviewStatus": "candidate",
                "moveVersionMatrix": "move_version_matrix.json",
                "itemVersionMatrix": "item_version_matrix.json",
            }
        )
    gameplay_root = staging / "gameplay"
    if gameplay_root.is_dir():
        gameplay_paths = {
            "gameVersionKeys": "gameplay/game_version_keys.json",
            "obtainMethods": "gameplay/obtain_methods.json",
            "learnMethods": "gameplay/learn_methods.json",
            "evolutionMethods": "gameplay/evolution_methods.json",
            "itemStoryUsage": "gameplay/item_story_usage.json",
            "versionCoverage": "gameplay/version_coverage.json",
            "sources": "gameplay/gameplay_sources.json",
            "audit": "gameplay/gameplay_v20_audit.json",
        }
        missing_gameplay = [
            path for path in gameplay_paths.values() if not (staging / path).is_file()
        ]
        if missing_gameplay:
            raise ValueError(f"incomplete v20 gameplay overlay: {missing_gameplay}")
        schema_features.update(
            {
                "exactGameObtainMethods": 1,
                "versionedLearnMethods": 1,
                "versionedEvolutionMethods": 1,
                "reviewedItemStoryUsage": 1,
                "boundedGameplaySpeciesShards": 1,
            }
        )
        gameplay_shards = gameplay_root / "species"
        expected_shards = {
            f"{row['id']}.json" for row in read_json(staging / "summaries.json")
        }
        actual_shards = (
            {path.name for path in gameplay_shards.glob("*.json") if path.is_file()}
            if gameplay_shards.is_dir()
            else set()
        )
        if actual_shards != expected_shards:
            raise ValueError("incomplete v20 gameplay species shard set")
        manifest["gameplayData"] = {
            "schemaVersion": 1,
            **gameplay_paths,
            "speciesShards": "gameplay/species/{speciesId}.json",
        }
    manifest.update(
        {
            "version": BUNDLE_VERSION,
            "baseBundleVersion": BASE_BUNDLE_VERSION,
            "releaseState": "candidate",
            "generatedAt": generated_at,
            "schemaFeatures": schema_features,
            "entityIndex": "entity_index.json",
            "provenance": "provenance.json",
            "pokemonCount": runtime_counts["pokemon"],
            "moveCount": runtime_counts["move"],
            "abilityCount": runtime_counts["ability"],
            "itemCount": runtime_counts["item"],
            "entityCounts": runtime_counts,
            "phantomLabelCounts": {
                kind: len(records)
                for kind, records in entity_index["audit"]["phantomLabels"].items()
            },
        }
    )
    write_json(staging / "manifest.json", manifest)
    manifest["sizeBytes"] = directory_size(staging)
    write_json(staging / "manifest.json", manifest)

    versioned = output / "upload" / CDN_PREFIX
    shutil.copytree(staging, versioned)
    archive = versioned / ARCHIVE_NAME
    if build_archive:
        create_deterministic_archive(staging, archive, generated_at=generated_at)

    pending = {
        key: value
        for key, value in base_root.items()
        if key not in {"archiveUrl", "publishedAt"}
    }
    pending.update(
        {
            "bundleVersion": BUNDLE_VERSION,
            "baseBundleVersion": BASE_BUNDLE_VERSION,
            "releaseState": "candidate",
            "cdnPrefix": CDN_PREFIX,
            "schemaFeatures": schema_features,
            "entityIndex": "entity_index.json",
            "provenance": "provenance.json",
            "pokemonCount": runtime_counts["pokemon"],
            "moveCount": runtime_counts["move"],
            "abilityCount": runtime_counts["ability"],
            "itemCount": runtime_counts["item"],
            "entityCounts": runtime_counts,
            "archiveFile": ARCHIVE_NAME,
            "archiveSha256": sha256_file(archive) if build_archive else None,
            "archiveSizeBytes": archive.stat().st_size if build_archive else None,
            "generatedAt": generated_at,
        }
    )
    for key in (
        "referenceDataAudit",
        "referenceDataSources",
        "referenceDataSourceCommit",
        "referenceDataReviewStatus",
        "moveVersionMatrix",
        "itemVersionMatrix",
        "gameplayData",
    ):
        if key in manifest:
            pending[key] = manifest[key]
    pending_path = output / "release-manifest" / "bundle-manifest.v20.candidate.json"
    write_json(pending_path, pending)
    if (output / "upload" / "bundle-manifest.json").exists():
        raise RuntimeError("candidate must not contain a publishable root manifest")

    after = tree_fingerprint(base_staging)
    if before != after:
        raise RuntimeError("v19 base changed during v20 candidate build")
    report = {
        "schemaVersion": 1,
        "bundleVersion": BUNDLE_VERSION,
        "baseBundleVersion": BASE_BUNDLE_VERSION,
        "generatedAt": generated_at,
        "baseTreeSha256": before,
        "baseRootManifestSha256": sha256_file(base_root_manifest),
        "baseUnchanged": True,
        "archiveBuilt": build_archive,
        "overlays": overlay_report,
        "repairedDerivedObjects": repairs,
        "entityCounts": entity_index["audit"]["runtimeCounts"],
        "phantomLabelCounts": {
            kind: len(records)
            for kind, records in entity_index["audit"]["phantomLabels"].items()
        },
        "runtimeWithoutLabelCounts": {
            kind: len(records)
            for kind, records in entity_index["audit"]["runtimeWithoutLabel"].items()
        },
        "duplicateNameGroups": len(entity_index["audit"]["duplicateNames"]),
        "pendingManifest": pending_path.relative_to(output).as_posix(),
    }
    write_json(output / "build-report.json", report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-staging", type=Path, default=DEFAULT_BASE)
    parser.add_argument(
        "--base-root-manifest", type=Path, default=DEFAULT_BASE_ROOT_MANIFEST
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--overlay",
        type=Path,
        action="append",
        default=[],
        help="Additive overlay directory with overlay-provenance.json (repeatable)",
    )
    parser.add_argument(
        "--generated-at",
        help="Fixed ISO-8601 timestamp for reproducible fixtures/tests",
    )
    parser.add_argument(
        "--no-archive",
        action="store_true",
        help="Foundation/test mode only; a releasable candidate requires an archive",
    )
    args = parser.parse_args()
    report = build_candidate(
        base_staging=args.base_staging,
        base_root_manifest=args.base_root_manifest,
        output=args.output,
        generated_at=args.generated_at,
        build_archive=not args.no_archive,
        overlay_dirs=args.overlay,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
