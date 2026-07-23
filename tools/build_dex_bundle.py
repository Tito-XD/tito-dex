#!/usr/bin/env python3
"""Build TitoDex offline dex bundle v6 for Cloudflare R2 / CDN.

Output matches flutter/lib/features/dex/dex_cache_store.dart layout.
Published under {cdn_base}/v4/ (bundle v6; v3 and v2 remain for older clients).
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import requests
try:
    import zstandard as zstd
except ImportError:  # pragma: no cover - exercised on maintainer Macs using zstd CLI
    zstd = None  # type: ignore[assignment]
from PIL import Image, UnidentifiedImageError

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
ENCOUNTER_OVERLAY_DIR = ROOT / "data" / "encounters"

try:
    from location_zh_resolver import resolve_location_area_zh  # noqa: E402
except ImportError:
    resolve_location_area_zh = None  # type: ignore[assignment]

from pokemon_forms import (  # noqa: E402
    classify_form,
    form_label_zh,
    form_search_terms,
    is_cosmetic_variety,
)

POKEAPI_BASE = "https://pokeapi.co/api/v2"
TYPE_ICON_BASE = (
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/"
    "sprites/types/generation-iii/colosseum"
)
POKESPRITE_TYPE_ICON_DIR = ROOT / "data" / "assets" / "type_icons"
POKESPRITE_RAW_BASE = (
    "https://raw.githubusercontent.com/msikma/pokesprite/master/misc"
)
BUNDLE_VERSION = 6
BUNDLE_CDN_PREFIX = "v4"
TITODEX_MAX_NATIONAL_ID = 1025
HGSS_MAX_ID = 493
HGSS_VERSION_GROUP = "heartgold-soulsilver"
JOHTO_POKEDEX_NAMES = {"original-johto", "updated-johto"}
HGSS_ENCOUNTER_VERSIONS = {"heartgold", "soulsilver"}
MOVE_LEARN_METHODS = ("level-up", "machine", "egg", "tutor")

EV_STAT_KEYS = {
    "hp": "hp",
    "attack": "attack",
    "defense": "defense",
    "special-attack": "specialAttack",
    "special-defense": "specialDefense",
    "speed": "speed",
}


@dataclass(frozen=True)
class GameEdition:
    slug: str
    label_zh: str
    version_group: str | None
    flavor_versions: tuple[str, ...]
    encounter_versions: frozenset[str]
    icon_slug: str
    fallback_slug: str | None = None


GAME_EDITIONS: tuple[GameEdition, ...] = (
    GameEdition(
        "rgb", "红/绿/蓝", "red-blue", ("red", "blue"),
        frozenset({"red", "blue", "red-japan", "green-japan", "blue-japan"}),
        "red-blue",
    ),
    GameEdition(
        "yellow", "皮卡丘", "yellow", ("yellow",),
        frozenset({"yellow"}), "yellow",
    ),
    GameEdition(
        "gs", "金/银", "gold-silver", ("gold", "silver"),
        frozenset({"gold", "silver"}), "gold-silver",
    ),
    GameEdition(
        "crystal", "水晶", "crystal", ("crystal",),
        frozenset({"crystal"}), "crystal",
    ),
    GameEdition(
        "rs", "红宝石/蓝宝石", "ruby-sapphire", ("ruby", "sapphire"),
        frozenset({"ruby", "sapphire"}), "ruby-sapphire",
    ),
    GameEdition(
        "emerald", "绿宝石", "emerald", ("emerald",),
        frozenset({"emerald"}), "emerald",
    ),
    GameEdition(
        "frlg", "火红/叶绿", "firered-leafgreen", ("firered", "leafgreen"),
        frozenset({"firered", "leafgreen"}), "firered-leafgreen",
    ),
    GameEdition(
        "dp", "钻石/珍珠", "diamond-pearl", ("diamond", "pearl"),
        frozenset({"diamond", "pearl"}), "diamond-pearl",
    ),
    GameEdition(
        "pt", "白金", "platinum", ("platinum",),
        frozenset({"platinum"}), "platinum",
    ),
    GameEdition(
        "hgss", "心金/魂银", "heartgold-soulsilver",
        ("heartgold", "soulsilver"),
        frozenset({"heartgold", "soulsilver"}), "heartgold-soulsilver",
    ),
    GameEdition(
        "bw", "黑/白", "black-white", ("black", "white"),
        frozenset({"black", "white"}), "black-white",
    ),
    GameEdition(
        "bw2", "黑2/白2", "black-2-white-2", ("black-2", "white-2"),
        frozenset({"black-2", "white-2"}), "black-2-white-2",
    ),
    GameEdition(
        "xy", "X/Y", "x-y", ("x", "y"),
        frozenset({"x", "y"}), "x-y",
    ),
    GameEdition(
        "oras", "欧米加红宝石/阿尔法蓝宝石", "omega-ruby-alpha-sapphire",
        ("omega-ruby", "alpha-sapphire"),
        frozenset({"omega-ruby", "alpha-sapphire"}), "omega-ruby-alpha-sapphire",
    ),
    GameEdition(
        "sm", "太阳/月亮", "sun-moon", ("sun", "moon"),
        frozenset({"sun", "moon"}), "sun-moon",
    ),
    GameEdition(
        "usum", "究极之日/月", "ultra-sun-ultra-moon",
        ("ultra-sun", "ultra-moon"),
        frozenset({"ultra-sun", "ultra-moon"}), "ultra-sun-ultra-moon",
    ),
    GameEdition(
        "lgpe", "Let's Go 皮卡丘/伊布", "lets-go-pikachu-lets-go-eevee",
        ("lets-go-pikachu", "lets-go-eevee"),
        frozenset({"lets-go-pikachu", "lets-go-eevee"}),
        "lets-go-pikachu-lets-go-eevee",
    ),
    GameEdition(
        "swsh", "剑/盾", "sword-shield", ("sword", "shield"),
        frozenset({
            "sword", "shield",
            "the-isle-of-armor-sword", "the-isle-of-armor-shield",
            "the-crown-tundra-sword", "the-crown-tundra-shield",
        }), "sword-shield",
    ),
    GameEdition(
        "bdsp", "晶灿钻石/明亮珍珠", "brilliant-diamond-shining-pearl",
        ("brilliant-diamond", "shining-pearl"),
        frozenset({"brilliant-diamond", "shining-pearl"}),
        "brilliant-diamond-shining-pearl", "pt",
    ),
    GameEdition(
        "pla", "传说阿尔宙斯", "legends-arceus", ("legends-arceus",),
        frozenset({"legends-arceus"}), "legends-arceus",
    ),
    GameEdition(
        "sv", "朱/紫", "scarlet-violet", ("scarlet", "violet"),
        frozenset({
            "scarlet", "violet",
            "the-teal-mask-scarlet", "the-teal-mask-violet",
            "the-indigo-disk-scarlet", "the-indigo-disk-violet",
        }), "scarlet-violet",
    ),
    GameEdition(
        "lza", "传说 Z-A", "legends-za", ("legends-za", "mega-dimension"),
        frozenset({"legends-za", "mega-dimension"}), "lza", "sv",
    ),
    GameEdition(
        "champions", "Champions", "champions", ("champions",),
        frozenset({"champions"}), "champions", "sv",
    ),
)

ALL_VERSION_GROUPS = tuple(
    edition.version_group for edition in GAME_EDITIONS if edition.version_group
)

_ENCOUNTER_OVERLAYS: dict[str, dict[str, list[dict[str, Any]]]] | None = None

ICON_SLUG_TO_POKEAPI_VERSION = {
    "red-blue": "red",
    "gold-silver": "gold",
    "ruby-sapphire": "ruby",
    "firered-leafgreen": "firered",
    "diamond-pearl": "diamond",
    "heartgold-soulsilver": "heartgold",
    "black-white": "black",
    "black-2-white-2": "black-2",
    "x-y": "x",
    "omega-ruby-alpha-sapphire": "omega-ruby",
    "sun-moon": "sun",
    "ultra-sun-ultra-moon": "ultra-sun",
    "lets-go-pikachu-lets-go-eevee": "lets-go-pikachu",
    "sword-shield": "sword",
    "brilliant-diamond-shining-pearl": "brilliant-diamond",
    "legends-arceus": "legends-arceus",
    "scarlet-violet": "scarlet",
    "legends-za": "legends-za",
    "champions": "champions",
    "yellow": "yellow",
    "crystal": "crystal",
    "emerald": "emerald",
    "platinum": "platinum",
}

STATUS_CONDITIONS = [
    {"slug": "burn", "nameEn": "Burn", "nameZh": "灼伤"},
    {"slug": "freeze", "nameEn": "Freeze", "nameZh": "冰冻"},
    {"slug": "paralysis", "nameEn": "Paralysis", "nameZh": "麻痹"},
    {"slug": "poison", "nameEn": "Poison", "nameZh": "中毒"},
    {"slug": "bad-poison", "nameEn": "Badly Poisoned", "nameZh": "剧毒"},
    {"slug": "sleep", "nameEn": "Sleep", "nameZh": "睡眠"},
    {"slug": "confusion", "nameEn": "Confusion", "nameZh": "混乱"},
    {"slug": "flinch", "nameEn": "Flinch", "nameZh": "畏缩"},
    {"slug": "trap", "nameEn": "Trapped", "nameZh": "束缚"},
    {"slug": "leech-seed", "nameEn": "Leech Seed", "nameZh": "寄生种子"},
    {"slug": "curse", "nameEn": "Curse", "nameZh": "诅咒"},
    {"slug": "nightmare", "nameEn": "Nightmare", "nameZh": "噩梦"},
    {"slug": "infatuation", "nameEn": "Infatuation", "nameZh": "着迷"},
    {"slug": "torment", "nameEn": "Torment", "nameZh": "无理取闹"},
    {"slug": "disable", "nameEn": "Disable", "nameZh": "定身法"},
    {"slug": "encore", "nameEn": "Encore", "nameZh": "再来一次"},
    {"slug": "perish-song", "nameEn": "Perish Song", "nameZh": "灭亡之歌"},
    {"slug": "bound", "nameEn": "Bound", "nameZh": "紧束"},
    {"slug": "yawn", "nameEn": "Drowsy", "nameZh": "瞌睡"},
    {"slug": "taunt", "nameEn": "Taunt", "nameZh": "挑衅"},
    {"slug": "embargo", "nameEn": "Embargo", "nameZh": "查封"},
    {"slug": "heal-block", "nameEn": "Heal Block", "nameZh": "回复封锁"},
]

WEATHER_CONDITIONS = [
    {"slug": "sun", "nameEn": "Harsh Sunlight", "nameZh": "大晴天"},
    {"slug": "rain", "nameEn": "Rain", "nameZh": "下雨"},
    {"slug": "sandstorm", "nameEn": "Sandstorm", "nameZh": "沙暴"},
    {"slug": "hail", "nameEn": "Hail", "nameZh": "冰雹"},
    {"slug": "snow", "nameEn": "Snow", "nameZh": "下雪"},
    {"slug": "fog", "nameEn": "Fog", "nameZh": "浓雾"},
    {"slug": "strong-winds", "nameEn": "Strong Winds", "nameZh": "乱流"},
    {"slug": "heavy-rain", "nameEn": "Heavy Rain", "nameZh": "大雨"},
    {"slug": "harsh-sunlight", "nameEn": "Extremely Harsh Sunlight", "nameZh": "大日照"},
    {"slug": "strong-winds-primal", "nameEn": "Strong Winds", "nameZh": "德尔塔气流"},
]

TERRAIN_CONDITIONS = [
    {"slug": "electric", "nameEn": "Electric Terrain", "nameZh": "电气场地"},
    {"slug": "grassy", "nameEn": "Grassy Terrain", "nameZh": "青草场地"},
    {"slug": "psychic", "nameEn": "Psychic Terrain", "nameZh": "精神场地"},
    {"slug": "misty", "nameEn": "Misty Terrain", "nameZh": "薄雾场地"},
]

CURATED_ITEM_SLUGS = [
    "potion", "super-potion", "hyper-potion", "max-potion", "full-restore",
    "revive", "max-revive", "antidote", "paralyze-heal", "awakening",
    "burn-heal", "ice-heal", "full-heal", "ether", "max-ether", "elixir",
    "max-elixir", "fresh-water", "soda-pop", "lemonade", "moomoo-milk",
    "x-attack", "x-defense", "x-sp-atk", "x-sp-def", "x-speed", "x-accuracy",
    "dire-hit", "guard-spec", "leftovers", "choice-band", "choice-specs",
    "choice-scarf", "life-orb", "focus-sash", "focus-band", "rocky-helmet",
    "assault-vest", "eviolite", "expert-belt", "muscle-band", "wise-glasses",
    "bright-powder", "quick-claw", "scope-lens", "wide-lens", "zoom-lens",
    "sitrus-berry", "lum-berry", "chesto-berry", "pecha-berry", "rawst-berry",
    "aspear-berry", "persim-berry", "leppa-berry", "oran-berry", "figy-berry",
    "wiki-berry", "mago-berry", "aguav-berry", "iapapa-berry", "liechi-berry",
    "ganlon-berry", "salac-berry", "petaya-berry", "apicot-berry", "lansat-berry",
    "starf-berry", "enigma-berry", "occa-berry", "passho-berry", "wacan-berry",
    "rindo-berry", "yache-berry", "chople-berry", "kebia-berry", "shuca-berry",
    "coba-berry", "payapa-berry", "tanga-berry", "charti-berry", "kasib-berry",
    "haban-berry", "colbur-berry", "babiri-berry", "chilan-berry", "roseli-berry",
    "black-sludge", "toxic-orb", "flame-orb", "sticky-barb", "iron-ball",
    "lagging-tail", "macho-brace", "power-weight", "power-bracer", "power-belt",
    "power-lens", "power-band", "power-anklet", "destiny-knot", "everstone",
    "light-clay", "heat-rock", "damp-rock", "smooth-rock", "icy-rock",
    "terrain-extender", "red-card", "eject-button", "eject-pack", "air-balloon",
    "weakness-policy", "blunder-policy", "throat-spray", "room-service",
    "clear-amulet", "covert-cloak", "punching-glove", "loaded-dice",
    "safety-goggles", "protective-pads", "heavy-duty-boots", "utility-umbrella",
    "kings-rock", "razor-claw", "razor-fang", "metal-coat", "dragon-scale",
    "up-grade", "dubious-disc", "protector", "electirizer", "magmarizer",
    "reaper-cloth", "prism-scale", "sachet", "whipped-dream", "oval-stone",
    "moon-stone", "sun-stone", "fire-stone", "water-stone", "thunder-stone",
    "leaf-stone", "shiny-stone", "dusk-stone", "dawn-stone", "ice-stone",
    "sweet-apple", "tart-apple", "cracked-pot", "chipped-pot", "galarica-cuff",
    "galarica-wreath",     "auspicious-armor", "malicious-armor", "peat-block",
    "black-augurite", "linking-cord", "scroll-of-darkness",
    "scroll-of-waters", "metal-alloy", "ability-shield", "booster-energy",
    "mirror-herb", "ability-patch", "ability-capsule",
    "pp-up", "pp-max", "rare-candy", "exp-share", "lucky-egg", "amulet-coin",
    "smoke-ball", "cleanse-tag", "repel", "super-repel", "max-repel",
    "escape-rope", "poke-ball", "great-ball", "ultra-ball", "master-ball",
    "safari-ball", "net-ball", "dive-ball", "nest-ball", "repeat-ball",
    "timer-ball", "luxury-ball", "premier-ball", "dusk-ball", "heal-ball",
    "quick-ball", "cherish-ball", "fast-ball", "level-ball", "lure-ball",
    "heavy-ball", "love-ball", "friend-ball", "moon-ball", "sport-ball",
    "park-ball", "dream-ball", "beast-ball", "strange-ball",
]

ENCOUNTER_AREA_LABELS_ZH = {
    "pallet-town-area": "真新镇",
    "viridian-city-area": "常磐市",
    "viridian-forest-area": "常磐森林",
    "pewter-city-area": "尼比市",
    "route-1-area": "1号道路",
    "route-2-area": "2号道路",
    "route-24-area": "24号道路",
    "route-25-area": "25号道路",
    "safari-zone-area": "狩猎地带",
    "mt-silver-area": "白银山",
    "national-park-area": "自然公园",
    "bell-tower-1f": "铃铛塔",
    "burned-tower-1f": "烧焦塔",
    "ice-path-1f": "冰雪小径",
    "mt-mortar-1f": "擂钵山",
    "dark-cave-area": "黑暗洞窟",
    "union-cave-1f": "连接洞窟",
    "slowpoke-well-1f": "呆呆兽之井",
    "kalos-berry-fields-area": "树果园（卡洛斯）",
    "unova-roaming-area": "合众地区（游走）",
}


def corrected_pokeapi_encounter_slug(
    version: str, pokemon_id: int | None, slug: str
) -> str | None:
    """Correct a small set of verified semantic errors in PokeAPI encounters."""
    if (
        slug == "team-flare-secret-hq-area"
        and (version, pokemon_id) in {("black", 641), ("white", 642)}
    ):
        return "unova-roaming-area"
    if (
        slug == "new-mauville-area"
        and version in {"sun", "moon"}
        and pokemon_id in {100, 101}
    ):
        # Voltorb/Electrode are not wild or Island Scan encounters in Sun/Moon.
        return None
    return slug

TYPE_NAMES = [
    "normal",
    "fire",
    "water",
    "electric",
    "grass",
    "ice",
    "fighting",
    "poison",
    "ground",
    "flying",
    "psychic",
    "bug",
    "rock",
    "ghost",
    "dragon",
    "dark",
    "steel",
    "fairy",
]

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


def type_name_zh(type_key: str) -> str:
    return TYPE_NAMES_ZH.get(type_key, type_key)

EGG_GROUP_ZH = {
    "monster": "怪兽",
    "water1": "水中1",
    "bug": "虫",
    "flying": "飞行",
    "ground": "陆上",
    "fairy": "妖精",
    "plant": "植物",
    "humanshape": "人形",
    "water3": "水中3",
    "mineral": "矿物",
    "indeterminate": "不定形",
    "water2": "水中2",
    "ditto": "百变怪",
    "dragon": "龙",
    "no-eggs": "未发现",
}


@dataclass
class TypeDamageRelations:
    double_damage_to: set[str]
    half_damage_to: set[str]
    no_damage_to: set[str]


class PokeApiBuilder:
    def __init__(self, delay_s: float = 0.35) -> None:
        self.session = requests.Session()
        self.session.headers["User-Agent"] = "TitoDex-dex-bundle-builder/1.0"
        self.delay_s = delay_s
        self.move_cache: dict[int, dict[str, Any]] = {}
        self.ability_cache: dict[tuple[str, bool], dict[str, Any]] = {}
        self.ability_index: dict[int, dict[str, Any]] = {}
        self.type_relations: dict[str, TypeDamageRelations] = {}
        self.form_sprite_jobs: dict[str, tuple[str | None, str | None]] = {}

    def _get_json(self, path: str) -> dict[str, Any]:
        url = path if path.startswith("http") else f"{POKEAPI_BASE}{path}"
        last_error: Exception | None = None
        for attempt in range(5):
            time.sleep(self.delay_s)
            try:
                response = self.session.get(url, timeout=90)
                response.raise_for_status()
                return response.json()
            except requests.RequestException as exc:
                last_error = exc
                wait = min(30.0, 2.0 ** attempt)
                print(f"  warn: retry {attempt + 1}/5 {path}: {exc}", file=sys.stderr)
                time.sleep(wait)
        raise last_error  # type: ignore[misc]

    def _get_json_list(self, path: str) -> list[Any]:
        url = path if path.startswith("http") else f"{POKEAPI_BASE}{path}"
        last_error: Exception | None = None
        for attempt in range(5):
            time.sleep(self.delay_s)
            try:
                response = self.session.get(url, timeout=90)
                response.raise_for_status()
                return response.json()
            except requests.RequestException as exc:
                last_error = exc
                wait = min(30.0, 2.0 ** attempt)
                print(f"  warn: retry {attempt + 1}/5 {path}: {exc}", file=sys.stderr)
                time.sleep(wait)
        raise last_error  # type: ignore[misc]

    def load_type_relations(self) -> dict[str, TypeDamageRelations]:
        if self.type_relations:
            return self.type_relations
        index = self._get_json("/type?limit=100")
        for result in index["results"]:
            name = result["name"]
            if name not in TYPE_NAMES:
                continue
            detail = self._get_json(f"/type/{name}")
            damage = detail["damage_relations"]
            self.type_relations[name] = TypeDamageRelations(
                double_damage_to={
                    item["name"] for item in damage.get("double_damage_to", [])
                },
                half_damage_to={
                    item["name"] for item in damage.get("half_damage_to", [])
                },
                no_damage_to={item["name"] for item in damage.get("no_damage_to", [])},
            )
        return self.type_relations

    def type_icon_url(self, type_name: str) -> str | None:
        detail = self._get_json(f"/type/{type_name}")
        sprites = detail.get("sprites") or {}
        gen3 = sprites.get("generation-iii") or {}
        colosseum = gen3.get("colosseum") or {}
        url = colosseum.get("name_icon")
        if url:
            return url
        # fairy (and some types) use extended id e.g. 10001.png in colosseum set
        type_id = detail.get("id")
        if type_id is not None:
            # fairy uses extended colosseum id 10001
            lookup_id = 10001 if type_name == "fairy" else type_id
            return f"{TYPE_ICON_BASE}/{lookup_id}.png"
        return None

    def pokesprite_type_icon_url(self, type_name: str) -> str | None:
        """Resolve Gen 8 type icon URL from pokesprite misc.json."""
        if not hasattr(self, "_pokesprite_type_paths"):
            request = requests.Request(
                "GET",
                "https://raw.githubusercontent.com/msikma/pokesprite/master/data/misc.json",
                headers={"User-Agent": "TitoDex-maintainer/1.0"},
            )
            prepared = self.session.prepare_request(request)
            response = self.session.send(prepared, timeout=60)
            response.raise_for_status()
            misc = response.json()
            mapping: dict[str, str] = {}
            for entry in misc.get("types") or []:
                eng = (entry.get("name") or {}).get("eng")
                files = entry.get("files") or {}
                rel = files.get("gen-8") or (next(iter(files.values()), None) if files else None)
                if eng and rel:
                    mapping[eng] = f"{POKESPRITE_RAW_BASE}/{rel}"
            self._pokesprite_type_paths = mapping
        return self._pokesprite_type_paths.get(type_name)

    def fetch_move(self, move_id: int) -> dict[str, Any]:
        if move_id in self.move_cache:
            return self.move_cache[move_id]
        move = self._get_json(f"/move/{move_id}")
        cached = {
            "id": move_id,
            "nameEn": capitalize(move["name"]),
            "nameZh": localized_name(move.get("names", []), move["name"]),
            "type": move["type"]["name"],
            "category": move["damage_class"]["name"],
        }
        for key in ("power", "accuracy", "pp"):
            if move.get(key) is not None:
                cached[key] = move[key]
        self.move_cache[move_id] = cached
        return cached

    def fetch_ability(self, slug: str, *, is_hidden: bool) -> dict[str, Any]:
        cache_key = (slug, is_hidden)
        if cache_key in self.ability_cache:
            return self.ability_cache[cache_key]
        detail = self._get_json(f"/ability/{slug}")
        ability_id = detail["id"]
        ability = {
            "id": ability_id,
            "nameEn": capitalize(detail["name"]),
            "nameZh": localized_name(detail.get("names", []), detail["name"]),
            "descriptionZh": ability_description_zh(detail),
            "isHidden": is_hidden,
        }
        self.ability_cache[cache_key] = ability
        return ability

    def register_ability(self, ability: dict[str, Any], pokemon_id: int) -> None:
        ability_id = ability["id"]
        entry = self.ability_index.setdefault(
            ability_id,
            {
                "nameEn": ability["nameEn"],
                "nameZh": ability["nameZh"],
                "descriptionZh": ability["descriptionZh"],
                "pokemonIds": [],
            },
        )
        if pokemon_id not in entry["pokemonIds"]:
            entry["pokemonIds"].append(pokemon_id)

    def fetch_abilities(
        self, ability_entries: list[dict[str, Any]], pokemon_id: int
    ) -> list[dict[str, Any]]:
        abilities: list[dict[str, Any]] = []
        for entry in ability_entries:
            slug = entry["ability"]["name"]
            is_hidden = entry.get("is_hidden", False)
            ability = self.fetch_ability(slug, is_hidden=is_hidden)
            self.register_ability(ability, pokemon_id)
            abilities.append(
                {
                    "nameEn": ability["nameEn"],
                    "nameZh": ability["nameZh"],
                    "descriptionZh": ability["descriptionZh"],
                    "isHidden": is_hidden,
                }
            )
        abilities.sort(key=lambda item: (item["isHidden"], item["nameZh"]))
        return abilities

    def build_forms(
        self,
        *,
        species_id: int,
        species: dict[str, Any],
        default_pokemon: dict[str, Any],
        species_name_zh: str,
        cdn_base: str,
        default_move_sets: dict[str, dict[str, list[dict[str, Any]]]],
        default_abilities: list[dict[str, Any]],
        obtain_locations_by_game: dict[str, list[dict[str, Any]]],
        obtain_locations_by_version: dict[str, list[dict[str, Any]]],
    ) -> tuple[list[dict[str, Any]], list[str], set[int]]:
        """Build meaningful PokeAPI varieties and every nested form resource.

        A species with one Pokémon entity and one form resource has no selector
        value, so it emits no ``forms`` array. Default battle data is reused
        from ``build_detail``; non-default entities are computed once even when
        they expose many cosmetic form resources (for example Alcremie).
        """
        forms: list[dict[str, Any]] = []
        search_terms: set[str] = set()
        multi_form_pokemon_ids: set[int] = set()
        varieties = species.get("varieties") or [
            {
                "is_default": True,
                "pokemon": {
                    "name": default_pokemon["name"],
                    "url": f"{POKEAPI_BASE}/pokemon/{default_pokemon['id']}/",
                },
            }
        ]

        candidates: list[
            tuple[dict[str, Any], dict[str, Any], list[dict[str, Any]]]
        ] = []
        for variety in varieties:
            ref = variety["pokemon"]
            variety_is_default = bool(variety.get("is_default"))
            pokemon = (
                default_pokemon
                if variety_is_default
                else self._get_json(ref["url"])
            )
            form_refs = list(pokemon.get("forms") or [])
            if not form_refs:
                form_refs = [
                    {
                        "name": pokemon["name"],
                        "url": "",
                    }
                ]
            candidates.append((variety, pokemon, form_refs))

        total_records = sum(len(form_refs) for _, _, form_refs in candidates)
        if total_records < 2:
            return [], [], set()

        relations = self.load_type_relations()
        default_remote_sprite = sprite_url(default_pokemon.get("sprites") or {})
        for variety, pokemon, form_refs in candidates:
            variety_is_default = bool(variety.get("is_default"))
            pokemon_id = int(pokemon["id"])
            pokemon_slug = pokemon["name"]
            entity_has_multiple_forms = len(form_refs) > 1
            if entity_has_multiple_forms:
                multi_form_pokemon_ids.add(pokemon_id)

            entity_cosmetic_only = not variety_is_default and is_cosmetic_variety(
                default_pokemon,
                pokemon,
            )

            if variety_is_default:
                abilities = default_abilities
                move_sets = default_move_sets
            else:
                abilities = self.fetch_abilities(
                    pokemon.get("abilities", []),
                    species_id,
                )
                move_sets = {}
                for version_group in ALL_VERSION_GROUPS:
                    move_set = fetch_move_set_for_version_group(
                        self,
                        pokemon.get("moves", []),
                        version_group,
                    )
                    if any(move_set.values()):
                        move_sets[version_group] = move_set

            for form_index, form_ref in enumerate(form_refs):
                form_url = str(form_ref.get("url") or "")
                form_meta = self._get_json(form_url) if form_url else {}
                record_key = str(
                    form_meta.get("name") or form_ref.get("name") or pokemon_slug
                )
                record_is_default = variety_is_default and bool(
                    form_meta.get("is_default", form_index == 0)
                )
                form_name_zh = localized_optional_name(
                    form_meta.get("form_names", [])
                )
                full_name_zh = localized_optional_name(form_meta.get("names", []))
                name_zh = form_label_zh(
                    species_name_zh,
                    species["name"],
                    record_key,
                    upstream_form_name_zh=full_name_zh or form_name_zh,
                    is_default=record_is_default,
                )
                is_battle_only = bool(form_meta.get("is_battle_only"))
                is_mega = bool(form_meta.get("is_mega"))
                cosmetic_only = (
                    entity_cosmetic_only
                    or (entity_has_multiple_forms and not record_is_default)
                ) and not is_battle_only
                kind = classify_form(
                    species["name"],
                    record_key,
                    is_battle_only=is_battle_only,
                    is_mega=is_mega,
                    cosmetic_only=cosmetic_only,
                )
                obtain_by_game = filter_form_obtain_locations(
                    obtain_locations_by_game,
                    pokemon_id,
                    form_key=record_key,
                    entity_has_multiple_forms=entity_has_multiple_forms,
                )
                obtain_by_version = filter_form_obtain_locations(
                    obtain_locations_by_version,
                    pokemon_id,
                    form_key=record_key,
                    entity_has_multiple_forms=entity_has_multiple_forms,
                )

                form_types = form_meta.get("types") or pokemon.get("types", [])
                types = extract_types(form_types)
                multipliers = compute_defensive_multipliers(types, relations)
                stab = compute_stab_super_effective(types, relations)

                pokemon_sprites = pokemon.get("sprites") or {}
                form_sprites = form_meta.get("sprites") or {}
                remote_sprite = sprite_url(form_sprites) or sprite_url(
                    pokemon_sprites
                )
                reuses_default_visual = bool(
                    remote_sprite
                    and default_remote_sprite
                    and remote_sprite == default_remote_sprite
                )

                if record_is_default or cosmetic_only or reuses_default_visual:
                    sprite_cdn = (
                        f"{cdn_base}/{BUNDLE_CDN_PREFIX}/sprites/{species_id}.png"
                    )
                    artwork_cdn = (
                        f"{cdn_base}/{BUNDLE_CDN_PREFIX}/artwork/{species_id}.png"
                    )
                    local_sprite = f"sprites/{species_id}.png"
                else:
                    form_id = form_meta.get("id")
                    asset_key = str(form_id or f"pokemon-{pokemon_id}-{form_index}")
                    sprite_cdn = None
                    artwork_cdn = None
                    local_sprite = None
                    if remote_sprite:
                        sprite_cdn = (
                            f"{cdn_base}/{BUNDLE_CDN_PREFIX}/sprites/forms/"
                            f"{asset_key}.png"
                        )
                        local_sprite = f"sprites/forms/{asset_key}.png"
                        # One compact sprite is sufficient for visually distinct
                        # forms.  High-resolution form artwork is intentionally
                        # not duplicated into the bundle.
                        self.form_sprite_jobs[asset_key] = (remote_sprite, None)

                version_group = (form_meta.get("version_group") or {}).get("name")
                available_groups = sorted(move_sets)
                obtainable_groups = sorted(
                    key for key, locations in obtain_by_game.items() if locations
                )
                has_battle_data = bool(
                    types
                    and parse_base_stats(pokemon.get("stats", []))
                    and abilities
                    and move_sets
                )
                sources = [
                    str((variety.get("pokemon") or {}).get("url") or ""),
                    form_url,
                ]
                entry: dict[str, Any] = {
                    "key": record_key,
                    "pokemonId": pokemon_id,
                    "nameEn": capitalize(record_key),
                    "nameZh": name_zh,
                    "kind": kind,
                    "formGroup": kind,
                    "isDefault": record_is_default,
                    "isBattleOnly": is_battle_only,
                    "isMega": is_mega,
                    "isCosmetic": cosmetic_only,
                    "availableVersionGroups": available_groups,
                    "obtainableVersionGroups": obtainable_groups,
                    "obtainable": not is_battle_only,
                    "eventOnly": False,
                    "deprecated": False,
                    "inheritsFromDefault": cosmetic_only,
                    "dataCompleteness": "complete" if has_battle_data else "partial",
                    "sources": sorted(source for source in sources if source),
                    "types": types,
                    "heightDm": pokemon.get("height", 0),
                    "weightHg": pokemon.get("weight", 0),
                    "baseStats": parse_base_stats(pokemon.get("stats", [])),
                    "typeMultipliers": multipliers,
                    "stabSuperEffective": stab,
                    "abilities": abilities,
                    "obtainLocationsByGame": obtain_by_game,
                    "obtainLocationsByVersion": obtain_by_version,
                    "moveSets": move_sets,
                }
                if sprite_cdn:
                    entry["spriteUrl"] = sprite_cdn
                if artwork_cdn:
                    entry["artworkUrl"] = artwork_cdn
                if local_sprite:
                    entry["localSpritePath"] = local_sprite
                if form_meta.get("id") is not None:
                    entry["formId"] = form_meta["id"]
                if form_name_zh:
                    entry["formNameZh"] = form_name_zh
                if version_group:
                    entry["introducedVersionGroup"] = version_group
                forms.append(entry)
                search_terms.update(
                    form_search_terms(
                        species["name"],
                        record_key,
                        name_zh,
                        form_name_zh,
                    )
                )

        forms.sort(
            key=lambda item: (
                not item["isDefault"],
                item["pokemonId"],
                item.get("formId") or 0,
                item["key"],
            )
        )
        return forms, sorted(search_terms), multi_form_pokemon_ids

    def build_detail(
        self, pokemon_id: int, cdn_base: str
    ) -> tuple[dict, dict, str | None]:
        pokemon = self._get_json(f"/pokemon/{pokemon_id}")
        species = self._get_json(f"/pokemon-species/{pokemon_id}")
        relations = self.load_type_relations()
        cdn_prefix = BUNDLE_CDN_PREFIX

        types = extract_types(pokemon["types"])
        sprites_payload = pokemon.get("sprites") or {}
        sprite_remote = sprite_url(sprites_payload)
        sprite_cdn = f"{cdn_base}/{cdn_prefix}/sprites/{pokemon_id}.png"
        artwork_cdn = f"{cdn_base}/{cdn_prefix}/artwork/{pokemon_id}.png"
        from pokeapi_assets import animated_sprite_url, build_sprite_url_map

        sprite_urls_by_version = {
            vg: f"{cdn_base}/{cdn_prefix}/sprites/by-version/{vg}/{pokemon_id}.png"
            for vg in build_sprite_url_map(sprites_payload)
        }
        animated_cdn = (
            f"{cdn_base}/{cdn_prefix}/sprites/animated/{pokemon_id}.gif"
            if animated_sprite_url(sprites_payload)
            else None
        )
        species_name_zh = localized_name(species.get("names", []), pokemon["name"])

        summary = {
            "id": pokemon_id,
            "nameEn": capitalize(pokemon["name"]),
            "nameZh": species_name_zh,
            "types": types,
            "spriteUrl": sprite_cdn,
            "artworkUrl": artwork_cdn,
            "localSpritePath": f"sprites/{pokemon_id}.png",
            "pokedexNumbers": parse_pokedex_numbers(species.get("pokedex_numbers", [])),
            "spriteUrlsByVersion": sprite_urls_by_version,
        }
        if animated_cdn:
            summary["animatedSpriteUrl"] = animated_cdn

        profile = compute_defensive_profile(types, relations)
        multipliers = compute_defensive_multipliers(types, relations)
        stab = compute_stab_super_effective(types, relations)
        base_stats = parse_base_stats(pokemon["stats"])
        johto = johto_dex_number(species.get("pokedex_numbers", []))
        flavor_entries = parse_flavor_entries(
            species.get("flavor_text_entries", []), cdn_base
        )
        move_entries = pokemon.get("moves", [])
        move_set = fetch_move_set_for_version_group(
            self, move_entries, HGSS_VERSION_GROUP
        )
        move_sets: dict[str, dict[str, list[dict[str, Any]]]] = {}
        for version_group in ALL_VERSION_GROUPS:
            group_moves = fetch_move_set_for_version_group(
                self, move_entries, version_group
            )
            if any(group_moves.values()):
                move_sets[version_group] = group_moves
        if HGSS_VERSION_GROUP not in move_sets:
            move_sets[HGSS_VERSION_GROUP] = move_set

        abilities = self.fetch_abilities(pokemon.get("abilities", []), pokemon_id)
        (
            obtain_locations_by_game,
            obtain_locations_by_version,
        ) = fetch_species_obtain_locations(self, species, pokemon_id)
        (
            forms,
            form_search_terms,
            multi_form_pokemon_ids,
        ) = self.build_forms(
            species_id=pokemon_id,
            species=species,
            default_pokemon=pokemon,
            species_name_zh=species_name_zh,
            cdn_base=cdn_base,
            default_move_sets=move_sets,
            default_abilities=abilities,
            obtain_locations_by_game=obtain_locations_by_game,
            obtain_locations_by_version=obtain_locations_by_version,
        )
        if multi_form_pokemon_ids:
            obtain_locations_by_game = mark_multi_form_encounters_ambiguous(
                obtain_locations_by_game,
                multi_form_pokemon_ids,
            )
            obtain_locations_by_version = mark_multi_form_encounters_ambiguous(
                obtain_locations_by_version,
                multi_form_pokemon_ids,
            )
        if forms:
            summary["formSearchTerms"] = form_search_terms
        obtain_locations = obtain_locations_by_game.get(
            HGSS_VERSION_GROUP,
            [],
        )
        gender_female = gender_female_percent(species.get("gender_rate"))
        egg_groups = [
            EGG_GROUP_ZH.get(g["name"], g["name"]) for g in species.get("egg_groups", [])
        ]
        hatch_counter = species.get("hatch_counter")
        base_happiness = species.get("base_happiness")
        capture_rate = species.get("capture_rate")
        ev_yield = parse_ev_yield(pokemon.get("stats", []))

        evolution_url = species.get("evolution_chain", {}).get("url")
        evolution = None
        if evolution_url:
            evolution = fetch_evolution_chain(self, evolution_url, cdn_base)

        detail = {
            "summary": summary,
            "genusZh": genus_zh(species.get("genera", [])),
            "heightDm": pokemon.get("height", 0),
            "weightHg": pokemon.get("weight", 0),
            "weaknesses": profile["weaknesses"],
            "resistances": profile["resistances"],
            "immunities": profile["immunities"],
            "stabSuperEffective": profile["stab"],
            "typeMultipliers": multipliers,
            "flavorEntries": flavor_entries,
            "moveSet": move_set,
            "moveSets": move_sets,
            "abilities": abilities,
            "obtainLocations": obtain_locations,
            "obtainLocationsByGame": obtain_locations_by_game,
            "obtainLocationsByVersion": obtain_locations_by_version,
            "eggGroups": egg_groups,
            "forms": forms,
        }
        if base_happiness is not None:
            detail["baseHappiness"] = base_happiness
        if capture_rate is not None:
            detail["captureRate"] = capture_rate
        if ev_yield:
            detail["evYield"] = ev_yield
        if johto is not None:
            detail["johtoDexNumber"] = johto
        if base_stats:
            detail["baseStats"] = base_stats
        if gender_female is not None:
            detail["genderFemalePercent"] = gender_female
        if hatch_counter is not None:
            detail["hatchCounter"] = hatch_counter
        if evolution is not None:
            detail["evolutionChain"] = evolution

        return summary, detail, sprite_remote


def capitalize(value: str) -> str:
    return value[:1].upper() + value[1:] if value else value


def localized_name(names: list[dict[str, Any]], fallback: str) -> str:
    for entry in names:
        code = entry.get("language", {}).get("name", "")
        if code in ("zh-Hans", "zh-hans"):
            return entry["name"]
    for entry in names:
        code = entry.get("language", {}).get("name", "")
        if code in ("zh-Hant", "zh-hant"):
            return entry["name"]
    return capitalize(fallback)


def localized_optional_name(names: list[dict[str, Any]]) -> str | None:
    """Return only a real upstream Chinese translation, without EN fallback."""
    for language_code in ("zh-Hans", "zh-hans", "zh-Hant", "zh-hant"):
        for entry in names:
            if entry.get("language", {}).get("name") == language_code:
                value = (entry.get("name") or "").strip()
                if value:
                    return value
    return None


def genus_zh(genera: list[dict[str, Any]]) -> str:
    for entry in genera:
        code = entry.get("language", {}).get("name", "")
        if code in ("zh-Hans", "zh-hans"):
            return entry["genus"]
    return genera[0]["genus"] if genera else ""


def extract_types(types: list[dict[str, Any]]) -> list[str]:
    sorted_types = sorted(types, key=lambda item: item["slot"])
    return [item["type"]["name"] for item in sorted_types]


def sprite_url(sprites: dict[str, Any]) -> str | None:
    """Legacy default: HGSS in-game sprite, then home/official artwork."""
    from pokeapi_assets import official_artwork_url, sprite_url_for_version_group

    return (
        sprite_url_for_version_group(sprites, "heartgold-soulsilver")
        or official_artwork_url(sprites)
        or sprites.get("front_default")
    )


def id_from_url(url: str) -> int:
    return int(urlparse(url).path.rstrip("/").split("/")[-1])


def johto_dex_number(entries: list[dict[str, Any]]) -> int | None:
    for entry in entries:
        if entry.get("pokedex", {}).get("name") in JOHTO_POKEDEX_NAMES:
            return entry["entry_number"]
    return None


def parse_pokedex_numbers(entries: list[dict[str, Any]]) -> dict[str, int]:
    result: dict[str, int] = {}
    for entry in entries:
        slug = entry.get("pokedex", {}).get("name")
        if slug:
            result[slug] = entry["entry_number"]
    return result


def _load_location_area_catalog() -> dict[str, str]:
    catalog_path = ROOT / "data" / "l10n" / "zh" / "location_areas.json"
    if not catalog_path.is_file():
        return {}
    data = json.loads(catalog_path.read_text(encoding="utf-8"))
    labels: dict[str, str] = {}
    for slug, entry in data.items():
        if not isinstance(entry, dict):
            continue
        label = entry.get("labelZh")
        if not label:
            continue
        labels[slug] = label
        area_id = entry.get("id")
        if area_id:
            labels[str(area_id)] = label
    return labels


_LOCATION_AREA_CATALOG: dict[str, str] | None = None
_LOCATION_AREA_ID_TO_SLUG: dict[str, str] = {}


def encounter_area_label_zh(slug: str) -> str:
    global _LOCATION_AREA_CATALOG, _LOCATION_AREA_ID_TO_SLUG
    if _LOCATION_AREA_CATALOG is None:
        _LOCATION_AREA_CATALOG = _load_location_area_catalog()
        catalog_path = ROOT / "data" / "l10n" / "zh" / "location_areas.json"
        if catalog_path.is_file():
            data = json.loads(catalog_path.read_text(encoding="utf-8"))
            for entry_slug, entry in data.items():
                if isinstance(entry, dict) and entry.get("id"):
                    _LOCATION_AREA_ID_TO_SLUG[str(entry["id"])] = entry_slug

    if slug in _LOCATION_AREA_CATALOG:
        return _LOCATION_AREA_CATALOG[slug]
    if slug in ENCOUNTER_AREA_LABELS_ZH:
        return ENCOUNTER_AREA_LABELS_ZH[slug]
    if resolve_location_area_zh is not None:
        label, _source = resolve_location_area_zh(slug)
        return label
    route_match = re.match(r"^route-(\d+)-", slug)
    if route_match:
        return f"{route_match.group(1)}号道路"
    return slug.replace("-area", "").replace("-", " ")


def ability_description_zh(detail: dict[str, Any]) -> str:
    for entry in detail.get("effect_entries", []):
        language = entry.get("language", {}).get("name", "")
        if language in ("zh-Hans", "zh-hans"):
            short = (entry.get("short_effect") or "").strip()
            if short:
                return short
            effect = (entry.get("effect") or "").strip()
            if effect:
                return effect
    for entry in detail.get("flavor_text_entries", []):
        language = entry.get("language", {}).get("name", "")
        if language in ("zh-Hans", "zh-hans"):
            text = (entry.get("flavor_text") or "").strip()
            if text:
                return text
    for entry in detail.get("effect_entries", []):
        if entry.get("language", {}).get("name") == "en":
            short = (entry.get("short_effect") or "").strip()
            if short:
                return short
    return ""


def parse_obtain_locations_by_version(
    encounters: list[dict[str, Any]],
    *,
    pokemon_id: int | None = None,
    species_id: int | None = None,
    form_key: str | None = None,
    is_default_form: bool | None = None,
) -> dict[str, list[dict[str, Any]]]:
    """Preserve every PokeAPI version and form identity from one response."""
    by_version: dict[str, dict[str, dict[str, Any]]] = {}
    for encounter in encounters:
        area = encounter.get("location_area") or {}
        area_url = area.get("url")
        if not area_url:
            continue
        raw_slug = area.get("name") or area_url.rstrip("/").split("/")[-1]
        if _LOCATION_AREA_CATALOG is None:
            encounter_area_label_zh(raw_slug)
        slug = raw_slug
        if slug.isdigit():
            slug = _LOCATION_AREA_ID_TO_SLUG.get(slug, slug)

        for detail in encounter.get("version_details", []):
            version = detail.get("version", {}).get("name", "")
            if not version:
                continue
            corrected_slug = corrected_pokeapi_encounter_slug(
                version, pokemon_id, slug
            )
            if corrected_slug is None:
                continue
            entry_slug = corrected_slug
            min_levels: list[int] = []
            max_levels: list[int] = []
            methods: set[str] = set()
            conditions: set[str] = set()
            for encounter_detail in detail.get("encounter_details", []):
                min_level = encounter_detail.get("min_level")
                max_level = encounter_detail.get("max_level")
                if isinstance(min_level, int) and min_level > 0:
                    min_levels.append(min_level)
                if isinstance(max_level, int) and max_level > 0:
                    max_levels.append(max_level)
                method = (encounter_detail.get("method") or {}).get("name")
                if method:
                    methods.add(method)
                for condition in encounter_detail.get("condition_values", []):
                    condition_slug = condition.get("name")
                    if condition_slug:
                        conditions.add(condition_slug)

            entry: dict[str, Any] = {
                "areaSlug": entry_slug,
                "areaLabelZh": encounter_area_label_zh(entry_slug),
                "maxChance": detail.get("max_chance") or 0,
                "rateKind": "percentage",
                "rateValue": detail.get("max_chance") or 0,
                "versions": [version],
            }
            if pokemon_id is not None:
                entry["pokemonId"] = pokemon_id
            if species_id is not None:
                entry["speciesId"] = species_id
            if form_key:
                entry["formKey"] = form_key
            if is_default_form is not None:
                entry["isDefaultForm"] = is_default_form
            entry["formAmbiguous"] = False
            if min_levels:
                entry["minLevel"] = min(min_levels)
            if max_levels:
                entry["maxLevel"] = max(max_levels)
            if methods:
                entry["methods"] = sorted(methods)
            if conditions:
                entry["conditions"] = sorted(conditions)
            if entry_slug == "unova-roaming-area":
                entry["conditions"] = sorted(
                    set(entry.get("conditions") or []) | {"roaming"}
                )
            by_version.setdefault(version, {})[entry_slug] = entry

    return {
        version: sorted(entries.values(), key=lambda item: item["areaLabelZh"])
        for version, entries in sorted(by_version.items())
    }


def merge_obtain_location_versions(
    by_version: dict[str, list[dict[str, Any]]],
    versions: set[str] | frozenset[str],
) -> list[dict[str, Any]]:
    """Merge paired editions while retaining which exact versions contain an area."""
    merged: dict[tuple[Any, ...], dict[str, Any]] = {}
    for version in sorted(versions):
        for source in by_version.get(version, []):
            identity = encounter_identity(source)
            current = merged.get(identity)
            if current is None:
                current = dict(source)
                current["versions"] = list(source.get("versions") or [version])
                merged[identity] = current
                continue
            current["maxChance"] = max(
                int(current.get("maxChance") or 0),
                int(source.get("maxChance") or 0),
            )
            if current.get("rateKind") == source.get("rateKind"):
                rate_values = [
                    value
                    for value in (current.get("rateValue"), source.get("rateValue"))
                    if isinstance(value, (int, float))
                ]
                if rate_values:
                    current["rateValue"] = max(rate_values)
            for key, chooser in (("minLevel", min), ("maxLevel", max)):
                values = [
                    value
                    for value in (current.get(key), source.get(key))
                    if isinstance(value, int)
                ]
                if values:
                    current[key] = chooser(values)
            for key in ("versions", "methods", "conditions"):
                current[key] = sorted(
                    set(current.get(key) or []) | set(source.get(key) or [])
                )
    return sorted(merged.values(), key=lambda item: item["areaLabelZh"])


def encounter_identity(entry: dict[str, Any]) -> tuple[Any, ...]:
    """Identity used for source precedence and lossless encounter de-duplication."""
    return (
        entry.get("speciesId"),
        entry.get("pokemonId"),
        entry.get("formKey", entry.get("formSlug")),
        entry.get("areaSlug"),
        tuple(sorted(entry.get("methods") or [])),
        entry.get("teraType"),
        bool(entry.get("isAlpha")),
        bool(entry.get("isTitan")),
        bool(entry.get("isTotem")),
        bool(entry.get("isRaid")),
        bool(entry.get("isFixedEncounter")),
    )


def load_encounter_overlays() -> dict[str, dict[str, list[dict[str, Any]]]]:
    """Load attributed per-version encounter files for gaps in PokeAPI."""
    global _ENCOUNTER_OVERLAYS
    if _ENCOUNTER_OVERLAYS is not None:
        return _ENCOUNTER_OVERLAYS
    overlays: dict[str, dict[str, list[dict[str, Any]]]] = {}
    if not ENCOUNTER_OVERLAY_DIR.is_dir():
        _ENCOUNTER_OVERLAYS = overlays
        return overlays
    payloads: list[tuple[int, Path, dict[str, Any]]] = []
    for path in sorted(ENCOUNTER_OVERLAY_DIR.rglob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        payloads.append((int(payload.get("priority") or 200), path, payload))
    merged_overlays: dict[str, dict[str, dict[tuple[Any, ...], dict[str, Any]]]] = {}
    for _priority, path, payload in sorted(payloads, key=lambda item: (item[0], str(item[1]))):
        version = str(payload.get("version") or "")
        source = payload.get("source") or {}
        if not version or not all(source.get(key) for key in ("name", "url", "license")):
            raise ValueError(
                f"{path}: encounter overlay requires version and attributed "
                "source name/url/license"
            )
        species_entries: dict[str, list[dict[str, Any]]] = {}
        for encounter_key, entries in (payload.get("encounters") or {}).items():
            normalized: list[dict[str, Any]] = []
            for raw in entries:
                entry = dict(raw)
                slug = str(entry.get("areaSlug") or "")
                if not slug:
                    raise ValueError(f"{path}: encounter {encounter_key} has blank areaSlug")
                entry.setdefault("areaLabelZh", encounter_area_label_zh(slug))
                entry.setdefault("maxChance", 0)
                entry.setdefault("rateKind", "percentage")
                entry.setdefault("rateValue", entry.get("maxChance", 0))
                ambiguous = bool(entry.get("formAmbiguous"))
                if not ambiguous and not str(encounter_key).startswith("species:"):
                    raw_id = str(encounter_key).removeprefix("pokemon:")
                    entry.setdefault("pokemonId", int(raw_id))
                if "formKey" not in entry and "formSlug" in entry:
                    entry["formKey"] = entry.pop("formSlug")
                entry.setdefault(
                    "formAmbiguous",
                    entry.get("pokemonId") is None and entry.get("formKey") is None,
                )
                entry["versions"] = [version]
                normalized.append(entry)
            species_entries[str(encounter_key)] = normalized
        version_entries = merged_overlays.setdefault(version, {})
        for encounter_key, entries in species_entries.items():
            bucket = version_entries.setdefault(encounter_key, {})
            for entry in entries:
                bucket[encounter_identity(entry)] = entry
    overlays = {
        version: {
            encounter_key: list(entries.values())
            for encounter_key, entries in buckets.items()
        }
        for version, buckets in merged_overlays.items()
    }
    _ENCOUNTER_OVERLAYS = overlays
    return overlays


def apply_encounter_overlays(
    by_version: dict[str, list[dict[str, Any]]],
    pokemon_id: int,
    *,
    species_id: int | None = None,
    form_key: str | None = None,
    is_default_form: bool | None = None,
) -> dict[str, list[dict[str, Any]]]:
    """Overlay attributed modern-game rows, replacing duplicate version/area rows."""
    result = {version: list(entries) for version, entries in by_version.items()}
    for version, species_entries in load_encounter_overlays().items():
        overlay_entries = species_entries.get(str(pokemon_id))
        if not overlay_entries:
            continue
        normalized_overlay: list[dict[str, Any]] = []
        for source in overlay_entries:
            entry = dict(source)
            if species_id is not None:
                entry.setdefault("speciesId", species_id)
            if form_key:
                # PKHeX form index 0 means the default Pokémon entity, but
                # its display key is not always the species slug
                # (meloetta-aria, meowstic-male, zygarde-50, …).  The
                # species payload already gives us the authoritative PokeAPI
                # variety key, so normalize only index 0 and preserve exact
                # non-default form mappings.
                if entry.get("formIndex") == 0 and is_default_form:
                    entry["formKey"] = form_key
                else:
                    entry.setdefault("formKey", form_key)
            if is_default_form is not None:
                entry.setdefault("isDefaultForm", is_default_form)
            entry.setdefault("formAmbiguous", False)
            normalized_overlay.append(entry)
        merged = {
            encounter_identity(entry): entry for entry in result.get(version, [])
        }
        merged.update(
            {encounter_identity(entry): entry for entry in normalized_overlay}
        )
        result[version] = sorted(
            merged.values(), key=lambda item: item["areaLabelZh"]
        )
    return result


def apply_species_ambiguous_overlays(
    by_version: dict[str, list[dict[str, Any]]], species_id: int
) -> dict[str, list[dict[str, Any]]]:
    """Attach species-only rows once without pretending they are the default form."""
    result = {version: list(entries) for version, entries in by_version.items()}
    lookup_keys = (f"species:{species_id}",)
    for version, overlay_entries in load_encounter_overlays().items():
        species_entries = next(
            (
                overlay_entries[key]
                for key in lookup_keys
                if key in overlay_entries
            ),
            None,
        )
        if not species_entries:
            continue
        normalized: list[dict[str, Any]] = []
        for source in species_entries:
            entry = dict(source)
            entry["speciesId"] = species_id
            entry.pop("pokemonId", None)
            entry.pop("formKey", None)
            entry.pop("formSlug", None)
            entry["formAmbiguous"] = True
            normalized.append(entry)
        merged = {encounter_identity(entry): entry for entry in result.get(version, [])}
        for entry in normalized:
            merged[encounter_identity(entry)] = entry
        result[version] = sorted(
            merged.values(), key=lambda item: item["areaLabelZh"]
        )
    return result


def fetch_obtain_locations(
    builder: PokeApiBuilder,
    pokemon_id: int,
    *,
    species_id: int | None = None,
    form_key: str | None = None,
    is_default_form: bool | None = None,
) -> tuple[
    dict[str, list[dict[str, Any]]],
    dict[str, list[dict[str, Any]]],
]:
    """Fetch the encounter endpoint once, then derive group and exact-version maps."""
    try:
        encounters = builder._get_json_list(f"/pokemon/{pokemon_id}/encounters")
    except requests.RequestException:
        encounters = []
    by_version = apply_encounter_overlays(
        parse_obtain_locations_by_version(
            encounters,
            pokemon_id=pokemon_id,
            species_id=species_id,
            form_key=form_key,
            is_default_form=is_default_form,
        ),
        pokemon_id,
        species_id=species_id,
        form_key=form_key,
        is_default_form=is_default_form,
    )
    by_game = {
        edition.version_group: merge_obtain_location_versions(
            by_version, edition.encounter_versions
        )
        for edition in GAME_EDITIONS
        if edition.version_group and edition.encounter_versions
    }
    return by_game, by_version


def fetch_species_obtain_locations(
    builder: PokeApiBuilder,
    species: dict[str, Any],
    default_pokemon_id: int,
) -> tuple[
    dict[str, list[dict[str, Any]]],
    dict[str, list[dict[str, Any]]],
]:
    """Collect encounters for every PokeAPI variety belonging to one species."""
    species_id = int(species.get("id") or default_pokemon_id)
    varieties = species.get("varieties") or [
        {
            "is_default": True,
            "pokemon": {
                "name": str(default_pokemon_id),
                "url": f"{POKEAPI_BASE}/pokemon/{default_pokemon_id}/",
            },
        }
    ]
    combined_by_version: dict[str, list[dict[str, Any]]] = {}
    seen_pokemon_ids: set[int] = set()
    for variety in varieties:
        pokemon_ref = variety.get("pokemon") or {}
        url = str(pokemon_ref.get("url") or "")
        try:
            pokemon_id = id_from_url(url) if url else default_pokemon_id
        except (TypeError, ValueError):
            continue
        if pokemon_id in seen_pokemon_ids:
            continue
        seen_pokemon_ids.add(pokemon_id)
        form_key = str(pokemon_ref.get("name") or pokemon_id)
        is_default = bool(variety.get("is_default"))
        _by_game, by_version = fetch_obtain_locations(
            builder,
            pokemon_id,
            species_id=species_id,
            form_key=form_key,
            is_default_form=is_default,
        )
        for version, entries in by_version.items():
            combined_by_version.setdefault(version, []).extend(entries)

    combined_by_version = apply_species_ambiguous_overlays(
        combined_by_version, species_id
    )

    by_game = {
        edition.version_group: merge_obtain_location_versions(
            combined_by_version, edition.encounter_versions
        )
        for edition in GAME_EDITIONS
        if edition.version_group and edition.encounter_versions
    }
    return by_game, combined_by_version


def fetch_version_obtain_locations(
    builder: PokeApiBuilder,
    pokemon_id: int,
    versions: set[str],
) -> list[dict[str, Any]]:
    """Backward-compatible helper for callers that need one version subset."""
    _by_game, by_version = fetch_obtain_locations(builder, pokemon_id)
    return merge_obtain_location_versions(by_version, versions)


def filter_form_obtain_locations(
    locations_by_key: dict[str, list[dict[str, Any]]],
    pokemon_id: int,
    *,
    form_key: str,
    entity_has_multiple_forms: bool = False,
) -> dict[str, list[dict[str, Any]]]:
    """Keep one Pokémon entity's rows plus explicitly ambiguous species rows."""
    result: dict[str, list[dict[str, Any]]] = {}
    for key, entries in locations_by_key.items():
        selected: list[dict[str, Any]] = []
        for source in entries:
            if source.get("pokemonId") != pokemon_id and not source.get(
                "formAmbiguous"
            ):
                continue
            entry = dict(source)
            if entity_has_multiple_forms and entry.get("pokemonId") == pokemon_id:
                source_form_key = entry.get("formKey", entry.get("formSlug"))
                has_exact_form_index = entry.get("formIndex") is not None
                if has_exact_form_index:
                    if source_form_key != form_key:
                        continue
                else:
                    entry.pop("formKey", None)
                    entry.pop("formSlug", None)
                    entry["formAmbiguous"] = True
            elif entry.get("pokemonId") == pokemon_id:
                source_form_key = entry.get("formKey", entry.get("formSlug"))
                if source_form_key and source_form_key != form_key:
                    continue
            selected.append(entry)
        if selected:
            result[key] = selected
    return result


