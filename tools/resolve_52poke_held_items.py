#!/usr/bin/env python3
"""Resolve 52poke held-item zh names to PokeAPI items and write metadata.

Reads ``data/l10n/zh/held_items_52poke.json``, collects item names that are
missing from the bundle ``items.json``, resolves each zh name to a 52poke item
page's English name, then fetches the PokeAPI item. Writes
``data/l10n/zh/items_52poke_extra.json`` with the new items for
``patch_dex_bundle_v16_held_items.py`` to merge into ``items.json``.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

from fetch_52poke_flavor_text import (
    DEFAULT_BUNDLE,
    ROOT,
    USER_AGENT,
    ZH_HANS_CONVERTER,
    candidate_titles,
    fetch_wikitext,
)

DEFAULT_HELD = ROOT / "data" / "l10n" / "zh" / "held_items_52poke.json"
DEFAULT_ITEMS = ROOT / "dist" / "dex-v16" / "upload" / "v5" / "items.json"
DEFAULT_OUTPUT = ROOT / "data" / "l10n" / "zh" / "items_52poke_extra.json"
POKEAPI_BASE = "https://pokeapi.co/api/v2"
RETRIES = 4

ENNAME_RE = re.compile(r"\{\{N\|[^|]*\|[^|]*\|[^|]*\|([^|}]+)\}\}")


def collect_missing_names(
    held_path: Path, items_path: Path
) -> tuple[set[str], dict[str, str]]:
    held = json.loads(held_path.read_text(encoding="utf-8"))
    items = json.loads(items_path.read_text(encoding="utf-8"))
    by_zh = {item["nameZh"] for item in items.values()}
    missing: set[str] = set()
    zh_to_slug: dict[str, str] = {}
    for entry in held.get("entries", []):
        for version, rows in (entry.get("versions") or {}).items():
            for row in rows:
                name = row.get("itemZh", "")
                if name not in by_zh:
                    missing.add(name)
    return missing, zh_to_slug


def resolve_enname(session: requests.Session, zh_name: str) -> str | None:
    for title in candidate_titles(session, zh_name):
        wikitext = fetch_wikitext(session, title)
        if wikitext is None:
            continue
        match = ENNAME_RE.search(wikitext)
        if match:
            return match.group(1).strip()
        if "道具信息框" in wikitext and title == zh_name:
            # Page exists but template field is missing; stop early.
            return None
    return None


def fetch_item(
    session: requests.Session, slug: str, name_zh: str
) -> dict[str, Any] | None:
    response = session.get(f"{POKEAPI_BASE}/item/{slug}", timeout=30)
    if response.status_code != 200:
        return None
    data = response.json()
    zh_name = next(
        (
            name["name"]
            for name in data.get("names", [])
            if name["language"]["name"] == "zh-Hans"
        ),
        slug,
    )
    zh_flavor = next(
        (
            entry["text"]
            for entry in data.get("flavor_text_entries", [])
            if entry["language"]["name"] == "zh-Hans"
        ),
        "",
    )
    sprites = data.get("sprites") or {}
    return {
        "id": data["id"],
        "slug": slug,
        "nameEn": data["name"],
        "nameZh": name_zh,
        "category": (data.get("category") or {}).get("name", "held-items"),
        "cost": data.get("cost", 0),
        "spriteUrl": sprites.get("default"),
        "descriptionZh": " ".join(zh_flavor.split()),
        "effectZh": " ".join(zh_flavor.split()),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Resolve missing 52poke held-item names to PokeAPI items"
    )
    parser.add_argument("--held-json", type=Path, default=DEFAULT_HELD)
    parser.add_argument("--items-json", type=Path, default=DEFAULT_ITEMS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--delay", type=float, default=0.8)
    args = parser.parse_args()

    missing, _ = collect_missing_names(args.held_json, args.items_json)
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": USER_AGENT,
            "Accept-Language": "zh-CN,zh;q=0.9",
        }
    )
    resolved: dict[str, Any] = {}
    failed: list[str] = []
    unresolved_with_enname: dict[str, str] = {}
    for name in sorted(missing):
        try:
            enname = resolve_enname(session, name)
            if not enname:
                failed.append(name)
                print(f"no-enname {name}", flush=True)
                time.sleep(args.delay)
                continue
            slug = enname.lower().replace(" ", "-").replace("'", "")
            item = None
            for attempt in range(RETRIES):
                try:
                    item = fetch_item(session, slug, name)
                    break
                except requests.RequestException:
                    if attempt == RETRIES - 1:
                        raise
                    time.sleep(2 * (attempt + 1))
            if item is None:
                failed.append(name)
                unresolved_with_enname[name] = enname
                print(f"no-pokeapi {name} ({enname})", flush=True)
            else:
                resolved[name] = item
                print(
                    f"ok {name} -> {item['slug']} "
                    f"(zh: {item['nameZh']}, sprite: {bool(item['spriteUrl'])})",
                    flush=True,
                )
        except requests.RequestException as exc:
            failed.append(name)
            print(f"error {name}: {exc}", flush=True)
        finally:
            payload = {
                "schemaVersion": 1,
                "resolvedAt": datetime.now(timezone.utc)
                .replace(microsecond=0)
                .isoformat(),
                "source": {
                    "name": "52poke wiki + PokeAPI",
                    "license": "PokeAPI data repository: BSD-3-Clause; 52poke: CC BY-NC-SA 3.0",
                },
                "itemsByZhName": resolved,
                "unresolved": sorted(failed),
                "unresolvedWithEnname": unresolved_with_enname,
            }
            args.output.parent.mkdir(parents=True, exist_ok=True)
            temp = args.output.with_suffix(".json.tmp")
            temp.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            try:
                os.replace(temp, args.output)
            except OSError:
                pass
            time.sleep(args.delay)

    payload = {
        "schemaVersion": 1,
        "resolvedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "source": {
            "name": "52poke wiki + PokeAPI",
            "license": "PokeAPI data repository: BSD-3-Clause; 52poke: CC BY-NC-SA 3.0",
        },
        "itemsByZhName": resolved,
        "unresolved": sorted(failed),
        "unresolvedWithEnname": unresolved_with_enname,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temp = args.output.with_suffix(".json.tmp")
    temp.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    for _attempt in range(6):
        try:
            os.replace(temp, args.output)
            break
        except OSError:
            time.sleep(0.5)
    print(
        f"done: {len(resolved)} resolved, {len(failed)} unresolved -> {args.output}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    main()
