#!/usr/bin/env python3
"""Build TitoDex offline dex bundle v5 for Cloudflare R2 / CDN.

Output matches flutter/lib/features/dex/dex_cache_store.dart layout.
Published under {cdn_base}/v3/ (bundle v5; v2 remains for older clients).
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import sys
import tarfile
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import requests
import zstandard as zstd
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

try:
    from location_zh_resolver import resolve_location_area_zh  # noqa: E402
except ImportError:
    resolve_location_area_zh = None  # type: ignore[assignment]

POKEAPI_BASE = "https://pokeapi.co/api/v2"
TYPE_ICON_BASE = (
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/"
    "sprites/types/generation-iii/colosseum"
)
POKESPRITE_TYPE_ICON_DIR = ROOT / "data" / "assets" / "type_icons"
POKESPRITE_RAW_BASE = (
    "https://raw.githubusercontent.com/msikma/pokesprite/master/misc"
)
BUNDLE_VERSION = 5
BUNDLE_CDN_PREFIX = "v3"
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
        frozenset({"red", "blue"}), "red-blue",
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
        frozenset({"sword", "shield"}), "sword-shield",
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
        frozenset({"scarlet", "violet"}), "scarlet-violet",
    ),
    GameEdition("lza", "传说 Z-A", None, (), frozenset(), "lza", "sv"),
    GameEdition("champions", "Champions", None, (), frozenset(), "champions", "sv"),
)

ALL_VERSION_GROUPS = tuple(
    edition.version_group for edition in GAME_EDITIONS if edition.version_group
)

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
    "upgrade", "dubious-disc", "protector", "electirizer", "magmarizer",
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
}

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
        self.ability_index: dict[int, dict[str, Any]] = {}
        self.type_relations: dict[str, TypeDamageRelations] = {}

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
        detail = self._get_json(f"/ability/{slug}")
        ability_id = detail["id"]
        return {
            "id": ability_id,
            "nameEn": capitalize(detail["name"]),
            "nameZh": localized_name(detail.get("names", []), detail["name"]),
            "descriptionZh": ability_description_zh(detail),
            "isHidden": is_hidden,
        }

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

    def build_detail(
        self, pokemon_id: int, cdn_base: str
    ) -> tuple[dict, dict, str | None]:
        pokemon = self._get_json(f"/pokemon/{pokemon_id}")
        species = self._get_json(f"/pokemon-species/{pokemon_id}")
        relations = self.load_type_relations()
        cdn_prefix = BUNDLE_CDN_PREFIX

        types = extract_types(pokemon["types"])
        sprite_remote = sprite_url(pokemon["sprites"])
        sprite_cdn = f"{cdn_base}/{cdn_prefix}/sprites/{pokemon_id}.png"
        artwork_cdn = f"{cdn_base}/{cdn_prefix}/artwork/{pokemon_id}.png"

        summary = {
            "id": pokemon_id,
            "nameEn": capitalize(pokemon["name"]),
            "nameZh": localized_name(species.get("names", []), pokemon["name"]),
            "types": types,
            "spriteUrl": sprite_cdn,
            "artworkUrl": artwork_cdn,
            "localSpritePath": f"sprites/{pokemon_id}.png",
            "pokedexNumbers": parse_pokedex_numbers(species.get("pokedex_numbers", [])),
        }

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
        obtain_locations_by_game = fetch_obtain_locations_by_game(self, pokemon_id)
        obtain_locations = obtain_locations_by_game.get(
            HGSS_VERSION_GROUP,
            fetch_version_obtain_locations(
                self, pokemon_id, HGSS_ENCOUNTER_VERSIONS
            ),
        )
        gender_female = gender_female_percent(species.get("gender_rate"))
        egg_groups = [
            EGG_GROUP_ZH.get(g["name"], g["name"]) for g in species.get("egg_groups", [])
        ]
        hatch_counter = species.get("hatch_counter")
        base_happiness = species.get("base_happiness")
        capture_rate = species.get("capture_rate")
        ev_yield = parse_ev_yield(species.get("ev_yield", []))

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
            "eggGroups": egg_groups,
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
        if entry.get("language", {}).get("name") == "zh-Hant":
            return entry["name"]
    return capitalize(fallback)


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
    other = sprites.get("other") or {}
    artwork = other.get("official-artwork") or {}
    return artwork.get("front_default") or sprites.get("front_default")


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


def fetch_version_obtain_locations(
    builder: PokeApiBuilder,
    pokemon_id: int,
    versions: set[str],
) -> list[dict[str, Any]]:
    try:
        encounters = builder._get_json_list(f"/pokemon/{pokemon_id}/encounters")
    except requests.RequestException:
        return []

    merged: dict[str, dict[str, Any]] = {}
    for encounter in encounters:
        area_url = (encounter.get("location_area") or {}).get("url")
        if not area_url:
            continue
        raw_slug = area_url.rstrip("/").split("/")[-1]
        if _LOCATION_AREA_CATALOG is None:
            encounter_area_label_zh(raw_slug)
        slug = raw_slug
        if slug.isdigit():
            slug = _LOCATION_AREA_ID_TO_SLUG.get(slug, slug)
        min_level = 100
        max_chance = 0
        in_scope = False

        for detail in encounter.get("version_details", []):
            version = detail.get("version", {}).get("name", "")
            if version not in versions:
                continue
            in_scope = True
            chance = detail.get("max_chance") or 0
            if chance > max_chance:
                max_chance = chance
            for encounter_detail in detail.get("encounter_details", []):
                level = encounter_detail.get("min_level") or 100
                if level < min_level:
                    min_level = level

        if not in_scope:
            continue

        entry: dict[str, Any] = {
            "areaSlug": slug,
            "areaLabelZh": encounter_area_label_zh(slug),
            "maxChance": max_chance,
        }
        if min_level != 100:
            entry["minLevel"] = min_level
        merged[slug] = entry

    results = sorted(merged.values(), key=lambda item: item["areaLabelZh"])
    return results


def fetch_obtain_locations_by_game(
    builder: PokeApiBuilder, pokemon_id: int
) -> dict[str, list[dict[str, Any]]]:
    by_game: dict[str, list[dict[str, Any]]] = {}
    for edition in GAME_EDITIONS:
        if not edition.version_group or not edition.encounter_versions:
            continue
        locations = fetch_version_obtain_locations(
            builder, pokemon_id, edition.encounter_versions
        )
        by_game[edition.version_group] = locations
    return by_game


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
        or lang_map.get("zh-Hant")
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


def optimize_png(png_bytes: bytes, *, max_width: int | None = 220) -> bytes:
    """Resize PNG while preserving alpha (no white JPEG matte)."""
    image = Image.open(io.BytesIO(png_bytes))
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
    compressor = zstd.ZstdCompressor(level=19)
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as tar:
        for file in sorted(source_dir.rglob("*")):
            if not file.is_file():
                continue
            if file.name == "bundle.tar.zst":
                continue
            tar.add(file, arcname=file.relative_to(source_dir).as_posix())
    archive_path.write_bytes(compressor.compress(buffer.getvalue()))


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

    # Keep APK fallback in sync with bundle config.
    apk_config_dir = ROOT / "flutter" / "assets" / "config"
    apk_config_dir.mkdir(parents=True, exist_ok=True)
    write_json(apk_config_dir / "app_config.json", app_config)

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
    ability_jobs: list[tuple[str, bool, int]] = []
    for pokemon_id in range(1, max_id + 1):
        detail_path = details_dir / f"{pokemon_id}.json"
        if not detail_path.exists():
            continue
        detail = json.loads(detail_path.read_text(encoding="utf-8"))
        move_ids.update(collect_move_ids_from_detail(detail))
        for ability in detail.get("abilities", []):
            slug = str(ability.get("nameEn", "")).lower().replace(" ", "-")
            if slug:
                ability_jobs.append((slug, ability.get("isHidden", False), pokemon_id))

    missing_moves = sorted(mid for mid in move_ids if mid not in builder.move_cache)
    print(f"  moves to fetch: {len(missing_moves)}", flush=True)
    for move_id in missing_moves:
        try:
            builder.fetch_move(move_id)
        except requests.RequestException as exc:
            print(f"  warn: move #{move_id}: {exc}", file=sys.stderr)

    print(f"  abilities to register: {len(ability_jobs)}", flush=True)
    for slug, is_hidden, pokemon_id in ability_jobs:
        try:
            fetched = builder.fetch_ability(slug, is_hidden=is_hidden)
            builder.register_ability(fetched, pokemon_id)
        except requests.RequestException as exc:
            print(f"  warn: ability {slug}: {exc}", file=sys.stderr)


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


def build_bundle(
    *,
    cdn_base: str,
    output_dir: Path,
    min_id: int,
    max_id: int,
    delay_s: float,
    resume: bool = False,
) -> None:
    cdn_base = cdn_base.rstrip("/")
    staging = output_dir / "staging"
    upload_bundle = output_dir / "upload" / BUNDLE_CDN_PREFIX
    artwork_staging = output_dir / "artwork_staging"

    import shutil

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
    (staging / "type_icons").mkdir(exist_ok=True)
    (staging / "game_icons").mkdir(exist_ok=True)

    builder = PokeApiBuilder(delay_s=delay_s)
    session = builder.session

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

    for pokemon_id in range(min_id, max_id + 1):
        detail_path = staging / "details" / f"{pokemon_id}.json"
        if resume and detail_path.exists():
            continue
        print(f"#{pokemon_id}/{max_id}…", flush=True)
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

    warm_builder_caches_from_details(builder, staging, max_id)
    summaries = summaries_from_details(staging, max_id)
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

    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    reference_meta = stage_bundle_reference_data(staging, published_at=published_at)

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
    import shutil

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
    parser = argparse.ArgumentParser(description="Build TitoDex dex CDN bundle v5")
    parser.add_argument(
        "--cdn-base",
        default="https://dex.example.com",
        help="Public CDN base URL (no trailing slash)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("dist/dex-v5"),
        help="Output directory",
    )
    parser.add_argument("--min-id", type=int, default=1)
    parser.add_argument("--max-id", type=int, default=TITODEX_MAX_NATIONAL_ID)
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

    build_bundle(
        cdn_base=args.cdn_base,
        output_dir=args.output,
        min_id=args.min_id,
        max_id=args.max_id,
        delay_s=args.delay,
        resume=args.resume,
    )


if __name__ == "__main__":
    main()
