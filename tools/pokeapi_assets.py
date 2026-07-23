"""Resolve PokeAPI sprite / artwork / animated URLs by game version group."""

from __future__ import annotations

from typing import Any

# PokeAPI version-group slug → (sprites.versions key, sub-key).
VERSION_GROUP_SPRITE_PATH: dict[str, tuple[str, str]] = {
    "red-blue": ("generation-i", "red-blue"),
    "yellow": ("generation-i", "yellow"),
    "gold-silver": ("generation-ii", "gold"),
    "crystal": ("generation-ii", "crystal"),
    "ruby-sapphire": ("generation-iii", "ruby-sapphire"),
    "emerald": ("generation-iii", "emerald"),
    "firered-leafgreen": ("generation-iii", "firered-leafgreen"),
    "diamond-pearl": ("generation-iv", "diamond-pearl"),
    "platinum": ("generation-iv", "platinum"),
    "heartgold-soulsilver": ("generation-iv", "heartgold-soulsilver"),
    "black-white": ("generation-v", "black-white"),
    "black-2-white-2": ("generation-v", "black-2-white-2"),
    "x-y": ("generation-vi", "x-y"),
    "omega-ruby-alpha-sapphire": ("generation-vi", "omega-ruby-alpha-sapphire"),
    "sun-moon": ("generation-vii", "sun-moon"),
    "ultra-sun-ultra-moon": ("generation-vii", "ultra-sun-ultra-moon"),
    "lets-go-pikachu-lets-go-eevee": (
        "generation-vii",
        "lets-go-pikachu-lets-go-eevee",
    ),
    "sword-shield": ("generation-viii", "sword-shield"),
    "brilliant-diamond-shining-pearl": (
        "generation-viii",
        "brilliant-diamond-shining-pearl",
    ),
    "legends-arceus": ("generation-viii", "legends-arceus"),
    "scarlet-violet": ("generation-ix", "scarlet-violet"),
}

# Unique version groups used for CDN bulk sprite builds.
ALL_SPRITE_VERSION_GROUPS: tuple[str, ...] = tuple(VERSION_GROUP_SPRITE_PATH.keys())

# Roman-numeral generation (1–9) for edition default display.
VERSION_GROUP_GENERATION: dict[str, int] = {
    "red-blue": 1,
    "yellow": 1,
    "gold-silver": 2,
    "crystal": 2,
    "ruby-sapphire": 3,
    "emerald": 3,
    "firered-leafgreen": 3,
    "diamond-pearl": 4,
    "platinum": 4,
    "heartgold-soulsilver": 4,
    "black-white": 5,
    "black-2-white-2": 5,
    "x-y": 6,
    "omega-ruby-alpha-sapphire": 6,
    "sun-moon": 7,
    "ultra-sun-ultra-moon": 7,
    "lets-go-pikachu-lets-go-eevee": 7,
    "sword-shield": 8,
    "brilliant-diamond-shining-pearl": 8,
    "legends-arceus": 8,
    "scarlet-violet": 9,
}


def generation_for_version_group(version_group: str) -> int:
    return VERSION_GROUP_GENERATION.get(version_group, 9)


def _dig(data: dict[str, Any], *keys: str) -> Any:
    cur: Any = data
    for key in keys:
        if not isinstance(cur, dict):
            return None
        cur = cur.get(key)
    return cur


def sprite_url_for_version_group(
    sprites: dict[str, Any],
    version_group: str,
    *,
    allow_universal_fallback: bool = True,
) -> str | None:
    """Pick in-game front sprite for a PokeAPI version-group slug."""
    path = VERSION_GROUP_SPRITE_PATH.get(version_group)
    if path:
        gen_key, sub_key = path
        url = _dig(sprites, "versions", gen_key, sub_key, "front_default")
        if url:
            return url
        # Same generation fallback (e.g. BDSP missing → DP).
        gen_bucket = sprites.get("versions", {}).get(gen_key, {})
        if isinstance(gen_bucket, dict):
            for sub in gen_bucket.values():
                if isinstance(sub, dict):
                    url = sub.get("front_default")
                    if url:
                        return url

    if not allow_universal_fallback:
        return None

    other = sprites.get("other") or {}
    for key in ("home", "official-artwork"):
        url = (other.get(key) or {}).get("front_default")
        if url:
            return url
    return sprites.get("front_default")


def official_artwork_url(sprites: dict[str, Any]) -> str | None:
    other = sprites.get("other") or {}
    artwork = other.get("official-artwork") or {}
    return artwork.get("front_default") or (other.get("home") or {}).get(
        "front_default"
    )


def animated_sprite_url(sprites: dict[str, Any]) -> str | None:
    """Showdown animated GIF (front_default)."""
    other = sprites.get("other") or {}
    showdown = other.get("showdown") or {}
    return showdown.get("front_default")


def type_icon_url_pokeapi(type_detail: dict[str, Any], *, prefer_gen: str = "generation-ix") -> str | None:
    """PokeAPI type icon; prefers Scarlet/Violet, then Sword/Shield, then Colosseum."""
    sprites = type_detail.get("sprites") or {}
    order = (
        prefer_gen,
        "generation-viii",
        "generation-vii",
        "generation-vi",
        "generation-v",
        "generation-iv",
        "generation-iii",
    )
    for gen_key in order:
        gen = sprites.get(gen_key) or {}
        if not isinstance(gen, dict):
            continue
        for sub in gen.values():
            if isinstance(sub, dict):
                url = sub.get("name_icon") or sub.get("front_default")
                if url:
                    return url
        if gen_key == "generation-iii":
            col = (gen.get("colosseum") or {}).get("name_icon")
            if col:
                return col
    type_id = type_detail.get("id")
    type_name = type_detail.get("name")
    if type_name == "fairy" and type_id:
        return (
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/"
            "sprites/types/generation-iii/colosseum/10001.png"
        )
    return None


def build_sprite_url_map(
    sprites: dict[str, Any],
    version_groups: tuple[str, ...] = ALL_SPRITE_VERSION_GROUPS,
) -> dict[str, str]:
    """Build version-group → remote URL map for one Pokémon."""
    result: dict[str, str] = {}
    for vg in version_groups:
        url = sprite_url_for_version_group(
            sprites,
            vg,
            allow_universal_fallback=False,
        )
        if url:
            result[vg] = url
    return result