def mark_multi_form_encounters_ambiguous(
    locations_by_key: dict[str, list[dict[str, Any]]],
    pokemon_ids: set[int],
) -> dict[str, list[dict[str, Any]]]:
    """Do not claim a cosmetic form when PokeAPI only identifies its entity."""
    if not pokemon_ids:
        return locations_by_key
    result: dict[str, list[dict[str, Any]]] = {}
    for key, entries in locations_by_key.items():
        normalized: list[dict[str, Any]] = []
        for source in entries:
            entry = dict(source)
            if entry.get("pokemonId") in pokemon_ids:
                entry.pop("formKey", None)
                entry.pop("formSlug", None)
                entry["formAmbiguous"] = True
            normalized.append(entry)
        result[key] = normalized
    return result


def parse_ev_yield(entries: list[dict[str, Any]]) -> dict[str, int]:
    result: dict[str, int] = {}
    for entry in entries:
        stat_name = entry.get("stat", {}).get("name", "")
        effort = entry.get("effort", 0)
        key = EV_STAT_KEYS.get(stat_name)
        if key and effort > 0:
            result[key] = effort
    return result


def normalize_flavor_text(text: str) -> str:
    return " ".join(text.replace("\n", " ").replace("\f", " ").split())


def pick_flavor_text(lang_map: dict[str, str]) -> str | None:
    return (
        lang_map.get("zh-Hans")
        or lang_map.get("zh-hans")
        or lang_map.get("zh-hant")
        or lang_map.get("en")
    )


