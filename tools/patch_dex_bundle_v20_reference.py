#!/usr/bin/env python3
"""Build a local v20 reference-data candidate from an immutable v19 staging tree.

This tool never uploads data and never edits the v19 input.  It enriches the
reference catalogs from one pinned PokéAPI/api-data commit, writes an audit,
and optionally creates an archive plus a *candidate* root manifest under the
new output directory.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tarfile
import tempfile
from collections.abc import Iterable
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit, urlunsplit


ROOT = Path(__file__).resolve().parents[1]
BASE_VERSION = 19
BUNDLE_VERSION = 20
CDN_PREFIX = "v5"
ARCHIVE_NAME = f"bundle-v{BUNDLE_VERSION}.tar.zst"
SOURCE_LOCK = ROOT / "data" / "dex" / "reference_v20_sources.json"
MECHANICS_DATA = ROOT / "data" / "dex" / "reference_v20_mechanics.json"
ITEM_VERSION_MATRIX = ROOT / "flutter" / "assets" / "data" / "item_version_matrix.json"
MOVE_VERSION_MATRIX = ROOT / "flutter" / "assets" / "data" / "move_version_matrix.json"
DEFAULT_BASE = ROOT / "dist" / "dex-v19" / "staging"
DEFAULT_BASE_ROOT_MANIFEST = ROOT / "dist" / "dex-v19" / "upload" / "bundle-manifest.json"
DEFAULT_OUTPUT = ROOT / "dist" / "dex-v20-candidate"
API_SUBTREES = (
    "data/api/v2/move",
    "data/api/v2/ability",
    "data/api/v2/item",
    "data/api/v2/machine",
    "data/api/v2/type",
    "LICENSE.txt",
)
LANGUAGE_ZH = ("zh-Hans", "zh-hans", "zh-Hant", "zh-hant")
GENERATION_BY_SLUG = {
    "generation-i": 1,
    "generation-ii": 2,
    "generation-iii": 3,
    "generation-iv": 4,
    "generation-v": 5,
    "generation-vi": 6,
    "generation-vii": 7,
    "generation-viii": 8,
    "generation-ix": 9,
}
MOVE_TARGET_ZH = {
    "specific-move": "指定招式",
    "selected-pokemon-me-first": "选定宝可梦",
    "ally": "我方单体",
    "users-field": "我方场地",
    "user-or-ally": "自身或我方单体",
    "opponents-field": "对手场地",
    "user": "自身",
    "random-opponent": "随机对手",
    "all-other-pokemon": "除自身外全部宝可梦",
    "selected-pokemon": "选定宝可梦",
    "all-opponents": "全部对手",
    "entire-field": "全场",
    "user-and-allies": "自身及全部同伴",
    "all-pokemon": "全部宝可梦",
    "all-allies": "全部同伴",
    "fainting-pokemon": "濒死宝可梦",
}


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any, *, compact: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            payload,
            ensure_ascii=False,
            separators=(",", ":") if compact else None,
            indent=None if compact else 2,
            sort_keys=False,
        )
        + "\n",
        encoding="utf-8",
    )


def clean_text(value: str | None) -> str:
    if not value:
        return ""
    return re.sub(r"\s+", " ", value.replace("\u00ad", " ")).strip()


def ref_id(resource: dict[str, Any] | None) -> int | None:
    if not resource:
        return None
    match = re.search(r"/(\d+)/?$", str(resource.get("url") or ""))
    return int(match.group(1)) if match else None


def ref_name(resource: dict[str, Any] | None) -> str | None:
    if not resource:
        return None
    value = str(resource.get("name") or "").strip()
    return value or None


def generation_number(resource: dict[str, Any] | None) -> int | None:
    return GENERATION_BY_SLUG.get(ref_name(resource) or "")


def localized_name(entries: Iterable[dict[str, Any]], fallback: str) -> tuple[str, str]:
    entries = list(entries)
    for language in LANGUAGE_ZH:
        for entry in entries:
            if ref_name(entry.get("language")) == language:
                value = clean_text(entry.get("name"))
                if value:
                    return value, language
    return fallback, "en"


def localized_effect(entries: Iterable[dict[str, Any]]) -> dict[str, Any]:
    entries = list(entries)
    for language in LANGUAGE_ZH:
        for entry in entries:
            if ref_name(entry.get("language")) != language:
                continue
            effect = clean_text(entry.get("effect"))
            short = clean_text(entry.get("short_effect"))
            if effect or short:
                return {
                    "effect": effect or short,
                    "shortEffect": short or effect,
                    "language": language,
                    "isFallback": False,
                }
    for entry in entries:
        if ref_name(entry.get("language")) == "en":
            effect = clean_text(entry.get("effect"))
            short = clean_text(entry.get("short_effect"))
            if effect or short:
                return {
                    "effect": effect or short,
                    "shortEffect": short or effect,
                    "language": "en",
                    "isFallback": True,
                }
    return {"effect": "", "shortEffect": "", "language": "none", "isFallback": True}


def replace_effect_chance(text: str, chance: Any) -> str:
    if chance is None:
        return text
    return text.replace("$effect_chance", str(chance))


def flavor_by_version(entries: Iterable[dict[str, Any]]) -> dict[str, str]:
    result: dict[str, str] = {}
    for language in LANGUAGE_ZH:
        for entry in entries:
            if ref_name(entry.get("language")) != language:
                continue
            version_group = ref_name(entry.get("version_group"))
            text = clean_text(entry.get("flavor_text"))
            if version_group and text:
                # LANGUAGE_ZH is ordered by preference.  Do not let a later
                # Traditional-Chinese entry overwrite an existing zh-Hans
                # value for the same version group.
                result.setdefault(version_group, text)
    return result


def latest_flavor(entries: Iterable[dict[str, Any]]) -> tuple[str, str, str | None]:
    versioned = flavor_by_version(entries)
    if versioned:
        version_group = next(reversed(versioned))
        return versioned[version_group], "zh-Hans", version_group
    for entry in reversed(list(entries)):
        if ref_name(entry.get("language")) != "en":
            continue
        text = clean_text(entry.get("flavor_text"))
        if text:
            return text, "en", ref_name(entry.get("version_group"))
    return "", "none", None


def source_record(commit: str, scope: str) -> dict[str, Any]:
    return {
        "sourceId": "pokeapi-api-data",
        "sourceCommit": commit,
        "license": "BSD-3-Clause",
        "scope": scope,
    }


def verify_source_checkout(path: Path, expected_commit: str) -> None:
    if not (path / ".git").exists():
        marker = path / ".titodex-source.json"
        if not marker.is_file() or read_json(marker).get("commit") != expected_commit:
            raise ValueError(
                f"Unverifiable api-data checkout at {path}; expected commit {expected_commit}"
            )
        return
    actual = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=path,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    if actual != expected_commit:
        raise ValueError(f"api-data commit mismatch: expected {expected_commit}, got {actual}")


def fetch_source_checkout(path: Path, source: dict[str, Any]) -> Path:
    expected_commit = source["commit"]
    if path.exists():
        verify_source_checkout(path, expected_commit)
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix="pokeapi-api-data-", dir=path.parent))
    try:
        subprocess.run(["git", "init", "-q"], cwd=temporary, check=True)
        subprocess.run(
            ["git", "remote", "add", "origin", source["repository"]],
            cwd=temporary,
            check=True,
        )
        subprocess.run(
            ["git", "sparse-checkout", "init", "--no-cone"], cwd=temporary, check=True
        )
        subprocess.run(
            [
                "git",
                "sparse-checkout",
                "set",
                *(
                    f"/{entry}/" if "." not in Path(entry).name else f"/{entry}"
                    for entry in API_SUBTREES
                ),
            ],
            cwd=temporary,
            check=True,
        )
        subprocess.run(
            ["git", "fetch", "--depth", "1", "origin", expected_commit],
            cwd=temporary,
            check=True,
        )
        subprocess.run(
            ["git", "checkout", "-q", "--detach", "FETCH_HEAD"],
            cwd=temporary,
            check=True,
        )
        temporary.rename(path)
    except Exception:
        shutil.rmtree(temporary, ignore_errors=True)
        raise
    verify_source_checkout(path, expected_commit)
    return path


def endpoint_rows(api_root: Path, resource: str) -> list[dict[str, Any]]:
    root = api_root / "data" / "api" / "v2" / resource
    if not root.is_dir():
        raise FileNotFoundError(f"Missing api-data endpoint tree: {root}")
    rows = [read_json(path) for path in root.glob("*/index.json")]
    return sorted(rows, key=lambda row: int(row["id"]))


def endpoint_by_id(api_root: Path, resource: str) -> dict[int, dict[str, Any]]:
    return {int(row["id"]): row for row in endpoint_rows(api_root, resource)}


def endpoint_by_slug(api_root: Path, resource: str) -> dict[str, dict[str, Any]]:
    return {str(row["name"]): row for row in endpoint_rows(api_root, resource)}


def normalize_damage_relations(payload: dict[str, Any]) -> dict[str, list[str]]:
    return {
        "doubleDamageFrom": sorted(ref_name(row) for row in payload.get("double_damage_from", []) if ref_name(row)),
        "doubleDamageTo": sorted(ref_name(row) for row in payload.get("double_damage_to", []) if ref_name(row)),
        "halfDamageFrom": sorted(ref_name(row) for row in payload.get("half_damage_from", []) if ref_name(row)),
        "halfDamageTo": sorted(ref_name(row) for row in payload.get("half_damage_to", []) if ref_name(row)),
        "noDamageFrom": sorted(ref_name(row) for row in payload.get("no_damage_from", []) if ref_name(row)),
        "noDamageTo": sorted(ref_name(row) for row in payload.get("no_damage_to", []) if ref_name(row)),
    }


def machine_kind(item_slug: str) -> tuple[str, int | None]:
    match = re.fullmatch(r"(tm|hm|tr)(\d+)", item_slug)
    if not match:
        return "machine", None
    return match.group(1).upper(), int(match.group(2))


def build_machine_indexes(
    api_root: Path,
    item_labels: dict[str, dict[str, Any]],
) -> tuple[dict[int, dict[str, Any]], dict[str, list[dict[str, Any]]]]:
    by_id: dict[int, dict[str, Any]] = {}
    by_item: dict[str, list[dict[str, Any]]] = {}
    item_label_by_slug = {row.get("slug"): row for row in item_labels.values()}
    for row in endpoint_rows(api_root, "machine"):
        item_slug = ref_name(row.get("item")) or ""
        move_slug = ref_name(row.get("move")) or ""
        version_group = ref_name(row.get("version_group")) or ""
        kind, number = machine_kind(item_slug)
        item_label = item_label_by_slug.get(item_slug) or {}
        entry = {
            "machineId": int(row["id"]),
            "itemId": ref_id(row.get("item")),
            "itemSlug": item_slug,
            "itemNameZh": item_label.get("nameZh") or item_slug,
            "moveId": ref_id(row.get("move")),
            "moveSlug": move_slug,
            "versionGroup": version_group,
            "kind": kind,
            **({"number": number} if number is not None else {}),
        }
        by_id[int(row["id"])] = entry
        by_item.setdefault(item_slug, []).append(entry)
    return by_id, by_item


def build_move_record(
    detail: dict[str, Any],
    *,
    existing: dict[str, Any] | None,
    label: dict[str, Any] | None,
    machines: dict[int, dict[str, Any]],
    commit: str,
) -> dict[str, Any]:
    existing = dict(existing or {})
    label = label or {}
    slug = str(detail["name"])
    name_zh, name_language = localized_name(detail.get("names", []), label.get("nameZh") or slug)
    effect = localized_effect(detail.get("effect_entries", []))
    effect["effect"] = replace_effect_chance(effect["effect"], detail.get("effect_chance"))
    effect["shortEffect"] = replace_effect_chance(effect["shortEffect"], detail.get("effect_chance"))
    description, description_language, description_version_group = latest_flavor(
        detail.get("flavor_text_entries", [])
    )
    meta = detail.get("meta") or {}
    machine_rows: list[dict[str, Any]] = []
    for machine_ref in detail.get("machines", []):
        machine_id = ref_id(machine_ref.get("machine"))
        resolved = machines.get(machine_id or -1)
        if resolved:
            machine_rows.append(resolved)
    history: list[dict[str, Any]] = []
    for past in detail.get("past_values", []):
        previous = {
            key: past.get(source_key)
            for key, source_key in (
                ("accuracy", "accuracy"),
                ("power", "power"),
                ("pp", "pp"),
                ("effectChance", "effect_chance"),
            )
            if past.get(source_key) is not None
        }
        if past.get("type"):
            previous["type"] = ref_name(past.get("type"))
        past_effect = localized_effect(past.get("effect_entries", []))
        if past_effect["effect"]:
            previous["effect"] = past_effect["effect"]
            previous["effectLanguage"] = past_effect["language"]
        if previous:
            history.append(
                {
                    "changedInVersionGroup": ref_name(past.get("version_group")),
                    "previousValues": previous,
                }
            )
    stat_changes = [
        {"stat": ref_name(row.get("stat")), "stages": row.get("change")}
        for row in detail.get("stat_changes", [])
        if ref_name(row.get("stat"))
    ]
    target = ref_name(detail.get("target"))
    record = {
        **existing,
        "stableId": f"move:{int(detail['id'])}",
        "id": int(detail["id"]),
        "slug": slug,
        "nameEn": label.get("nameEn") or slug.replace("-", " ").title(),
        "nameZh": name_zh,
        "nameLanguage": name_language,
        "type": ref_name(detail.get("type")),
        "typeZh": label.get("typeZh"),
        "category": ref_name(detail.get("damage_class")),
        "categoryZh": label.get("categoryZh"),
        "power": detail.get("power"),
        "accuracy": detail.get("accuracy"),
        "pp": detail.get("pp"),
        "priority": detail.get("priority", 0),
        "target": target,
        "targetZh": MOVE_TARGET_ZH.get(target or "", target),
        "generation": generation_number(detail.get("generation")),
        "descriptionZh": description,
        "descriptionLanguage": description_language,
        "descriptionVersionGroup": description_version_group,
        "descriptionByVersionGroup": flavor_by_version(detail.get("flavor_text_entries", [])),
        "effect": effect["effect"],
        "shortEffect": effect["shortEffect"],
        "effectLanguage": effect["language"],
        "effectIsFallback": effect["isFallback"],
        "effectChance": detail.get("effect_chance"),
        "ailment": ref_name(meta.get("ailment")),
        "ailmentChance": meta.get("ailment_chance"),
        "statChance": meta.get("stat_chance"),
        "flinchChance": meta.get("flinch_chance"),
        "drain": meta.get("drain"),
        "healing": meta.get("healing"),
        "critRate": meta.get("crit_rate"),
        "minHits": meta.get("min_hits"),
        "maxHits": meta.get("max_hits"),
        "minTurns": meta.get("min_turns"),
        "maxTurns": meta.get("max_turns"),
        "metaCategory": ref_name(meta.get("category")),
        "statChanges": stat_changes,
        "history": history,
        "machines": machine_rows,
        "provenance": source_record(commit, "current values plus explicit version-group history"),
    }
    return {key: value for key, value in record.items() if value is not None}


def build_ability_record(
    detail: dict[str, Any],
    *,
    existing: dict[str, Any] | None,
    label: dict[str, Any] | None,
    commit: str,
) -> dict[str, Any]:
    existing = dict(existing or {})
    label = label or {}
    slug = str(detail["name"])
    name_zh, name_language = localized_name(detail.get("names", []), label.get("nameZh") or slug)
    effect = localized_effect(detail.get("effect_entries", []))
    description, description_language, description_version_group = latest_flavor(
        detail.get("flavor_text_entries", [])
    )
    changes = []
    for change in detail.get("effect_changes", []):
        changed = localized_effect(change.get("effect_entries", []))
        if changed["effect"]:
            changes.append(
                {
                    "changedInVersionGroup": ref_name(change.get("version_group")),
                    "effect": changed["effect"],
                    "effectLanguage": changed["language"],
                }
            )
    assignments = [
        {
            "pokemonId": ref_id(row.get("pokemon")),
            "pokemonSlug": ref_name(row.get("pokemon")),
            "slot": row.get("slot"),
            "isHidden": bool(row.get("is_hidden")),
        }
        for row in detail.get("pokemon", [])
        if ref_id(row.get("pokemon")) is not None
    ]
    species_ids = sorted(
        {
            int(row["pokemonId"])
            for row in assignments
            if row["pokemonId"] is not None and int(row["pokemonId"]) <= 1025
        }
        | {int(value) for value in existing.get("pokemonIds", [])}
    )
    return {
        **existing,
        "stableId": f"ability:{int(detail['id'])}",
        "id": int(detail["id"]),
        "slug": slug,
        "nameEn": label.get("nameEn") or slug.replace("-", " ").title(),
        "nameZh": name_zh,
        "nameLanguage": name_language,
        "generation": generation_number(detail.get("generation")),
        "isMainSeries": bool(detail.get("is_main_series")),
        "descriptionZh": description,
        "descriptionLanguage": description_language,
        "descriptionVersionGroup": description_version_group,
        "descriptionByVersionGroup": flavor_by_version(detail.get("flavor_text_entries", [])),
        "effect": effect["effect"],
        "shortEffect": effect["shortEffect"],
        "effectLanguage": effect["language"],
        "effectIsFallback": effect["isFallback"],
        "history": changes,
        "pokemonIds": species_ids,
        "pokemonAssignments": assignments,
        "provenance": source_record(commit, "current values plus explicit version-group history"),
    }


def build_item_record(
    detail: dict[str, Any],
    *,
    existing: dict[str, Any],
    machine_by_item: dict[str, list[dict[str, Any]]],
    commit: str,
) -> dict[str, Any]:
    slug = str(detail["name"])
    effect = localized_effect(detail.get("effect_entries", []))
    version_prices = [
        {
            "versionGroup": ref_name(row.get("version_group")),
            "currency": ref_name(row.get("currency")),
            "purchasePrice": row.get("purchase_price"),
            "sellPrice": row.get("sell_price"),
        }
        for row in detail.get("prices", [])
    ]
    return {
        **existing,
        "stableId": f"item:{int(detail['id'])}",
        "id": int(detail["id"]),
        "slug": slug,
        "attributes": sorted(
            ref_name(row) for row in detail.get("attributes", []) if ref_name(row)
        ),
        "category": ref_name(detail.get("category")) or existing.get("category"),
        "cost": detail.get("cost", existing.get("cost")),
        "flingPower": detail.get("fling_power"),
        "flingEffect": ref_name(detail.get("fling_effect")),
        "effect": effect["effect"],
        "shortEffect": effect["shortEffect"],
        "effectLanguage": effect["language"],
        "effectIsFallback": effect["isFallback"],
        "descriptionByVersionGroup": flavor_by_version(detail.get("flavor_text_entries", [])),
        "versionPrices": version_prices,
        "machines": machine_by_item.get(slug, []),
        "heldByPokemonIds": sorted(
            {
                int(pid)
                for row in detail.get("held_by_pokemon", [])
                if (pid := ref_id(row.get("pokemon"))) is not None
            }
        ),
        "babyTriggerForSpeciesId": ref_id(detail.get("baby_trigger_for")),
        "provenance": source_record(commit, "current values and explicit version-group prices/machines"),
    }


def enrich_types(
    existing: dict[str, dict[str, Any]],
    api_root: Path,
    labels: dict[str, dict[str, Any]],
    commit: str,
) -> dict[str, dict[str, Any]]:
    result = dict(existing)
    for detail in endpoint_rows(api_root, "type"):
        slug = str(detail["name"])
        if slug not in result and slug not in labels:
            continue
        current = normalize_damage_relations(detail.get("damage_relations") or {})
        history = [
            {
                "generation": generation_number(row.get("generation")),
                "relations": normalize_damage_relations(row.get("damage_relations") or {}),
            }
            for row in detail.get("past_damage_relations", [])
        ]
        label = labels.get(slug) or {}
        result[slug] = {
            **result.get(slug, {}),
            **current,
            "stableId": f"type:{int(detail['id'])}",
            "id": int(detail["id"]),
            "slug": slug,
            "nameEn": label.get("nameEn") or slug,
            "nameZh": label.get("nameZh") or slug,
            "generation": generation_number(detail.get("generation")),
            "damageRelations": current,
            "history": history,
            "provenance": source_record(commit, "current relations plus generation history"),
        }
    return result


def merge_mechanics(
    rows: list[dict[str, Any]],
    patches: dict[str, dict[str, Any]],
    *,
    stable_prefix: str,
) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    for row in rows:
        slug = row["slug"]
        patch = patches.get(slug, {})
        output.append(
            {
                **row,
                "stableId": f"{stable_prefix}:{slug}",
                **patch,
                "provenance": {
                    "sourceId": "titodex-reviewed-mechanics",
                    "scope": "generation-aware candidate",
                    "reviewStatus": "candidate",
                },
            }
        )
    return output


def directory_size(path: Path) -> int:
    return sum(file.stat().st_size for file in path.rglob("*") if file.is_file())


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def create_archive(staging: Path, archive: Path) -> None:
    archive.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".tar", dir=archive.parent, delete=False) as temp:
        tar_path = Path(temp.name)
    try:
        with tarfile.open(tar_path, "w") as tar:
            for file in sorted(staging.rglob("*")):
                if file.is_file() and file.resolve() != archive.resolve():
                    tar.add(file, arcname=file.relative_to(staging).as_posix())
        try:
            subprocess.run(
                ["zstd", "-q", "-19", "-f", str(tar_path), "-o", str(archive)],
                check=True,
            )
        except FileNotFoundError:
            import zstandard

            compressor = zstandard.ZstdCompressor(level=19)
            with tar_path.open("rb") as source, archive.open("wb") as dest:
                compressor.copy_stream(source, dest)
    finally:
        tar_path.unlink(missing_ok=True)


def candidate_archive_url(base_url: str, archive_name: str) -> str:
    parsed = urlsplit(base_url)
    if not parsed.scheme or not parsed.netloc:
        raise ValueError("Base root manifest archiveUrl is not an absolute URL")
    parent = parsed.path.rsplit("/", 1)[0]
    return urlunsplit((parsed.scheme, parsed.netloc, f"{parent}/{archive_name}", "", ""))


def coverage_audit(
    *,
    moves: dict[str, dict[str, Any]],
    abilities: dict[str, dict[str, Any]],
    items: dict[str, dict[str, Any]],
    types: dict[str, dict[str, Any]],
    statuses: list[dict[str, Any]],
    weather: list[dict[str, Any]],
    terrains: list[dict[str, Any]],
    source_commit: str,
    unresolved_items: list[str],
) -> dict[str, Any]:
    count = lambda rows, predicate: sum(1 for row in rows.values() if predicate(row))
    return {
        "schemaVersion": 1,
        "bundleVersion": BUNDLE_VERSION,
        "sourceCommit": source_commit,
        "moves": {
            "records": len(moves),
            "description": count(moves, lambda row: bool(row.get("descriptionZh"))),
            "chineseDescription": count(moves, lambda row: row.get("descriptionLanguage") in LANGUAGE_ZH),
            "effect": count(moves, lambda row: bool(row.get("effect"))),
            "shortEffect": count(moves, lambda row: bool(row.get("shortEffect"))),
            "generation": count(moves, lambda row: row.get("generation") is not None),
            "priority": count(moves, lambda row: row.get("priority") is not None),
            "target": count(moves, lambda row: bool(row.get("target"))),
            "meta": count(moves, lambda row: bool(row.get("metaCategory"))),
            "history": count(moves, lambda row: bool(row.get("history"))),
            "machineMapped": count(moves, lambda row: bool(row.get("machines"))),
            "versionGroupAvailability": count(
                moves, lambda row: bool(row.get("availableVersionGroups"))
            ),
        },
        "abilities": {
            "records": len(abilities),
            "description": count(abilities, lambda row: bool(row.get("descriptionZh"))),
            "chineseDescription": count(abilities, lambda row: row.get("descriptionLanguage") in LANGUAGE_ZH),
            "effect": count(abilities, lambda row: bool(row.get("effect"))),
            "generation": count(abilities, lambda row: row.get("generation") is not None),
            "history": count(abilities, lambda row: bool(row.get("history"))),
            "pokemonAssignments": count(abilities, lambda row: bool(row.get("pokemonAssignments"))),
        },
        "items": {
            "records": len(items),
            "matchedToPinnedSource": count(items, lambda row: row.get("stableId", "").startswith("item:")),
            "attributes": count(items, lambda row: bool(row.get("attributes"))),
            "effect": count(items, lambda row: bool(row.get("effect"))),
            "fling": count(items, lambda row: row.get("flingPower") is not None or bool(row.get("flingEffect"))),
            "versionPrices": count(items, lambda row: bool(row.get("versionPrices"))),
            "machineMapped": count(items, lambda row: bool(row.get("machines"))),
            "versionGroupAvailability": count(
                items, lambda row: bool(row.get("availableVersionGroups"))
            ),
            "auditedVersionPrices": count(
                items, lambda row: bool(row.get("pricesByVersionGroup"))
            ),
            "unresolvedSourceSlugs": unresolved_items,
        },
        "mechanics": {
            "types": len(types),
            "typesWithHistory": sum(bool(row.get("history")) for row in types.values()),
            "statuses": len(statuses),
            "statusesWithDescription": sum(bool(row.get("descriptionZh")) for row in statuses),
            "weather": len(weather),
            "weatherWithDescription": sum(bool(row.get("descriptionZh")) for row in weather),
            "terrains": len(terrains),
            "terrainsWithDescription": sum(bool(row.get("descriptionZh")) for row in terrains),
        },
    }


def build(args: argparse.Namespace) -> dict[str, Any]:
    source_lock = read_json(args.source_lock)
    pokeapi_source = next(
        row for row in source_lock["sources"] if row["sourceId"] == "pokeapi-api-data"
    )
    api_root = fetch_source_checkout(args.api_data, pokeapi_source)
    source_commit = pokeapi_source["commit"]

    base_staging = args.base_staging.resolve()
    output = args.output.resolve()
    staging = output / "staging"
    upload = output / "upload"
    if output == base_staging or output in base_staging.parents or base_staging in output.parents:
        raise ValueError("Output and immutable v19 input must not overlap")
    base_manifest = read_json(base_staging / "manifest.json")
    if base_manifest.get("version") != BASE_VERSION or base_manifest.get("complete") is not True:
        raise ValueError(
            f"Expected complete v{BASE_VERSION} staging, got version={base_manifest.get('version')}"
        )
    for path in (staging, upload):
        if path.exists():
            shutil.rmtree(path)
    output.mkdir(parents=True, exist_ok=True)
    shutil.copytree(base_staging, staging)
    for archive in staging.glob("bundle*.tar.zst"):
        archive.unlink()

    move_labels = read_json(ROOT / "data" / "l10n" / "zh" / "moves.json")
    ability_labels = read_json(ROOT / "data" / "l10n" / "zh" / "abilities.json")
    item_labels = read_json(ROOT / "data" / "l10n" / "zh" / "items.json")
    type_labels = read_json(ROOT / "data" / "l10n" / "zh" / "types.json")
    machine_by_id, machine_by_item = build_machine_indexes(api_root, item_labels)
    move_version_matrix = read_json(MOVE_VERSION_MATRIX)
    item_version_matrix = read_json(ITEM_VERSION_MATRIX)

    old_moves = read_json(staging / "moves.json")
    api_moves = endpoint_by_id(api_root, "move")
    moves: dict[str, dict[str, Any]] = {}
    for move_id, detail in api_moves.items():
        label = move_labels.get(str(move_id))
        if label is None and str(move_id) not in old_moves:
            continue
        moves[str(move_id)] = build_move_record(
            detail,
            existing=old_moves.get(str(move_id)),
            label=label,
            machines=machine_by_id,
            commit=source_commit,
        )
        available = (move_version_matrix.get("moves") or {}).get(str(move_id))
        if available:
            moves[str(move_id)]["availableVersionGroups"] = sorted(set(available))
            moves[str(move_id)]["availabilityProvenance"] = {
                "sourceId": "titodex-v19-version-matrices",
                "scope": "exact version-group availability",
            }
        else:
            moves[str(move_id)]["availabilityStatus"] = "unknown"

    old_abilities = read_json(staging / "abilities.json")
    api_abilities = endpoint_by_id(api_root, "ability")
    abilities: dict[str, dict[str, Any]] = {}
    for ability_id, detail in api_abilities.items():
        label = ability_labels.get(str(ability_id))
        if label is None and str(ability_id) not in old_abilities:
            continue
        abilities[str(ability_id)] = build_ability_record(
            detail,
            existing=old_abilities.get(str(ability_id)),
            label=label,
            commit=source_commit,
        )

    old_items = read_json(staging / "items.json")
    api_items = endpoint_by_slug(api_root, "item")
    item_matrix_by_slug = {
        row["slug"]: row
        for row in (item_version_matrix.get("items") or {}).values()
        if row.get("slug")
    }
    items: dict[str, dict[str, Any]] = {}
    unresolved_items: list[str] = []
    for item_id, existing in old_items.items():
        slug = existing["slug"]
        detail = api_items.get(slug)
        if detail is None:
            items[item_id] = existing
            unresolved_items.append(slug)
        else:
            items[item_id] = build_item_record(
                detail,
                existing=existing,
                machine_by_item=machine_by_item,
                commit=source_commit,
            )
        matrix_entry = item_matrix_by_slug.get(slug)
        if matrix_entry:
            items[item_id]["availableVersionGroups"] = sorted(
                set(matrix_entry.get("versionGroups") or [])
            )
            items[item_id]["availableGenerations"] = sorted(
                set(matrix_entry.get("generations") or [])
            )
            items[item_id]["pricesByVersionGroup"] = matrix_entry.get("prices") or {}
            items[item_id]["availabilityProvenance"] = {
                "sourceId": "titodex-v19-version-matrices",
                "scope": "audited version-group availability and prices",
            }
        else:
            items[item_id]["availabilityStatus"] = "unknown"

    types = enrich_types(read_json(staging / "types.json"), api_root, type_labels, source_commit)
    mechanics = read_json(args.mechanics)
    statuses = merge_mechanics(
        read_json(staging / "status_conditions.json"),
        mechanics["statuses"],
        stable_prefix="status",
    )
    weather = merge_mechanics(
        read_json(staging / "weather.json"), mechanics["weather"], stable_prefix="weather"
    )
    terrains = merge_mechanics(
        read_json(staging / "terrains.json"), mechanics["terrains"], stable_prefix="terrain"
    )

    write_json(staging / "moves.json", moves, compact=True)
    write_json(staging / "abilities.json", abilities, compact=True)
    write_json(staging / "items.json", items, compact=True)
    write_json(staging / "types.json", types, compact=True)
    write_json(staging / "status_conditions.json", statuses, compact=True)
    write_json(staging / "weather.json", weather, compact=True)
    write_json(staging / "terrains.json", terrains, compact=True)
    shutil.copyfile(args.source_lock, staging / "reference_v20_sources.json")
    shutil.copyfile(MOVE_VERSION_MATRIX, staging / "move_version_matrix.json")
    shutil.copyfile(ITEM_VERSION_MATRIX, staging / "item_version_matrix.json")

    catalog_path = staging / "dex_catalog.json"
    catalog = read_json(catalog_path)
    catalog["version"] = 2
    catalog["moves"] = moves
    catalog["abilities"] = abilities
    catalog["abilityPokemonIds"] = {
        ability_id: row["pokemonIds"] for ability_id, row in abilities.items()
    }
    write_json(catalog_path, catalog, compact=True)

    audit = coverage_audit(
        moves=moves,
        abilities=abilities,
        items=items,
        types=types,
        statuses=statuses,
        weather=weather,
        terrains=terrains,
        source_commit=source_commit,
        unresolved_items=unresolved_items,
    )
    write_json(staging / "reference_v20_audit.json", audit)

    published_at = args.published_at or datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    manifest_path = staging / "manifest.json"
    manifest = read_json(manifest_path)
    manifest.update(
        {
            "version": BUNDLE_VERSION,
            "downloadedAt": published_at,
            "moveCount": len(moves),
            "abilityCount": len(abilities),
            "itemCount": len(items),
            "referenceDataAudit": "reference_v20_audit.json",
            "referenceDataSources": "reference_v20_sources.json",
            "referenceDataSourceCommit": source_commit,
            "referenceDataReviewStatus": "candidate",
            "moveVersionMatrix": "move_version_matrix.json",
            "itemVersionMatrix": "item_version_matrix.json",
        }
    )
    schema_features = dict(manifest.get("schemaFeatures") or {})
    schema_features.update(
        {
            "referenceStableIds": 1,
            "moveDetails": 2,
            "abilityDetails": 2,
            "itemDetails": 2,
            "generationMechanics": 1,
        }
    )
    manifest["schemaFeatures"] = schema_features
    manifest["sizeBytes"] = directory_size(staging)
    write_json(manifest_path, manifest)

    if not args.skip_archive:
        archive = staging / ARCHIVE_NAME
        create_archive(staging, archive)
        versioned = upload / CDN_PREFIX
        shutil.copytree(staging, versioned)
        if args.base_root_manifest and args.base_root_manifest.is_file():
            root_manifest = read_json(args.base_root_manifest)
            root_manifest.update(
                {
                    "bundleVersion": BUNDLE_VERSION,
                    "archiveUrl": candidate_archive_url(root_manifest["archiveUrl"], ARCHIVE_NAME),
                    "archiveSha256": sha256_file(versioned / ARCHIVE_NAME),
                    "archiveSizeBytes": (versioned / ARCHIVE_NAME).stat().st_size,
                    "publishedAt": published_at,
                    "moveCount": len(moves),
                    "abilityCount": len(abilities),
                    "itemCount": len(items),
                    "referenceDataSourceCommit": source_commit,
                    "candidate": True,
                }
            )
            upload.mkdir(parents=True, exist_ok=True)
            write_json(upload / "bundle-manifest.candidate.json", root_manifest)

    print(json.dumps(audit, ensure_ascii=False, indent=2))
    print(f"Built local v{BUNDLE_VERSION} candidate at {output}")
    return audit


def main() -> int:
    lock = read_json(SOURCE_LOCK)
    source = next(row for row in lock["sources"] if row["sourceId"] == "pokeapi-api-data")
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    default_api_data = cache_home / "titodex" / "pokeapi-api-data" / source["commit"]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-staging", type=Path, default=DEFAULT_BASE)
    parser.add_argument("--base-root-manifest", type=Path, default=DEFAULT_BASE_ROOT_MANIFEST)
    parser.add_argument("--api-data", type=Path, default=default_api_data)
    parser.add_argument("--source-lock", type=Path, default=SOURCE_LOCK)
    parser.add_argument("--mechanics", type=Path, default=MECHANICS_DATA)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--published-at")
    parser.add_argument("--skip-archive", action="store_true")
    args = parser.parse_args()
    build(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
