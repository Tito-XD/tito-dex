#!/usr/bin/env python3
"""Fetch PokeAPI metadata for the core missing items and resolve zh names.

For each slug in ``data/l10n/zh/missing_items_core.json``, fetches the
PokeAPI item. zh-Hans names come from PokeAPI when available; otherwise the
52poke wiki page (found by English name) supplies the zh name and sprite
filename. Writes ``data/l10n/zh/items_core_extra.json`` for
``patch_dex_bundle_v17_items.py``.
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
    ROOT,
    USER_AGENT,
    fetch_wikitext,
    opensearch_titles,
)

DEFAULT_SLUGS = ROOT / "data" / "l10n" / "zh" / "missing_items_core.json"
DEFAULT_OUTPUT = ROOT / "data" / "l10n" / "zh" / "items_core_extra.json"
POKEAPI_BASE = "https://pokeapi.co/api/v2"
WIKI_BASE = "https://wiki.52poke.com"

ZH_NAME_RE = re.compile(r"\{\{N\|([^|]*)\|[^|]*\|[^|]*\|[^|}]*\}\}")
SPRITE_RE = re.compile(r"\|sprite=([^|\n}]+)")

CATEGORY_ZH = {
    "mega-stones": "携带道具",
    "z-crystals": "携带道具",
    "training": "携带道具",
    "effort-training": "携带道具",
    "collectibles": "携带道具",
    "all-machines": "招式学习器",
    "dynamax-crystals": "极巨结晶",
    "tm-materials": "招式材料",
    "species-candies": "宝可梦糖果",
    "sandwich-ingredients": "料理素材",
    "curry-ingredients": "料理素材",
    "picnic": "料理素材",
    "all-mail": "邮件",
    "data-cards": "数据卡",
    "gameplay": "剧情道具",
    "plot-advancement": "剧情道具",
    "event-items": "剧情道具",
    "loot": "冒险道具",
    "spelunking": "冒险道具",
    "apricorn-box": "冒险道具",
    "mulch": "冒险道具",
    "dex-completion": "冒险道具",
}
EVOLUTION_COLLECTIBLES = {
    "galarica-cuff",
    "galarica-wreath",
    "shoal-salt",
    "shoal-shell",
}


def wiki_file_url(filename: str) -> str:
    import urllib.parse

    return (
        f"{WIKI_BASE}/wiki/Special:FilePath/"
        f"{urllib.parse.quote(filename.replace(' ', '_'))}"
    )


def resolve_zh_via_52poke(
    session: requests.Session, enname: str
) -> tuple[str | None, str | None]:
    candidates = list(opensearch_titles(session, enname))
    queries = [enname, enname.replace("-", " "), f"{enname} 道具"]
    for query in queries:
        params = {
            "action": "query",
            "list": "search",
            "srsearch": query,
            "srlimit": 5,
            "format": "json",
        }
        try:
            response = session.get(
                f"{WIKI_BASE}/api.php", params=params, timeout=30
            )
            candidates.extend(
                item["title"]
                for item in response.json().get("query", {}).get("search", [])
            )
        except (requests.RequestException, ValueError):
            pass
    seen: set[str] = set()
    for title in candidates:
        if not title or title in seen:
            continue
        seen.add(title)
        wikitext = fetch_wikitext(session, title)
        if wikitext is None:
            continue
        zh_match = ZH_NAME_RE.search(wikitext)
        sprite_match = SPRITE_RE.search(wikitext)
        if zh_match or sprite_match:
            zh_name = zh_match.group(1).strip() if zh_match else None
            sprite = sprite_match.group(1).strip() if sprite_match else None
            if "{{!" in (sprite or ""):
                sprite = None
            return zh_name, sprite
    return None, None


def fetch_item(
    session: requests.Session, slug: str
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
        None,
    )
    zh_flavor = next(
        (
            entry["text"]
            for entry in data.get("flavor_text_entries", [])
            if entry["language"]["name"] == "zh-Hans"
        ),
        "",
    )
    sprite_url = (data.get("sprites") or {}).get("default")
    return {
        "slug": slug,
        "nameEn": data["name"],
        "nameZh": zh_name,
        "category": (data.get("category") or {}).get("name", "held-items"),
        "cost": data.get("cost", 0),
        "spriteUrl": sprite_url,
        "descriptionZh": " ".join(zh_flavor.split()),
    }


def inherit_from_base(session: requests.Session, item: dict[str, Any]) -> None:
    if item["nameZh"] and item["descriptionZh"]:
        return
    slug = item["slug"]
    if not slug.endswith("--held"):
        return
    base = slug[: -len("--held")]
    try:
        response = session.get(f"{POKEAPI_BASE}/item/{base}", timeout=30)
    except requests.RequestException:
        return
    if response.status_code != 200:
        return
    data = response.json()
    if not item["nameZh"]:
        item["nameZh"] = next(
            (
                name["name"]
                for name in data.get("names", [])
                if name["language"]["name"] == "zh-Hans"
            ),
            item["nameZh"],
        )
    if not item["descriptionZh"]:
        item["descriptionZh"] = " ".join(
            next(
                (
                    entry["text"]
                    for entry in data.get("flavor_text_entries", [])
                    if entry["language"]["name"] == "zh-Hans"
                ),
                "",
            ).split()
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fetch metadata for the 94 core missing items"
    )
    parser.add_argument("--slugs-json", type=Path, default=DEFAULT_SLUGS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--delay", type=float, default=0.6)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    raw = json.loads(args.slugs_json.read_text(encoding="utf-8"))
    entries = raw.get("items") or [
        {"slug": slug} for slug in raw.get("slugs", [])
    ]
    slugs = [entry["slug"] for entry in entries]
    category_by_slug = {
        entry["slug"]: entry.get("category") for entry in entries
    }
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": USER_AGENT,
            "Accept-Language": "zh-CN,zh;q=0.9",
        }
    )
    items: dict[str, Any] = {}
    if args.output.is_file() and not args.force:
        items = json.loads(args.output.read_text(encoding="utf-8")).get(
            "itemsBySlug", {}
        )
    unresolved: list[str] = []
    for slug in slugs:
        if slug in items and not args.force:
            continue
        try:
            item = fetch_item(session, slug)
            if item is None:
                unresolved.append(slug)
                print(f"no-pokeapi {slug}", flush=True)
                continue
            inherit_from_base(session, item)
            if not item["nameZh"]:
                search_name = item["nameEn"]
                if slug.endswith("--held"):
                    search_name = slug[: -len("--held")].replace("-", " ")
                zh_name, sprite_file = resolve_zh_via_52poke(session, search_name)
                item["nameZh"] = zh_name or item["nameEn"]
                if sprite_file and not item["spriteUrl"]:
                    item["spriteUrl"] = wiki_file_url(sprite_file)
                if not item["nameZh"] or item["nameZh"] == item["nameEn"]:
                    unresolved.append(slug)
            category = category_by_slug.get(slug) or item["category"]
            item["category"] = category
            if item["slug"] in EVOLUTION_COLLECTIBLES:
                item["categoryZh"] = "进化道具"
            else:
                item["categoryZh"] = CATEGORY_ZH.get(category, "其他道具")
            items[slug] = item
            print(
                f"ok {slug:24s} zh={item['nameZh'][:12]:12s} "
                f"sprite={bool(item['spriteUrl'])}",
                flush=True,
            )
        except requests.RequestException as exc:
            unresolved.append(slug)
            print(f"error {slug}: {exc}", flush=True)
        finally:
            payload = {
                "schemaVersion": 1,
                "fetchedAt": datetime.now(timezone.utc)
                .replace(microsecond=0)
                .isoformat(),
                "source": {
                    "name": "PokeAPI + 52poke wiki",
                    "license": "PokeAPI data: CC-BY 4.0; 52poke: CC BY-NC-SA 4.0",
                },
                "itemsBySlug": items,
                "unresolved": sorted(unresolved),
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
        "fetchedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "source": {
            "name": "PokeAPI + 52poke wiki",
            "license": "PokeAPI data: CC-BY 4.0; 52poke: CC BY-NC-SA 4.0",
        },
        "itemsBySlug": items,
        "unresolved": sorted(unresolved),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"done: {len(items)} resolved, {len(unresolved)} unresolved -> {args.output}"
    )
    return 1 if unresolved else 0


if __name__ == "__main__":
    main()
