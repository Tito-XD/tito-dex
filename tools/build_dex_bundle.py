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

POKEAPI_BASE = "https://pokeapi.co/api/v2"
TYPE_ICON_BASE = (
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/"
    "sprites/types/generation-iii/colosseum"
)
BUNDLE_VERSION = 5
BUNDLE_CDN_PREFIX = "v3"
TITODEX_MAX_NATIONAL_ID = 1025
HGSS_MAX_ID = 493
HGSS_VERSION_GROUP = "heartgold-soulsilver"
SV_VERSION_GROUP = "scarlet-violet"
SS_VERSION_GROUP = "sword-shield"
JOHTO_POKEDEX_NAMES = {"original-johto", "updated-johto"}
HGSS_FLAVOR_VERSIONS = ["gold", "silver", "crystal", "heartgold", "soulsilver"]
HGSS_ENCOUNTER_VERSIONS = {"heartgold", "soulsilver"}
SV_ENCOUNTER_VERSIONS = {"scarlet", "violet"}
SS_ENCOUNTER_VERSIONS = {"sword", "shield"}

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
        time.sleep(self.delay_s)
        response = self.session.get(url, timeout=60)
        response.raise_for_status()
        return response.json()

    def _get_json_list(self, path: str) -> list[Any]:
        url = path if path.startswith("http") else f"{POKEAPI_BASE}{path}"
        time.sleep(self.delay_s)
        response = self.session.get(url, timeout=60)
        response.raise_for_status()
        return response.json()

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
        flavor_entries = parse_flavor_entries(species.get("flavor_text_entries", []))
        move_entries = pokemon.get("moves", [])
        move_set = fetch_move_set_for_version_group(self, move_entries, HGSS_VERSION_GROUP)
        move_sets: dict[str, dict[str, list[dict[str, Any]]]] = {
            HGSS_VERSION_GROUP: move_set,
        }
        if pokemon_id > HGSS_MAX_ID:
            sv_moves = fetch_move_set_for_version_group(
                self, move_entries, SV_VERSION_GROUP
            )
            if any(sv_moves.values()):
                move_sets[SV_VERSION_GROUP] = sv_moves
            ss_moves = fetch_move_set_for_version_group(
                self, move_entries, SS_VERSION_GROUP
            )
            if any(ss_moves.values()):
                move_sets[SS_VERSION_GROUP] = ss_moves

        abilities = self.fetch_abilities(pokemon.get("abilities", []), pokemon_id)
        obtain_locations = fetch_obtain_locations(self, pokemon_id)
        gender_female = gender_female_percent(species.get("gender_rate"))
        egg_groups = [
            EGG_GROUP_ZH.get(g["name"], g["name"]) for g in species.get("egg_groups", [])
        ]
        hatch_counter = species.get("hatch_counter")

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
            "eggGroups": egg_groups,
        }
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


def encounter_area_label_zh(slug: str) -> str:
    if slug in ENCOUNTER_AREA_LABELS_ZH:
        return ENCOUNTER_AREA_LABELS_ZH[slug]
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
        slug = area_url.rstrip("/").split("/")[-1]
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


def fetch_obtain_locations(
    builder: PokeApiBuilder, pokemon_id: int
) -> list[dict[str, Any]]:
    if pokemon_id <= HGSS_MAX_ID:
        return fetch_version_obtain_locations(
            builder, pokemon_id, HGSS_ENCOUNTER_VERSIONS
        )
    sv = fetch_version_obtain_locations(builder, pokemon_id, SV_ENCOUNTER_VERSIONS)
    if sv:
        return sv
    return fetch_version_obtain_locations(builder, pokemon_id, SS_ENCOUNTER_VERSIONS)


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


