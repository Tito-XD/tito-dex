#!/usr/bin/env python3
"""Fetch PokeAPI zh-Hans names and build TitoDex master Chinese reference catalog."""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from location_zh_resolver import (  # noqa: E402
    load_location_names_en_zh,
    load_slug_overrides,
    resolve_location_area_zh,
)

POKEAPI_BASE = "https://pokeapi.co/api/v2"
OUT_DIR = ROOT / "data" / "l10n" / "zh"

MOVE_CATEGORIES_ZH = {
    "physical": "物理",
    "special": "特殊",
    "status": "变化",
}

STAT_KEYS_ZH = {
    "hp": "HP",
    "attack": "攻击",
    "defense": "防御",
    "special-attack": "特攻",
    "special-defense": "特防",
    "speed": "速度",
}

ITEM_CATEGORIES_ZH = {
    "stat-boosts": "能力提升",
    "effort-drop": "努力值下降",
    "medicine": "药品",
    "other": "其他",
    "in-a-pinch": "危急",
    "picky-healing": " picky 治疗",
    "type-protection": "属性防护",
    "baking-only": "仅烘焙",
    "collectibles": "收藏品",
    "evolution": "进化",
    "spelunking": "探洞",
    "held-items": "携带道具",
    "choice": "选择",
    "effort-training": "努力值训练",
    "bad-held-items": "负面携带",
    "training": "训练",
    "plates": "石板",
    "species-specific": "种族专用",
    "type-enhancement": "属性强化",
    "event-items": "活动道具",
    "gameplay": "游戏",
    "plot-advancement": "剧情",
    "unused": "未使用",
    "liquids": "液体",
    "mulch": "肥料",
    "flutes": " flute",
    "apricorn-balls": "球果球",
    "apricorn-box": "球果盒",
    "data-cards": "数据卡",
    "jewels": "宝石",
    "miracle-shooter": "奇迹射击",
    "mega-stones": "超级石",
    "memories": "存储碟",
    "z-crystals": "Z纯晶",
    "usable-in-battle": "对战可用",
    "capture": "捕获",
    "vitamins": "营养饮料",
    "healing": "回复",
    "pp-recovery": "PP回复",
    "revival": "复活",
    "status-cures": "状态治愈",
    "maturity": "成熟",
    "dex-completion": "图鉴完成",
    "spelunking": "探洞",
    "picnic": "野餐",
}

TYPE_NAMES_ZH = {
    "normal": "一般",
    "fire": "火",
    "water": "水",
    "electric": "电",
    "grass": "草",
    "ice": "冰",
    "fighting": "格斗",
    "poison": "毒",
    "ground": "地面",
    "flying": "飞行",
    "psychic": "超能力",
    "bug": "虫",
    "rock": "岩石",
    "ghost": "幽灵",
    "dragon": "龙",
    "dark": "恶",
    "steel": "钢",
    "fairy": "妖精",
}

EGG_GROUP_ZH = {
    "monster": "怪兽",
    "water1": "水中1",
    "bug": "虫",
    "flying": "飞行",
    "ground": "地面",
    "fairy": "妖精",
    "plant": "植物",
    "humanshape": "人型",
    "water3": "水中3",
    "mineral": "矿物",
    "indeterminate": "不定形",
    "water2": "水中2",
    "ditto": "百变怪",
    "dragon": "龙",
    "no-eggs": "未发现",
}


class PokeApiClient:
    def __init__(self, delay: float = 0.08) -> None:
        self.session = requests.Session()
        self.session.headers["User-Agent"] = "TitoDex-zh-catalog/1.0"
        self.delay = delay
        self._cache: dict[str, Any] = {}

    def get(self, path: str) -> Any:
        url = path if path.startswith("http") else f"{POKEAPI_BASE}{path}"
        if url in self._cache:
            return self._cache[url]
        time.sleep(self.delay)
        response = self.session.get(url, timeout=60)
        response.raise_for_status()
        data = response.json()
        self._cache[url] = data
        return data

    def paginate(self, path: str) -> list[dict[str, Any]]:
        url = f"{POKEAPI_BASE}{path}"
        results: list[dict[str, Any]] = []
        while url:
            payload = self.get(url)
            results.extend(payload.get("results", []))
            url = payload.get("next")
        return results