def parse_flavor_entries(
    entries: list[dict[str, Any]], cdn_base: str
) -> list[dict[str, Any]]:
    by_version: dict[str, dict[str, str]] = {}
    for entry in entries:
        version = entry.get("version", {}).get("name", "")
        language = entry.get("language", {}).get("name", "")
        text = normalize_flavor_text(entry.get("flavor_text", ""))
        if not version or not text:
            continue
        by_version.setdefault(version, {})[language] = text

    result: list[dict[str, Any]] = []
    cdn_prefix = BUNDLE_CDN_PREFIX
    for edition in GAME_EDITIONS:
        if not edition.version_group:
            continue
        icon_url = f"{cdn_base}/{cdn_prefix}/game_icons/{edition.icon_slug}.png"
        for version in edition.flavor_versions:
            text = pick_flavor_text(by_version.get(version, {}))
            if not text:
                continue
            result.append(
                {
                    "gameEdition": edition.slug,
                    "versionGroup": edition.version_group,
                    "version": version,
                    "labelZh": edition.label_zh,
                    "iconUrl": icon_url,
                    "text": text,
                }
            )
    return result


def parse_base_stats(stats: list[dict[str, Any]]) -> dict[str, int]:
    values: dict[str, int] = {}
    for entry in stats:
        stat_name = entry["stat"]["name"]
        values[stat_name] = entry.get("base_stat", 0)
    return {
        "hp": values.get("hp", 0),
        "attack": values.get("attack", 0),
        "defense": values.get("defense", 0),
        "specialAttack": values.get("special-attack", 0),
        "specialDefense": values.get("special-defense", 0),
        "speed": values.get("speed", 0),
    }