def parse_flavor_entries(entries: list[dict[str, Any]]) -> list[dict[str, str]]:
    result: list[dict[str, str]] = []
    for version in HGSS_FLAVOR_VERSIONS:
        zh_hans = zh_hant = english = None
        for entry in entries:
            if entry.get("version", {}).get("name") != version:
                continue
            language = entry.get("language", {}).get("name", "")
            text = " ".join(entry.get("flavor_text", "").replace("\n", " ").split())
            if not text:
                continue
            if language in ("zh-Hans", "zh-hans"):
                zh_hans = text
            elif language == "zh-Hant":
                zh_hant = text
            elif language == "en":
                english = text
        chosen = zh_hans or zh_hant or english
        if chosen:
            result.append({"version": version, "text": chosen})
    return result


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

    for entry in move_entries:
        move_id = id_from_url(entry["move"]["url"])
        for detail in entry.get("version_group_details", []):
            if detail.get("version_group", {}).get("name") != version_group:
                continue
            method = detail.get("move_learn_method", {}).get("name")
            if method not in ("level-up", "machine", "egg"):
                continue
            level = detail.get("level_learned_at") or 0
            target = {"level-up": level_up, "machine": machine, "egg": egg}[method]
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
            if file.is_file():
                tar.add(file, arcname=file.relative_to(source_dir).as_posix())
    archive_path.write_bytes(compressor.compress(buffer.getvalue()))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_bundle(
    *,
    cdn_base: str,
    output_dir: Path,
    min_id: int,
    max_id: int,
    delay_s: float,
) -> None:
    cdn_base = cdn_base.rstrip("/")
    staging = output_dir / "staging"
    upload_bundle = output_dir / "upload" / BUNDLE_CDN_PREFIX
    artwork_staging = output_dir / "artwork_staging"

    if staging.exists():
        import shutil

        shutil.rmtree(staging)
    if artwork_staging.exists():
        import shutil

        shutil.rmtree(artwork_staging)
    staging.mkdir(parents=True)
    artwork_staging.mkdir(parents=True)
    (staging / "details").mkdir()
    (staging / "sprites").mkdir()
    (staging / "type_icons").mkdir()

    builder = PokeApiBuilder(delay_s=delay_s)
    session = builder.session

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

    print("Downloading type icons…")
    for type_name in TYPE_NAMES:
        try:
            icon_url = builder.type_icon_url(type_name)
            if not icon_url:
                print(f"  warn: no colosseum icon for {type_name}", file=sys.stderr)
                continue
            png = download_bytes(session, icon_url)
            optimized = optimize_png(png, max_width=64)
            (staging / "type_icons" / f"{type_name}.png").write_bytes(optimized)
        except requests.RequestException as exc:
            print(f"  warn: type icon {type_name}: {exc}", file=sys.stderr)

    summaries: list[dict[str, Any]] = []
    for pokemon_id in range(min_id, max_id + 1):
        print(f"#{pokemon_id}/{max_id}…")
        summary, detail, sprite_remote = builder.build_detail(pokemon_id, cdn_base)
        summaries.append(summary)
        write_json(staging / "details" / f"{pokemon_id}.json", detail)

        if sprite_remote:
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

    size_bytes = directory_size(staging)
    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    manifest = {
        "version": BUNDLE_VERSION,
        "complete": max_id >= TITODEX_MAX_NATIONAL_ID and min_id == 1,
        "preferOffline": True,
        "downloadedAt": published_at,
        "pokemonCount": len(summaries),
        "moveCount": len(moves_payload),
        "abilityCount": len(abilities_payload),
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
        "bundle.tar.zst",
    ):
        shutil.copy2(staging / name, upload_bundle / name)
    shutil.copytree(staging / "details", upload_bundle / "details")
    shutil.copytree(staging / "sprites", upload_bundle / "sprites")
    shutil.copytree(staging / "type_icons", upload_bundle / "type_icons")

    archive_sha = sha256_file(upload_bundle / "bundle.tar.zst")
    bundle_manifest = {
        "bundleVersion": BUNDLE_VERSION,
        "pokemonCount": len(summaries),
        "archiveUrl": f"{cdn_base}/{BUNDLE_CDN_PREFIX}/bundle.tar.zst",
        "archiveSha256": archive_sha,
        "archiveSizeBytes": (upload_bundle / "bundle.tar.zst").stat().st_size,
        "publishedAt": published_at,
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
    args = parser.parse_args()

    build_bundle(
        cdn_base=args.cdn_base,
        output_dir=args.output,
        min_id=args.min_id,
        max_id=args.max_id,
        delay_s=args.delay,
    )


if __name__ == "__main__":
    main()