def localized_genus(genera: list[dict[str, Any]]) -> str:
    for entry in genera:
        code = entry.get("language", {}).get("name", "")
        if code in ("zh-Hans", "zh-hans"):
            return entry.get("genus") or entry.get("name") or ""
    for entry in genera:
        code = entry.get("language", {}).get("name", "")
        if code in ("zh-Hant", "zh-hant"):
            return entry.get("genus") or entry.get("name") or ""
    return ""


def localized_name(names: list[dict[str, Any]], fallback: str) -> str:
    for entry in names:
        code = entry.get("language", {}).get("name", "")
        if code in ("zh-Hans", "zh-hans"):
            return entry.get("name") or fallback
    for entry in names:
        code = entry.get("language", {}).get("name", "")
        if code in ("zh-Hant", "zh-hant"):
            return entry.get("name") or fallback
    return fallback


def localized_text(entries: list[dict[str, Any]], fallback: str = "") -> str:
    for entry in entries:
        code = entry.get("language", {}).get("name", "")
        if code in ("zh-Hans", "zh-hans"):
            text = (entry.get("short_effect") or entry.get("effect") or entry.get("flavor_text") or "").strip()
            if text:
                return text
    for entry in entries:
        if entry.get("language", {}).get("name") == "en":
            text = (entry.get("short_effect") or entry.get("effect") or entry.get("flavor_text") or "").strip()
            if text:
                return text
    return fallback


def english_name(names: list[dict[str, Any]], fallback: str) -> str:
    for entry in names:
        if entry.get("language", {}).get("name") == "en":
            return entry.get("name") or fallback
    return fallback


def slug_from_url(url: str) -> str:
    return url.rstrip("/").split("/")[-1]


def fetch_species(client: PokeApiClient, max_id: int) -> dict[str, dict[str, str]]:
    catalog: dict[str, dict[str, str]] = {}
    for species_ref in client.paginate(f"/pokemon-species?limit={max_id}"):
        sid = slug_from_url(species_ref["url"])
        detail = client.get(species_ref["url"])
        national = detail.get("id")
        en = english_name(detail.get("names", []), detail["name"])
        zh = localized_name(detail.get("names", []), en)
        catalog[str(national)] = {
            "slug": sid,
            "nameEn": en,
            "nameZh": zh,
            "genusZh": localized_genus(detail.get("genera", [])),
        }
    return catalog


def fetch_moves(client: PokeApiClient) -> dict[str, dict[str, str]]:
    catalog: dict[str, dict[str, str]] = {}
    for ref in client.paginate("/move?limit=1000"):
        detail = client.get(ref["url"])
        mid = detail["id"]
        en = english_name(detail.get("names", []), detail["name"])
        zh = localized_name(detail.get("names", []), en)
        category = detail.get("damage_class", {}).get("name", "")
        catalog[str(mid)] = {
            "slug": detail["name"],
            "nameEn": en,
            "nameZh": zh,
            "categoryEn": category,
            "categoryZh": MOVE_CATEGORIES_ZH.get(category, category),
            "typeZh": TYPE_NAMES_ZH.get(detail.get("type", {}).get("name", ""), ""),
        }
    return catalog


def fetch_abilities(client: PokeApiClient) -> dict[str, dict[str, str]]:
    catalog: dict[str, dict[str, str]] = {}
    for ref in client.paginate("/ability?limit=500"):
        detail = client.get(ref["url"])
        aid = detail["id"]
        en = english_name(detail.get("names", []), detail["name"])
        zh = localized_name(detail.get("names", []), en)
        catalog[str(aid)] = {
            "slug": detail["name"],
            "nameEn": en,
            "nameZh": zh,
            "descriptionZh": localized_text(detail.get("effect_entries", [])),
        }
    return catalog


def fetch_items(client: PokeApiClient) -> dict[str, dict[str, str]]:
    catalog: dict[str, dict[str, str]] = {}
    for ref in client.paginate("/item?limit=2500"):
        detail = client.get(ref["url"])
        iid = detail["id"]
        en = english_name(detail.get("names", []), detail["name"])
        zh = localized_name(detail.get("names", []), en)
        category = detail.get("category", {}).get("name", "")
        catalog[str(iid)] = {
            "slug": detail["name"],
            "nameEn": en,
            "nameZh": zh,
            "categoryEn": category,
            "categoryZh": ITEM_CATEGORIES_ZH.get(category, category),
        }
    return catalog