def gender_female_percent(gender_rate: int | None) -> float | None:
    if gender_rate is None or gender_rate < 0:
        return None
    return gender_rate / 8 * 100


def compute_defensive_multipliers(
    defender_types: list[str],
    relations_by_type: dict[str, TypeDamageRelations],
) -> dict[str, float]:
    multipliers: dict[str, float] = {}
    for attack_type in TYPE_NAMES:
        multiplier = 1.0
        for defender_type in defender_types:
            relations = relations_by_type.get(attack_type)
            if relations is None:
                continue
            if defender_type in relations.no_damage_to:
                multiplier = 0.0
                break
            if defender_type in relations.double_damage_to:
                multiplier *= 2
            elif defender_type in relations.half_damage_to:
                multiplier *= 0.5
        multipliers[attack_type] = multiplier
    return multipliers


def compute_defensive_profile(
    defender_types: list[str],
    relations_by_type: dict[str, TypeDamageRelations],
) -> dict[str, list[str]]:
    multipliers = compute_defensive_multipliers(defender_types, relations_by_type)
    weaknesses: list[str] = []
    resistances: list[str] = []
    immunities: list[str] = []
    for attack_type, value in multipliers.items():
        label = type_name_zh(attack_type)
        if value >= 2:
            weaknesses.append(label)
        elif value == 0:
            immunities.append(label)
        elif value <= 0.5:
            resistances.append(label)
    weaknesses.sort()
    resistances.sort()
    immunities.sort()
    stab = compute_stab_super_effective(defender_types, relations_by_type)
    return {
        "weaknesses": weaknesses,
        "resistances": resistances,
        "immunities": immunities,
        "stab": stab,
    }


