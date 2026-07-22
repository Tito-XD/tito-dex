"""Pure helpers for normalising PokeAPI Pokemon varieties/forms.

The national dex stays species-based.  These helpers describe the battle or
appearance variants nested under a species without inventing entries for
universal battle states such as a Tera Type or Dynamax.
"""

from __future__ import annotations

from typing import Any


REGIONAL_SUFFIXES: dict[str, str] = {
    "alola": "阿罗拉的样子",
    "galar": "伽勒尔的样子",
    "hisui": "洗翠的样子",
    "paldea": "帕底亚的样子",
}

# Useful when the upstream form resource has not been translated.  This is
# intentionally suffix based: the species name still comes from PokeAPI's
# Simplified Chinese species catalogue.
FORM_SUFFIX_ZH: dict[str, str] = {
    **REGIONAL_SUFFIXES,
    "mega": "超级进化",
    "mega-x": "超级进化X",
    "mega-y": "超级进化Y",
    "gmax": "超极巨化",
    "primal": "原始回归",
    "origin": "起源形态",
    "therian": "灵兽形态",
    "incarnate": "化身形态",
    "aria": "歌声形态",
    "pirouette": "舞步形态",
    "10": "10%形态",
    "10-power-construct": "10%形态（群聚变形）",
    "50": "50%形态",
    "50-power-construct": "50%形态（群聚变形）",
    "complete": "完全体形态",
    "school": "鱼群形态",
    "solo": "单独的样子",
    "blade": "剑形态",
    "shield": "盾牌形态",
    "zen": "达摩模式",
    "zen-galar": "达摩模式（伽勒尔）",
    "hangry": "空腹花纹",
    "crowned": "王之形态",
    "crowned-sword": "剑之王",
    "crowned-shield": "盾之王",
    "hero": "全能形态",
    "zero": "零之形态",
    "terastal": "太晶形态",
    "stellar": "星晶形态",
}


def variety_suffix(species_slug: str, pokemon_slug: str) -> str:
    """Return the stable suffix that differentiates a variety."""
    prefix = f"{species_slug}-"
    return pokemon_slug[len(prefix) :] if pokemon_slug.startswith(prefix) else pokemon_slug


def classify_form(
    species_slug: str,
    pokemon_slug: str,
    *,
    is_battle_only: bool = False,
    is_mega: bool = False,
    cosmetic_only: bool = False,
) -> str:
    """Map a PokeAPI variety to TitoDex's small, future-proof taxonomy."""
    suffix = variety_suffix(species_slug, pokemon_slug)
    if suffix in REGIONAL_SUFFIXES or any(
        suffix.endswith(f"-{region}") for region in REGIONAL_SUFFIXES
    ):
        return "regional"
    if is_mega or suffix == "mega" or suffix.startswith("mega-"):
        return "mega"
    if suffix == "gmax" or suffix.endswith("-gmax"):
        return "gigantamax"
    if cosmetic_only:
        return "cosmetic"
    if is_battle_only:
        return "battle"
    return "form"


def battle_signature(pokemon: dict[str, Any]) -> tuple[Any, ...]:
    """Fields which decide whether a variety is more than a visual skin."""
    types = tuple(
        entry.get("type", {}).get("name")
        for entry in sorted(pokemon.get("types", []), key=lambda item: item.get("slot", 0))
    )
    stats = tuple(
        (entry.get("stat", {}).get("name"), entry.get("base_stat"))
        for entry in pokemon.get("stats", [])
    )
    abilities = tuple(
        sorted(
            (
                entry.get("ability", {}).get("name"),
                bool(entry.get("is_hidden")),
                entry.get("slot"),
            )
            for entry in pokemon.get("abilities", [])
        )
    )
    moves = tuple(sorted(entry.get("move", {}).get("name") for entry in pokemon.get("moves", [])))
    return types, stats, abilities, moves, pokemon.get("height"), pokemon.get("weight")


def is_cosmetic_variety(
    default_pokemon: dict[str, Any],
    candidate: dict[str, Any],
    *,
    is_battle_only: bool = False,
) -> bool:
    """Treat a variety as cosmetic only when all battle-facing data matches."""
    return not is_battle_only and battle_signature(default_pokemon) == battle_signature(candidate)


def form_label_zh(
    species_name_zh: str,
    species_slug: str,
    pokemon_slug: str,
    *,
    upstream_form_name_zh: str | None = None,
    is_default: bool = False,
) -> str:
    if is_default:
        return species_name_zh
    upstream = (upstream_form_name_zh or "").strip()
    if upstream and upstream.lower() not in {pokemon_slug.lower(), "default"}:
        if species_name_zh in upstream:
            return upstream
        return f"{species_name_zh}（{upstream}）"
    suffix = variety_suffix(species_slug, pokemon_slug)
    suffix_zh = FORM_SUFFIX_ZH.get(suffix)
    if suffix_zh is None:
        for region, region_zh in REGIONAL_SUFFIXES.items():
            if suffix.endswith(f"-{region}"):
                base = suffix[: -(len(region) + 1)].replace("-", " ")
                suffix_zh = f"{region_zh} · {base}"
                break
    return f"{species_name_zh}（{suffix_zh or suffix.replace('-', ' ')}）"


def form_search_terms(
    species_slug: str,
    pokemon_slug: str,
    name_zh: str,
    form_name_zh: str | None,
) -> list[str]:
    terms = {pokemon_slug, variety_suffix(species_slug, pokemon_slug), name_zh}
    if form_name_zh:
        terms.add(form_name_zh)
    return sorted(term for term in terms if term)