def fetch_natures(client: PokeApiClient) -> dict[str, dict[str, str]]:
    catalog: dict[str, dict[str, str]] = {}
    for ref in client.paginate("/nature?limit=30"):
        detail = client.get(ref["url"])
        en = english_name(detail.get("names", []), detail["name"])
        zh = localized_name(detail.get("names", []), en)
        inc = detail.get("increased_stat", {}) or {}
        dec = detail.get("decreased_stat", {}) or {}
        catalog[detail["name"]] = {
            "nameEn": en,
            "nameZh": zh,
            "increasedStatZh": STAT_KEYS_ZH.get(inc.get("name", ""), inc.get("name", "")),
            "decreasedStatZh": STAT_KEYS_ZH.get(dec.get("name", ""), dec.get("name", "")),
        }
    return catalog


def fetch_egg_groups(client: PokeApiClient) -> dict[str, dict[str, str]]:
    catalog: dict[str, dict[str, str]] = {}
    for ref in client.paginate("/egg-group?limit=20"):
        slug = slug_from_url(ref["url"])
        detail = client.get(ref["url"])
        en = english_name(detail.get("names", []), slug)
        zh = EGG_GROUP_ZH.get(slug, localized_name(detail.get("names", []), en))
        catalog[slug] = {"nameEn": en, "nameZh": zh}
    return catalog


def fetch_location_areas(
    client: PokeApiClient,
) -> tuple[dict[str, dict[str, str]], list[str]]:
    slug_overrides = load_slug_overrides()
    names_en_zh = load_location_names_en_zh()
    existing_path = OUT_DIR / "location_areas.json"
    existing: dict[str, dict[str, str]] = (
        json.loads(existing_path.read_text(encoding="utf-8"))
        if existing_path.is_file()
        else {}
    )
    preserved_sources = {"52poke_wiki", "bulbapedia_langlink", "slug_override"}
    catalog: dict[str, dict[str, str]] = {}
    unresolved: list[str] = []

    for ref in client.paginate("/location-area?limit=2000"):
        detail = client.get(ref["url"])
        slug = detail["name"]
        area_id = str(detail["id"])
        area_en = english_name(detail.get("names", []), slug)
        location_url = detail.get("location", {}).get("url")
        location_en = ""
        if location_url:
            location_detail = client.get(location_url)
            location_en = english_name(location_detail.get("names", []), "")

        label_zh, source = resolve_location_area_zh(
            slug,
            area_name_en=area_en,
            location_name_en=location_en,
            slug_overrides=slug_overrides,
            names_en_zh=names_en_zh,
        )
        previous = existing.get(slug) or {}
        if previous.get("source") in preserved_sources and previous.get("labelZh"):
            label_zh = previous["labelZh"]
            source = previous["source"]
        if source in {"english_fallback", "slug_title"}:
            unresolved.append(slug)

        catalog[slug] = {
            "id": area_id,
            "areaNameEn": area_en,
            "locationNameEn": location_en,
            "labelZh": label_zh,
            "source": source,
        }

    return catalog, unresolved