def compute_stab_super_effective(
    attacker_types: list[str],
    relations_by_type: dict[str, TypeDamageRelations],
) -> list[str]:
    effective: set[str] = set()
    for attack_type in attacker_types:
        relations = relations_by_type.get(attack_type)
        if relations is None:
            continue
        effective.update(relations.double_damage_to)
    return sorted(type_name_zh(name) for name in effective)


def fetch_move_set_for_version_group(
    builder: PokeApiBuilder,
    move_entries: list[dict[str, Any]],
    version_group: str,
) -> dict[str, list[dict[str, Any]]]:
    level_up: dict[int, dict[str, Any]] = {}
    machine: dict[int, dict[str, Any]] = {}
    egg: dict[int, dict[str, Any]] = {}
    tutor: dict[int, dict[str, Any]] = {}

    for entry in move_entries:
        move_id = id_from_url(entry["move"]["url"])
        for detail in entry.get("version_group_details", []):
            if detail.get("version_group", {}).get("name") != version_group:
                continue
            method = detail.get("move_learn_method", {}).get("name")
            if method not in MOVE_LEARN_METHODS:
                continue
            level = detail.get("level_learned_at") or 0
            target = {
                "level-up": level_up,
                "machine": machine,
                "egg": egg,
                "tutor": tutor,
            }[method]
            existing = target.get(move_id)
            if method == "level-up" and existing and (existing.get("level") or 0) >= level:
                continue
            if method != "level-up" and existing:
                continue
            ref: dict[str, Any] = {"moveId": move_id, "method": method}
            if method == "level-up" and level > 0:
                ref["level"] = level
            target[move_id] = ref
            builder.fetch_move(move_id)

    def sort_refs(refs: dict[int, dict[str, Any]], *, by_level: bool) -> list[dict[str, Any]]:
        items = list(refs.values())
        if by_level:
            items.sort(key=lambda item: item.get("level") or 0)
        else:
            items.sort(key=lambda item: builder.move_cache[item["moveId"]]["nameZh"])
        return items

    return {
        "levelUp": sort_refs(level_up, by_level=True),
        "machine": sort_refs(machine, by_level=False),
        "egg": sort_refs(egg, by_level=False),
        "tutor": sort_refs(tutor, by_level=False),
    }


