#!/usr/bin/env python3
"""Map each TM to its latest PokeAPI move type and bundle 52poke SV icons."""

from __future__ import annotations

import argparse
import json
import re
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

from enrich_items_v19 import USER_AGENT, WIKI_API, get_json, latest_zh, png_dimensions

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ITEMS = ROOT / "dist" / "dex-v18" / "staging" / "items.json"
DEFAULT_OUTPUT = ROOT / "data" / "l10n" / "zh" / "tm_v19_enrichment.json"
DEFAULT_SPRITES = ROOT / "data" / "assets" / "item-sprites"
POKEAPI = "https://pokeapi.co/api/v2"

TYPE_ZH = {
    "normal": "一般",
    "fighting": "格斗",
    "flying": "飞行",
    "poison": "毒",
    "ground": "地面",
    "rock": "岩石",
    "bug": "虫",
    "ghost": "幽灵",
    "steel": "钢",
    "fire": "火",
    "water": "水",
    "grass": "草",
    "electric": "电",
    "psychic": "超能力",
    "ice": "冰",
    "dragon": "龙",
    "dark": "恶",
    "fairy": "妖精",
}
MOVE_ZH_FALLBACK = {
    "chilling-water": (
        "泼冷水",
        "水属性招式，并会降低对手的攻击。",
    ),
    "trailblaze": (
        "起草",
        "攻击后会提高自己的速度。",
    ),
    "tera-blast": (
        "太晶爆发",
        "太晶化时会变为对应的太晶属性。",
    ),
}

_thread_local = threading.local()


def session() -> requests.Session:
    cached = getattr(_thread_local, "session", None)
    if cached is None:
        cached = requests.Session()
        cached.headers.update({"User-Agent": USER_AGENT})
        _thread_local.session = cached
    return cached


def json_url(url: str) -> dict[str, Any] | None:
    try:
        response = session().get(url, timeout=30)
        if response.status_code == 200:
            return response.json()
    except (requests.RequestException, ValueError):
        pass
    return None


def resource_id(url: str) -> int:
    match = re.search(r"/(\d+)/?$", url)
    return int(match.group(1)) if match else 0


def resolve_machine(item: dict[str, Any]) -> dict[str, str]:
    slug = item["slug"]
    payload = json_url(f"{POKEAPI}/item/{slug}")
    if not payload:
        return {}
    result = {
        "nameZh": latest_zh(payload.get("names") or [], "name"),
    }
    machines = payload.get("machines") or []
    if not machines:
        return result
    latest = max(
        machines,
        key=lambda entry: resource_id((entry.get("version_group") or {}).get("url", "")),
    )
    machine = json_url((latest.get("machine") or {}).get("url", ""))
    move_url = ((machine or {}).get("move") or {}).get("url", "")
    move = json_url(move_url) if move_url else None
    move_type = ((move or {}).get("type") or {}).get("name", "")
    if move_type:
        move_name_zh = latest_zh((move or {}).get("names") or [], "name")
        move_flavor_zh = latest_zh(
            (move or {}).get("flavor_text_entries") or [], "flavor_text"
        )
        fallback = MOVE_ZH_FALLBACK.get((move or {}).get("name", ""))
        if not move_name_zh and fallback:
            move_name_zh, move_flavor_zh = fallback
        result["moveType"] = move_type
        result["move"] = (move or {}).get("name", "")
        result["moveNameZh"] = move_name_zh
        result["versionGroup"] = (
            (latest.get("version_group") or {}).get("name", "")
        )
        if move_name_zh:
            description = f"可让宝可梦学会「{move_name_zh}」。"
            if move_flavor_zh:
                description += move_flavor_zh
            result["descriptionZh"] = description
            result["effectZh"] = description
            result["descriptionSource"] = "PokeAPI machine + move"
    return result


def fetch_type_icons() -> dict[str, bytes]:
    icons: dict[str, bytes] = {}
    for type_slug, type_zh in TYPE_ZH.items():
        filename = f"Bag TM {type_zh} SV Sprite.png"
        payload = get_json(
            WIKI_API,
            params={
                "action": "query",
                "titles": f"File:{filename}",
                "prop": "imageinfo",
                "iiprop": "url|size|mime",
                "format": "json",
                "formatversion": 2,
            },
        )
        pages = payload.get("query", {}).get("pages", []) if payload else []
        info = (pages[0].get("imageinfo") or [None])[0] if pages else None
        if not info or info.get("mime") != "image/png":
            continue
        try:
            response = session().get(
                info["url"],
                headers={"Referer": "https://wiki.52poke.com/"},
                timeout=35,
            )
        except requests.RequestException:
            continue
        if png_dimensions(response.content) == (160, 160):
            icons[type_slug] = response.content
    return icons


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--items", type=Path, default=DEFAULT_ITEMS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--sprites-dir", type=Path, default=DEFAULT_SPRITES)
    parser.add_argument("--workers", type=int, default=8)
    args = parser.parse_args()

    items = json.loads(args.items.read_text(encoding="utf-8")).values()
    machines = [item for item in items if item.get("categoryZh") == "招式学习器"]
    resolved: dict[str, dict[str, str]] = {}
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {executor.submit(resolve_machine, item): item for item in machines}
        for done, future in enumerate(as_completed(futures), 1):
            item = futures[future]
            result = future.result()
            if result:
                resolved[item["slug"]] = result
            if done % 50 == 0 or done == len(futures):
                print(f"machines {done}/{len(futures)}", flush=True)

    icons = fetch_type_icons()
    args.sprites_dir.mkdir(parents=True, exist_ok=True)
    icon_count = 0
    for slug, result in resolved.items():
        if not slug.startswith("tm"):
            continue
        icon = icons.get(result.get("moveType", ""))
        if icon is None:
            continue
        (args.sprites_dir / f"{slug}.png").write_bytes(icon)
        result["spriteSource"] = f"52poke Bag TM {TYPE_ZH[result['moveType']]} SV"
        icon_count += 1

    payload = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "sources": [
            {"name": "PokeAPI machines + moves", "license": "CC-BY 4.0"},
            {"name": "52poke TM bag icons", "license": "CC BY-NC-SA 4.0"},
        ],
        "itemsBySlug": resolved,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"resolved {len(resolved)} machines; wrote {icon_count} typed TM icons; "
        f"types {len(icons)}/18",
        flush=True,
    )
    return 0 if len(icons) == 18 else 1


if __name__ == "__main__":
    raise SystemExit(main())