def fetch_hgss_map_ids() -> dict[str, dict[str, str]]:
    hgss_path = ROOT / "tools" / "hgss_map_list.json"
    entries = json.loads(hgss_path.read_text(encoding="utf-8"))
    names_en_zh = load_location_names_en_zh()
    catalog: dict[str, dict[str, str]] = {}
    for index, entry in enumerate(entries):
        name_en = entry.get("name", "")
        label_zh = names_en_zh.get(name_en, name_en)
        catalog[str(index)] = {
            "nameEn": name_en,
            "code": entry.get("code", ""),
            "labelZh": label_zh,
        }
    return catalog


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-species-id", type=int, default=1025)
    parser.add_argument("--skip-items", action="store_true", help="Skip ~2000 item fetches")
    parser.add_argument("--skip-location-areas", action="store_true")
    parser.add_argument("--only-location-areas", action="store_true")
    args = parser.parse_args()

    client = PokeApiClient()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    items: dict[str, dict[str, str]] = {}
    location_areas: dict[str, dict[str, str]] = {}
    unresolved: list[str] = []
    species: dict[str, dict[str, str]] = {}
    moves: dict[str, dict[str, str]] = {}
    abilities: dict[str, dict[str, str]] = {}
    natures: dict[str, dict[str, str]] = {}
    egg_groups: dict[str, dict[str, str]] = {}

    if args.only_location_areas:
        print("==> location_areas (this takes a few minutes)")
        location_areas, unresolved = fetch_location_areas(client)
        write_json(OUT_DIR / "location_areas.json", location_areas)
        write_json(OUT_DIR / "location_areas_unresolved.json", {"slugs": unresolved})
        print("==> hgss_map_ids")
        hgss_map_ids = fetch_hgss_map_ids()
        write_json(OUT_DIR / "hgss_map_ids.json", hgss_map_ids)
        manifest_path = OUT_DIR / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.is_file() else {}
        manifest.update({
            "locale": "zh-Hans",
            "generatedAt": datetime.now(timezone.utc).isoformat(),
            "pokeapiBase": POKEAPI_BASE,
            "counts": {
                **manifest.get("counts", {}),
                "species": len(json.loads((OUT_DIR / "species.json").read_text())) if (OUT_DIR / "species.json").is_file() else 0,
                "moves": len(json.loads((OUT_DIR / "moves.json").read_text())) if (OUT_DIR / "moves.json").is_file() else 0,
                "abilities": len(json.loads((OUT_DIR / "abilities.json").read_text())) if (OUT_DIR / "abilities.json").is_file() else 0,
                "items": len(json.loads((OUT_DIR / "items.json").read_text())) if (OUT_DIR / "items.json").is_file() else 0,
                "locationAreas": len(location_areas),
                "locationAreasUnresolved": len(unresolved),
                "hgssMapIds": len(hgss_map_ids),
            },
        })
        write_json(OUT_DIR / "manifest.json", manifest)
        print(json.dumps(manifest, ensure_ascii=False, indent=2))
        return 0

    print("==> species")
    species = fetch_species(client, args.max_species_id)
    write_json(OUT_DIR / "species.json", species)

    print("==> moves")
    moves = fetch_moves(client)
    write_json(OUT_DIR / "moves.json", moves)

    print("==> abilities")
    abilities = fetch_abilities(client)
    write_json(OUT_DIR / "abilities.json", abilities)

    if not args.skip_items:
        print("==> items")
        items = fetch_items(client)
        write_json(OUT_DIR / "items.json", items)

    print("==> natures")
    natures = fetch_natures(client)
    write_json(OUT_DIR / "natures.json", natures)

    print("==> egg_groups")
    egg_groups = fetch_egg_groups(client)
    write_json(OUT_DIR / "egg_groups.json", egg_groups)

    write_json(OUT_DIR / "types.json", {k: {"nameEn": k, "nameZh": v} for k, v in TYPE_NAMES_ZH.items()})
    write_json(
        OUT_DIR / "move_categories.json",
        {k: {"nameEn": k, "nameZh": v} for k, v in MOVE_CATEGORIES_ZH.items()},
    )
    write_json(
        OUT_DIR / "stats.json",
        {k: {"nameEn": k, "nameZh": v} for k, v in STAT_KEYS_ZH.items()},
    )

    if not args.skip_location_areas:
        print("==> location_areas (this takes a few minutes)")
        location_areas, unresolved = fetch_location_areas(client)
        write_json(OUT_DIR / "location_areas.json", location_areas)
        write_json(OUT_DIR / "location_areas_unresolved.json", {"slugs": unresolved})

    print("==> hgss_map_ids")
    hgss_map_ids = fetch_hgss_map_ids()
    write_json(OUT_DIR / "hgss_map_ids.json", hgss_map_ids)

    manifest = {
        "locale": "zh-Hans",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "pokeapiBase": POKEAPI_BASE,
        "counts": {
            "species": len(species),
            "moves": len(moves),
            "abilities": len(abilities),
            "items": len(items) if not args.skip_items else 0,
            "natures": len(natures),
            "eggGroups": len(egg_groups),
            "locationAreas": len(location_areas) if not args.skip_location_areas else 0,
            "locationAreasUnresolved": len(unresolved),
            "hgssMapIds": len(hgss_map_ids),
        },
    }
    write_json(OUT_DIR / "manifest.json", manifest)

    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