def fetch_hgss_move_set(
    builder: PokeApiBuilder, move_entries: list[dict[str, Any]]
) -> dict[str, list[dict[str, Any]]]:
    return fetch_move_set_for_version_group(builder, move_entries, HGSS_VERSION_GROUP)


def evolution_trigger_zh(detail: dict[str, Any]) -> str | None:
    min_level = detail.get("min_level")
    if min_level and min_level > 0:
        return f"Lv.{min_level}"
    item = detail.get("item")
    if item:
        return f"道具：{capitalize(item['name'])}"
    trigger = (detail.get("trigger") or {}).get("name")
    mapping = {
        "level-up": "升级",
        "use-item": "使用道具",
        "trade": "交换",
        "shed": "蜕壳",
        "spin": "旋转",
        "other": "特殊条件",
    }
    return mapping.get(trigger or "", capitalize(trigger) if trigger else None)


def fetch_evolution_chain(
    builder: PokeApiBuilder, url: str, cdn_base: str
) -> dict[str, Any]:
    chain = builder._get_json(url)
    return parse_evolution_node(builder, chain["chain"], cdn_base)


def parse_evolution_node(
    builder: PokeApiBuilder, node: dict[str, Any], cdn_base: str
) -> dict[str, Any]:
    species = node["species"]
    species_id = id_from_url(species["url"])
    species_detail = builder._get_json(f"/pokemon-species/{species_id}")
    trigger_zh = None
    details = node.get("evolution_details") or []
    if details:
        trigger_zh = evolution_trigger_zh(details[0])

    children = [
        parse_evolution_node(builder, child, cdn_base)
        for child in node.get("evolves_to", [])
    ]

    return {
        "id": species_id,
        "nameEn": capitalize(species["name"]),
        "nameZh": localized_name(species_detail.get("names", []), species["name"]),
        "spriteUrl": f"{cdn_base}/{BUNDLE_CDN_PREFIX}/sprites/{species_id}.png",
        "artworkUrl": f"{cdn_base}/{BUNDLE_CDN_PREFIX}/artwork/{species_id}.png",
        "localSpritePath": f"sprites/{species_id}.png",
        **({"evolvesFrom": trigger_zh} if trigger_zh else {}),
        **({"triggerZh": trigger_zh} if trigger_zh else {}),
        "children": children,
    }


def strip_png_chunks(png_bytes: bytes, drop_types: set[bytes]) -> bytes:
    """Drop ancillary PNG chunks (e.g. broken iCCP from PokeAPI sprites)."""
    if not png_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        return png_bytes
    out = bytearray(b"\x89PNG\r\n\x1a\n")
    pos = 8
    while pos + 8 <= len(png_bytes):
        length = struct.unpack(">I", png_bytes[pos : pos + 4])[0]
        chunk_type = png_bytes[pos + 4 : pos + 8]
        chunk_end = pos + 12 + length
        if chunk_end > len(png_bytes):
            break
        if chunk_type not in drop_types:
            out.extend(png_bytes[pos:chunk_end])
        pos = chunk_end
    return bytes(out)


def open_png_image(png_bytes: bytes) -> Image.Image:
    """Open PNG bytes, repairing common PokeAPI sprite metadata issues."""
    try:
        image = Image.open(io.BytesIO(png_bytes))
        image.load()
        return image
    except UnidentifiedImageError:
        repaired = strip_png_chunks(png_bytes, {b"iCCP", b"cHRM", b"sRGB", b"gAMA"})
        image = Image.open(io.BytesIO(repaired))
        image.load()
        return image


def optimize_png(png_bytes: bytes, *, max_width: int | None = 220) -> bytes:
    """Resize PNG while preserving alpha (no white JPEG matte)."""
    image = open_png_image(png_bytes)
    if image.mode not in ("RGB", "RGBA"):
        image = image.convert("RGBA")
    if max_width is not None and image.width > max_width:
        ratio = max_width / image.width
        image = image.resize((max_width, int(image.height * ratio)), Image.Resampling.LANCZOS)
    out = io.BytesIO()
    image.save(out, format="PNG", optimize=True)
    return out.getvalue()


def download_bytes(session: requests.Session, url: str) -> bytes:
    time.sleep(0.15)
    response = session.get(url, timeout=60)
    response.raise_for_status()
    return response.content


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def directory_size(path: Path) -> int:
    total = 0
    for file in path.rglob("*"):
        if file.is_file():
            total += file.stat().st_size
    return total


def create_zst_tar(source_dir: Path, archive_path: Path) -> None:
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as tar:
        for file in sorted(source_dir.rglob("*")):
            if not file.is_file():
                continue
            if file.name == "bundle.tar.zst":
                continue
            tar.add(file, arcname=file.relative_to(source_dir).as_posix())
    tar_bytes = buffer.getvalue()
    if zstd is not None:
        compressor = zstd.ZstdCompressor(level=19)
        archive_path.write_bytes(compressor.compress(tar_bytes))
        return
    process = subprocess.run(
        ["zstd", "-19", "--stdout"],
        input=tar_bytes,
        capture_output=True,
        check=True,
    )
    archive_path.write_bytes(process.stdout)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


APP_CONFIG_VERSION = 1

DEFAULT_APP_CONFIG: dict[str, Any] = {
    "configVersion": APP_CONFIG_VERSION,
    "sleepTools": {
        "tierAHint": "Tier A：静态链接，点击复制到剪贴板",
        "links": [
            {"labelZh": "Neroli's Lab 主页", "url": "https://nerolislab.com"},
            {"labelZh": "攻略指南", "url": "https://nerolislab.com/guides/"},
            {"labelZh": "开发文档", "url": "https://docs.nerolislab.com"},
        ],
    },
}


def build_hgss_map_list_with_zh() -> list[dict[str, str]]:
    """Merge Project Pokémon map list with zh labels from the catalog."""
    base_path = ROOT / "tools" / "hgss_map_list.json"
    zh_path = ROOT / "data" / "l10n" / "zh" / "hgss_map_ids.json"
    base_list = json.loads(base_path.read_text(encoding="utf-8"))
    zh_by_id: dict[str, dict[str, Any]] = {}
    if zh_path.is_file():
        zh_by_id = json.loads(zh_path.read_text(encoding="utf-8"))

    merged: list[dict[str, str]] = []
    for index, entry in enumerate(base_list):
        row: dict[str, str] = {
            "name": entry.get("name", "Unknown"),
            "code": entry.get("code", ""),
        }
        zh_entry = zh_by_id.get(str(index), {})
        label_zh = zh_entry.get("labelZh")
        if label_zh:
            row["labelZh"] = label_zh
        merged.append(row)
    return merged


def stage_bundle_reference_data(
    staging: Path,
    *,
    published_at: str,
) -> dict[str, Any]:
    """Stage l10n/, maps/, config/ for the offline bundle (no nav icons)."""
    from generate_zh_catalog_assets import write_compact_l10n

    print("Staging zh l10n catalog…", flush=True)
    l10n_dir = staging / "l10n" / "zh"
    l10n_stats = write_compact_l10n(l10n_dir)

    print("Staging HGSS map list…", flush=True)
    maps_dir = staging / "maps"
    maps_dir.mkdir(parents=True, exist_ok=True)
    hgss_map_list = build_hgss_map_list_with_zh()
    write_json(maps_dir / "hgss_map_list.json", hgss_map_list)

    print("Staging app config…", flush=True)
    config_dir = staging / "config"
    config_dir.mkdir(parents=True, exist_ok=True)
    app_config = {
        **DEFAULT_APP_CONFIG,
        "publishedAt": published_at,
    }
    write_json(config_dir / "app_config.json", app_config)

    return {
        "l10nVersion": l10n_stats.get("l10nVersion", published_at),
        "configVersion": APP_CONFIG_VERSION,
        "locationLabelKeys": l10n_stats.get("locationLabelKeys", 0),
        "hgssMapCount": len(hgss_map_list),
    }


def build_games_json(cdn_base: str) -> list[dict[str, Any]]:
    games: list[dict[str, Any]] = []
    for edition in GAME_EDITIONS:
        entry: dict[str, Any] = {
            "slug": edition.slug,
            "labelZh": edition.label_zh,
            "versionGroup": edition.version_group,
            "flavorVersions": list(edition.flavor_versions),
            "encounterVersions": sorted(edition.encounter_versions),
            "iconSlug": edition.icon_slug,
            "iconUrl": (
                f"{cdn_base}/{BUNDLE_CDN_PREFIX}/game_icons/{edition.icon_slug}.png"
            ),
        }
        if edition.fallback_slug:
            entry["fallbackSlug"] = edition.fallback_slug
        games.append(entry)
    return games


def fetch_natures_index(builder: PokeApiBuilder) -> list[dict[str, Any]]:
    index = builder._get_json("/nature?limit=50")
    natures: list[dict[str, Any]] = []
    for result in index["results"]:
        detail = builder._get_json(f"/nature/{result['name']}")
        increased = detail.get("increased_stat")
        decreased = detail.get("decreased_stat")
        entry: dict[str, Any] = {
            "id": detail["id"],
            "slug": detail["name"],
            "nameEn": capitalize(detail["name"].replace("-", " ")),
            "nameZh": localized_name(detail.get("names", []), detail["name"]),
        }
        if increased:
            entry["increasedStat"] = EV_STAT_KEYS.get(
                increased["name"], increased["name"]
            )
        if decreased:
            entry["decreasedStat"] = EV_STAT_KEYS.get(
                decreased["name"], decreased["name"]
            )
        likes = detail.get("likes_flavor")
        hates = detail.get("hates_flavor")
        if likes:
            entry["likesFlavor"] = likes["name"]
        if hates:
            entry["hatesFlavor"] = hates["name"]
        natures.append(entry)
    return sorted(natures, key=lambda item: item["id"])


def fetch_egg_groups_index(builder: PokeApiBuilder) -> list[dict[str, Any]]:
    index = builder._get_json("/egg-group?limit=20")
    groups: list[dict[str, Any]] = []
    for result in index["results"]:
        detail = builder._get_json(f"/egg-group/{result['name']}")
        groups.append(
            {
                "id": detail["id"],
                "slug": detail["name"],
                "nameEn": capitalize(detail["name"].replace("-", " ")),
                "nameZh": EGG_GROUP_ZH.get(
                    detail["name"],
                    localized_name(detail.get("names", []), detail["name"]),
                ),
            }
        )
    return sorted(groups, key=lambda item: item["id"])


def fetch_items_index(builder: PokeApiBuilder) -> dict[str, dict[str, Any]]:
    items: dict[str, dict[str, Any]] = {}
    seen: set[str] = set()
    for slug in CURATED_ITEM_SLUGS:
        if slug in seen:
            continue
        seen.add(slug)
        try:
            detail = builder._get_json(f"/item/{slug}")
        except requests.RequestException:
            continue
        item_id = detail["id"]
        entry: dict[str, Any] = {
            "id": item_id,
            "slug": detail["name"],
            "nameEn": capitalize(detail["name"].replace("-", " ")),
            "nameZh": localized_name(detail.get("names", []), detail["name"]),
        }
        category = detail.get("category", {}).get("name")
        if category:
            entry["category"] = category
        cost = detail.get("cost")
        if cost is not None:
            entry["cost"] = cost
        items[str(item_id)] = entry
    return items


def fetch_version_sprite_url(builder: PokeApiBuilder, icon_slug: str) -> str | None:
    if icon_slug in {"lza", "champions"}:
        return None
    version_name = ICON_SLUG_TO_POKEAPI_VERSION.get(icon_slug, icon_slug)
    try:
        detail = builder._get_json(f"/version/{version_name}")
    except requests.RequestException:
        return None
    return detail.get("sprites", {}).get("default")


def download_game_icons(
    builder: PokeApiBuilder,
    session: requests.Session,
    staging: Path,
) -> None:
    icons_dir = staging / "game_icons"
    icons_dir.mkdir(parents=True, exist_ok=True)
    for edition in GAME_EDITIONS:
        if not edition.version_group:
            continue
        icon_url = fetch_version_sprite_url(builder, edition.icon_slug)
        if not icon_url:
            print(
                f"  warn: no game icon for {edition.icon_slug}",
                file=sys.stderr,
            )
            continue
        try:
            png = download_bytes(session, icon_url)
            optimized = optimize_png(png, max_width=64)
            (icons_dir / f"{edition.icon_slug}.png").write_bytes(optimized)
        except requests.RequestException as exc:
            print(f"  warn: game icon {edition.icon_slug}: {exc}", file=sys.stderr)


def collect_move_ids_from_detail(detail: dict[str, Any]) -> set[int]:
    move_ids: set[int] = set()

    def scan_move_set(move_set: dict[str, Any]) -> None:
        for key in ("levelUp", "machine", "egg", "tutor"):
            for ref in move_set.get(key, []):
                move_id = ref.get("moveId")
                if move_id is not None:
                    move_ids.add(int(move_id))

    scan_move_set(detail.get("moveSet") or {})
    for move_set in (detail.get("moveSets") or {}).values():
        scan_move_set(move_set)
    return move_ids


def warm_builder_caches_from_details(
    builder: PokeApiBuilder, staging: Path, max_id: int
) -> None:
    """Fetch moves/abilities referenced in existing details (end-of-build pass)."""
    details_dir = staging / "details"
    if not details_dir.is_dir():
        return
    print("Collecting move/ability caches from detail files…", flush=True)
    move_ids: set[int] = set()
    ability_jobs: set[tuple[str, bool, int]] = set()
    for pokemon_id in range(1, max_id + 1):
        detail_path = details_dir / f"{pokemon_id}.json"
        if not detail_path.exists():
            continue
        detail = json.loads(detail_path.read_text(encoding="utf-8"))
        form_payloads = [detail, *(detail.get("forms") or [])]
        for payload in form_payloads:
            move_ids.update(collect_move_ids_from_detail(payload))
            for ability in payload.get("abilities", []):
                slug = str(ability.get("nameEn", "")).lower().replace(" ", "-")
                if slug:
                    ability_jobs.add(
                        (slug, ability.get("isHidden", False), pokemon_id)
                    )

    missing_moves = sorted(mid for mid in move_ids if mid not in builder.move_cache)
    print(f"  moves to fetch: {len(missing_moves)}", flush=True)
    for move_id in missing_moves:
        try:
            builder.fetch_move(move_id)
        except requests.RequestException as exc:
            print(f"  warn: move #{move_id}: {exc}", file=sys.stderr)

    print(f"  abilities to register: {len(ability_jobs)}", flush=True)
    for slug, is_hidden, pokemon_id in sorted(ability_jobs):
        try:
            fetched = builder.fetch_ability(slug, is_hidden=is_hidden)
            builder.register_ability(fetched, pokemon_id)
        except requests.RequestException as exc:
            print(f"  warn: ability {slug}: {exc}", file=sys.stderr)


def hydrate_builder_indexes_from_staging(
    builder: PokeApiBuilder, staging: Path
) -> None:
    """Reuse completed resume indexes instead of refetching moves/abilities."""
    moves_path = staging / "moves.json"
    if moves_path.is_file():
        builder.move_cache.update(
            {
                int(move_id): payload
                for move_id, payload in json.loads(
                    moves_path.read_text(encoding="utf-8")
                ).items()
            }
        )

    abilities_path = staging / "abilities.json"
    if not abilities_path.is_file():
        return
    for ability_id_raw, payload in json.loads(
        abilities_path.read_text(encoding="utf-8")
    ).items():
        ability_id = int(ability_id_raw)
        indexed = dict(payload)
        indexed["pokemonIds"] = list(payload.get("pokemonIds") or [])
        builder.ability_index[ability_id] = indexed
        slug = str(payload.get("nameEn") or "").lower().replace(" ", "-")
        if not slug:
            continue
        for is_hidden in (False, True):
            builder.ability_cache[(slug, is_hidden)] = {
                "id": ability_id,
                "nameEn": payload.get("nameEn", slug),
                "nameZh": payload.get("nameZh", slug),
                "descriptionZh": payload.get("descriptionZh", ""),
                "isHidden": is_hidden,
            }


def summaries_from_details(staging: Path, max_id: int) -> list[dict[str, Any]]:
    summaries: list[dict[str, Any]] = []
    for pokemon_id in range(1, max_id + 1):
        detail_path = staging / "details" / f"{pokemon_id}.json"
        if not detail_path.exists():
            continue
        detail = json.loads(detail_path.read_text(encoding="utf-8"))
        summary = detail.get("summary")
        if summary:
            summaries.append(summary)
    return summaries


def form_count_from_details(staging: Path, max_id: int) -> int:
    total = 0
    for pokemon_id in range(1, max_id + 1):
        detail_path = staging / "details" / f"{pokemon_id}.json"
        if detail_path.exists():
            detail = json.loads(detail_path.read_text(encoding="utf-8"))
            total += len(detail.get("forms") or [])
    return total


def encounter_coverage_from_details(staging: Path, max_id: int) -> dict[str, Any]:
    exact: dict[str, dict[str, Any]] = {}
    for pokemon_id in range(1, max_id + 1):
        detail_path = staging / "details" / f"{pokemon_id}.json"
        if not detail_path.is_file():
            continue
        detail = json.loads(detail_path.read_text(encoding="utf-8"))
        for version, entries in (detail.get("obtainLocationsByVersion") or {}).items():
            stats = exact.setdefault(
                version,
                {
                    "species": set(),
                    "entries": 0,
                    "formLinked": 0,
                    "formAmbiguous": 0,
                    "tera": 0,
                    "alpha": 0,
                    "titan": 0,
                    "raid": 0,
                    "fixed": 0,
                },
            )
            if entries:
                stats["species"].add(pokemon_id)
            stats["entries"] += len(entries)
            for entry in entries:
                linked = entry.get("pokemonId") is not None and bool(entry.get("formKey"))
                stats["formLinked"] += int(linked)
                stats["formAmbiguous"] += int(bool(entry.get("formAmbiguous")))
                stats["tera"] += int(bool(entry.get("teraType")))
                stats["alpha"] += int(bool(entry.get("isAlpha")))
                stats["titan"] += int(bool(entry.get("isTitan")))
                stats["raid"] += int(bool(entry.get("isRaid")))
                stats["fixed"] += int(bool(entry.get("isFixedEncounter")))
    return {
        "exactVersions": {
            version: {
                **{key: value for key, value in stats.items() if key != "species"},
                "speciesWithLocations": len(stats["species"]),
            }
            for version, stats in sorted(exact.items())
        },
        "notApplicable": ["champions"],
    }


def encounter_source_metadata() -> list[dict[str, Any]]:
    sources: dict[tuple[str, str, str, str], dict[str, Any]] = {}
    for path in sorted(ENCOUNTER_OVERLAY_DIR.rglob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        source = payload.get("source") or {}
        version = str(payload.get("version") or "")
        if not source or not version:
            continue
        identity = (
            str(source.get("name") or ""),
            str(source.get("url") or ""),
            str(source.get("license") or ""),
            str(source.get("commit") or ""),
        )
        record = sources.setdefault(
            identity,
            {
                "name": identity[0],
                "url": identity[1],
                "license": identity[2],
                **({"commit": identity[3]} if identity[3] else {}),
                "versions": [],
            },
        )
        record["versions"].append(version)
    for record in sources.values():
        record["versions"] = sorted(set(record["versions"]))
    return sorted(sources.values(), key=lambda item: item["name"])


def build_runtime_catalog(
    staging: Path,
    summaries: list[dict[str, Any]],
    moves_payload: dict[str, dict[str, Any]],
    abilities_payload: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    """Create the UI-hot subset of a dex bundle.

    The app must never discover filter memberships by walking 1025 detail
    files after a user has tapped a reference.  Keep those reverse lookups in
    one small JSON document next to the summary list instead.
    """
    move_learners: dict[str, set[int]] = {}
    egg_groups: dict[str, set[int]] = {}
    egg_group_slugs = {label: slug for slug, label in EGG_GROUP_ZH.items()}

    for summary in summaries:
        pokemon_id = int(summary["id"])
        detail_path = staging / "details" / f"{pokemon_id}.json"
        if not detail_path.exists():
            continue
        detail = json.loads(detail_path.read_text(encoding="utf-8"))
        for move_id in collect_move_ids_from_detail(detail):
            move_learners.setdefault(str(move_id), set()).add(pokemon_id)
        for label in detail.get("eggGroups") or []:
            slug = egg_group_slugs.get(label)
            if slug:
                egg_groups.setdefault(slug, set()).add(pokemon_id)

    return {
        "version": 1,
        "summaries": summaries,
        "moveLearners": {
            move_id: sorted(ids) for move_id, ids in sorted(move_learners.items(), key=lambda item: int(item[0]))
        },
        "eggGroups": {
            slug: sorted(ids) for slug, ids in sorted(egg_groups.items())
        },
        "abilityPokemonIds": {
            ability_id: sorted({int(pid) for pid in entry.get("pokemonIds", [])})
            for ability_id, entry in sorted(abilities_payload.items(), key=lambda item: int(item[0]))
        },
        "moves": moves_payload,
        "abilities": abilities_payload,
    }


def build_bundle(
    *,
    cdn_base: str,
    output_dir: Path,
    min_id: int,
    max_id: int,
    delay_s: float,
    resume: bool = False,
    selected_ids: tuple[int, ...] | None = None,
) -> None:
    cdn_base = cdn_base.rstrip("/")
    staging = output_dir / "staging"
    upload_bundle = output_dir / "upload" / BUNDLE_CDN_PREFIX
    artwork_staging = output_dir / "artwork_staging"

    if resume and staging.exists():
        print(f"Resuming into existing staging at {staging}")
    else:
        if staging.exists():
            shutil.rmtree(staging)
        if artwork_staging.exists():
            shutil.rmtree(artwork_staging)

    staging.mkdir(parents=True, exist_ok=True)
    artwork_staging.mkdir(parents=True, exist_ok=True)
    (staging / "details").mkdir(exist_ok=True)
    (staging / "sprites").mkdir(exist_ok=True)
    (staging / "sprites" / "forms").mkdir(exist_ok=True)
    (staging / "type_icons").mkdir(exist_ok=True)
    (staging / "game_icons").mkdir(exist_ok=True)

    builder = PokeApiBuilder(delay_s=delay_s)
    session = builder.session
    if resume:
        hydrate_builder_indexes_from_staging(builder, staging)

    if not (staging / "types.json").exists():
        print("Loading type relations…")
        relations = builder.load_type_relations()
        types_payload = {
            name: {
                "doubleDamageTo": sorted(relations[name].double_damage_to),
                "halfDamageTo": sorted(relations[name].half_damage_to),
                "noDamageTo": sorted(relations[name].no_damage_to),
            }
            for name in TYPE_NAMES
            if name in relations
        }
        write_json(staging / "types.json", types_payload)
    else:
        builder.load_type_relations()

    if not (staging / "games.json").exists():
        print("Building global indexes…")
        write_json(staging / "games.json", build_games_json(cdn_base))
        write_json(staging / "natures.json", fetch_natures_index(builder))
        write_json(staging / "egg_groups.json", fetch_egg_groups_index(builder))
        write_json(staging / "status_conditions.json", STATUS_CONDITIONS)
        write_json(staging / "weather.json", WEATHER_CONDITIONS)
        write_json(staging / "terrains.json", TERRAIN_CONDITIONS)
        write_json(staging / "items.json", fetch_items_index(builder))

    if not any((staging / "type_icons").glob("*.png")):
        print("Downloading type icons (pokesprite Gen 8)…")
        for type_name in TYPE_NAMES:
            dest = staging / "type_icons" / f"{type_name}.png"
            vendored = POKESPRITE_TYPE_ICON_DIR / f"{type_name}.png"
            if vendored.is_file():
                dest.write_bytes(vendored.read_bytes())
                continue
            try:
                icon_url = None
                try:
                    detail = builder._get_json(f"/type/{type_name}")
                    from pokeapi_assets import type_icon_url_pokeapi

                    icon_url = type_icon_url_pokeapi(detail)
                except requests.RequestException:
                    pass
                if not icon_url:
                    icon_url = builder.pokesprite_type_icon_url(type_name)
                if not icon_url:
                    icon_url = builder.type_icon_url(type_name)
                if not icon_url:
                    print(f"  warn: no type icon for {type_name}", file=sys.stderr)
                    continue
                png = download_bytes(session, icon_url)
                optimized = optimize_png(png, max_width=64)
                dest.write_bytes(optimized)
                POKESPRITE_TYPE_ICON_DIR.mkdir(parents=True, exist_ok=True)
                (POKESPRITE_TYPE_ICON_DIR / f"{type_name}.png").write_bytes(optimized)
            except requests.RequestException as exc:
                print(f"  warn: type icon {type_name}: {exc}", file=sys.stderr)

    if not any((staging / "game_icons").glob("*.png")):
        print("Downloading game icons…")
        download_game_icons(builder, session, staging)

    build_ids = selected_ids or tuple(range(min_id, max_id + 1))
    for build_index, pokemon_id in enumerate(build_ids, start=1):
        detail_path = staging / "details" / f"{pokemon_id}.json"
        if resume and detail_path.exists():
            continue
        print(f"#{pokemon_id} ({build_index}/{len(build_ids)})…", flush=True)
        summary, detail, sprite_remote = builder.build_detail(pokemon_id, cdn_base)
        write_json(detail_path, detail)

        if sprite_remote and not (staging / "sprites" / f"{pokemon_id}.png").exists():
            try:
                png = download_bytes(session, sprite_remote)
                (staging / "sprites" / f"{pokemon_id}.png").write_bytes(
                    optimize_png(png, max_width=220)
                )
                (artwork_staging / f"{pokemon_id}.png").write_bytes(
                    optimize_png(png, max_width=None)
                )
            except requests.RequestException as exc:
                print(f"  warn: sprite #{pokemon_id}: {exc}", file=sys.stderr)

    for form_id, (sprite_remote, _artwork_remote) in sorted(
        builder.form_sprite_jobs.items()
    ):
        sprite_dest = staging / "sprites" / "forms" / f"{form_id}.png"
        if sprite_remote and not sprite_dest.exists():
            try:
                png = download_bytes(session, sprite_remote)
                sprite_dest.write_bytes(optimize_png(png, max_width=220))
            except requests.RequestException as exc:
                print(f"  warn: form sprite #{form_id}: {exc}", file=sys.stderr)

    warm_builder_caches_from_details(builder, staging, max_id)
    summaries = summaries_from_details(staging, max_id)
    form_count = form_count_from_details(staging, max_id)
    form_sprite_count = len(list((staging / "sprites" / "forms").glob("*.png")))
    encounter_coverage = encounter_coverage_from_details(staging, max_id)
    encounter_sources = encounter_source_metadata()
    write_json(staging / "summaries.json", summaries)
    moves_payload = {str(move_id): move for move_id, move in builder.move_cache.items()}
    write_json(staging / "moves.json", moves_payload)
    abilities_payload = {
        str(ability_id): {
            **{key: value for key, value in data.items() if key != "pokemonIds"},
            "pokemonIds": sorted(data["pokemonIds"]),
        }
        for ability_id, data in sorted(builder.ability_index.items())
    }
    write_json(staging / "abilities.json", abilities_payload)
    write_json(
        staging / "dex_catalog.json",
        build_runtime_catalog(staging, summaries, moves_payload, abilities_payload),
    )

    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    reference_meta = stage_bundle_reference_data(staging, published_at=published_at)

    # Offline archives must contain the same nested form artwork that the
    # upload tree exposes separately. Older bundles omitted artwork entirely;
    # keeping it under staging makes tar inclusion directly auditable.
    if artwork_staging.is_dir():
        shutil.copytree(artwork_staging, staging / "artwork", dirs_exist_ok=True)

    games_payload = json.loads((staging / "games.json").read_text(encoding="utf-8"))
    natures_payload = json.loads((staging / "natures.json").read_text(encoding="utf-8"))
    egg_groups_payload = json.loads(
        (staging / "egg_groups.json").read_text(encoding="utf-8")
    )
    items_payload = json.loads((staging / "items.json").read_text(encoding="utf-8"))

    size_bytes = directory_size(staging)
    manifest = {
        "version": BUNDLE_VERSION,
        "complete": max_id >= TITODEX_MAX_NATIONAL_ID
        and len(summaries) >= TITODEX_MAX_NATIONAL_ID,
        "preferOffline": True,
        "downloadedAt": published_at,
        "pokemonCount": len(summaries),
        "formCount": form_count,
        "formSpriteCount": form_sprite_count,
        "schemaFeatures": {
            "pokemonForms": 2,
            "encounterFormIdentity": 3,
            "exactVersionLocations": 1,
        },
        "exactVersionLocations": True,
        "encounterSources": encounter_sources,
        "encounterCoverage": encounter_coverage,
        "moveCount": len(moves_payload),
        "abilityCount": len(abilities_payload),
        "gameCount": len(games_payload),
        "natureCount": len(natures_payload),
        "eggGroupCount": len(egg_groups_payload),
        "itemCount": len(items_payload),
        "l10nVersion": reference_meta.get("l10nVersion"),
        "configVersion": reference_meta.get("configVersion"),
        "sizeBytes": size_bytes,
    }
    write_json(staging / "manifest.json", manifest)

    archive_path = staging / "bundle.tar.zst"
    print("Creating bundle.tar.zst…")
    create_zst_tar(staging, archive_path)

    # Copy to upload/{BUNDLE_CDN_PREFIX} (v2 clients keep using prior upload/v2 builds)
    if upload_bundle.exists():
        shutil.rmtree(upload_bundle.parent)
    upload_bundle.mkdir(parents=True)
    shutil.copytree(artwork_staging, upload_bundle / "artwork")
    for name in (
        "manifest.json",
        "summaries.json",
        "types.json",
        "moves.json",
        "abilities.json",
        "dex_catalog.json",
        "games.json",
        "natures.json",
        "egg_groups.json",
        "status_conditions.json",
        "weather.json",
        "terrains.json",
        "items.json",
        "bundle.tar.zst",
    ):
        shutil.copy2(staging / name, upload_bundle / name)
    shutil.copytree(staging / "details", upload_bundle / "details")
    shutil.copytree(staging / "sprites", upload_bundle / "sprites")
    shutil.copytree(staging / "type_icons", upload_bundle / "type_icons")
    shutil.copytree(staging / "game_icons", upload_bundle / "game_icons")
    for extra_dir in ("l10n", "maps", "config"):
        src = staging / extra_dir
        if src.is_dir():
            shutil.copytree(src, upload_bundle / extra_dir)

    archive_sha = sha256_file(upload_bundle / "bundle.tar.zst")
    bundle_manifest = {
        "bundleVersion": BUNDLE_VERSION,
        "pokemonCount": len(summaries),
        "formCount": form_count,
        "formSpriteCount": form_sprite_count,
        "schemaFeatures": {
            "pokemonForms": 2,
            "encounterFormIdentity": 3,
            "exactVersionLocations": 1,
        },
        "cdnPrefix": BUNDLE_CDN_PREFIX,
        "complete": max_id >= TITODEX_MAX_NATIONAL_ID
        and len(summaries) >= TITODEX_MAX_NATIONAL_ID,
        "exactVersionLocations": True,
        "encounterSources": encounter_sources,
        "encounterCoverage": encounter_coverage,
        "archiveUrl": f"{cdn_base}/{BUNDLE_CDN_PREFIX}/bundle.tar.zst",
        "archiveSha256": archive_sha,
        "archiveSizeBytes": (upload_bundle / "bundle.tar.zst").stat().st_size,
        "publishedAt": published_at,
        "l10nVersion": reference_meta.get("l10nVersion"),
        "configVersion": reference_meta.get("configVersion"),
    }
    write_json(output_dir / "upload" / "bundle-manifest.json", bundle_manifest)

    print("\nDone.")
    print(f"  staging:          {staging}")
    print(f"  upload/{BUNDLE_CDN_PREFIX}: {upload_bundle}")
    print(f"  bundle-manifest:  {output_dir / 'upload' / 'bundle-manifest.json'}")
    print(f"  SHA256:           {archive_sha}")
    print(f"  archive size:     {bundle_manifest['archiveSizeBytes']:,} bytes")
    print(f"  staging size:     {size_bytes:,} bytes")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build TitoDex dex CDN bundle v6")
    parser.add_argument(
        "--cdn-base",
        default="https://dex.example.com",
        help="Public CDN base URL (no trailing slash)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("dist/dex-v6"),
        help="Output directory",
    )
    parser.add_argument("--min-id", type=int, default=1)
    parser.add_argument("--max-id", type=int, default=TITODEX_MAX_NATIONAL_ID)
    parser.add_argument(
        "--ids",
        help="Comma-separated non-contiguous species IDs for a smoke build",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.35,
        help="Delay between PokeAPI requests (seconds)",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Continue into existing staging/; skip completed detail JSON files",
    )
    args = parser.parse_args()
    selected_ids = None
    if args.ids:
        selected_ids = tuple(
            sorted({int(value.strip()) for value in args.ids.split(",") if value.strip()})
        )
        if not selected_ids:
            parser.error("--ids must contain at least one species ID")
        if selected_ids[0] < 1 or selected_ids[-1] > TITODEX_MAX_NATIONAL_ID:
            parser.error(f"--ids must stay within 1..{TITODEX_MAX_NATIONAL_ID}")
        args.min_id = selected_ids[0]
        args.max_id = selected_ids[-1]

    build_bundle(
        cdn_base=args.cdn_base,
        output_dir=args.output,
        min_id=args.min_id,
        max_id=args.max_id,
        delay_s=args.delay,
        resume=args.resume,
        selected_ids=selected_ids,
    )


if __name__ == "__main__":
    main()
