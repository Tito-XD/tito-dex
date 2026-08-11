#!/usr/bin/env python3
"""Build the per-form media audit and enrich the 52poke media catalog.

The audit is deliberately conservative: a species-level PokeAPI id is not
counted as exact media for a non-default cosmetic form, and a shared 52poke
file stays marked as shared instead of being duplicated as independent art.
52poke files are resolved through MediaWiki ``imageinfo`` and can be verified
with a streamed HTTP request before their URLs are written to the catalog.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import requests


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DETAILS = ROOT / "dist" / "dex-v19" / "staging" / "details"
DEFAULT_STAGING = ROOT / "dist" / "dex-v19" / "staging"
DEFAULT_CATALOG = ROOT / "data" / "l10n" / "zh" / "media_catalog_52poke.json"
DEFAULT_EXISTENCE = ROOT / "data" / "dex" / "sprite_version_existence.json"
DEFAULT_OUTPUT = ROOT / "data" / "dex" / "form_media_audit.json"
WIKI_API = "https://wiki.52poke.com/api.php"
WIKI_MEDIA_RIGHTS = "source page attribution; underlying media rights vary"
USER_AGENT = "TitoDex-form-media-audit/1.0 (maintainer data build)"
RETRIES = 4
INTENTIONALLY_SHARED_VISUAL_SPECIES = {414, 664, 665}

# Full-size files use human-readable names that predate HOME's compact form
# codes. These overrides are intentionally explicit; files that cannot be
# tied to one of our form records are classified as auxiliary below instead
# of being matched by substring.
_EXPLICIT_FILE_FORM_KEYS: dict[tuple[int, str], tuple[str, ...]] = {
    (128, "128Tauros-Combat.png"): ("tauros-paldea-combat-breed",),
    (128, "128Tauros-Blaze.png"): ("tauros-paldea-blaze-breed",),
    (128, "128Tauros-Aqua.png"): ("tauros-paldea-aqua-breed",),
    (550, "550Basculin-Red.png"): ("basculin-red-striped",),
    (550, "550Basculin-Blue.png"): ("basculin-blue-striped",),
    (550, "550Basculin-White.png"): ("basculin-white-striped",),
    (555, "555Darmanitan-Galar.png"): ("darmanitan-galar-standard",),
    (593, "593Jellicent-Famale.png"): ("jellicent-female",),
    (646, "646B.png"): ("kyurem-black",),
    (646, "646W.png"): ("kyurem-white",),
    (647, "647Keldeo-Resolution.png"): ("keldeo-resolute",),
    (678, "678Meowstic-Mega.png"): (
        "meowstic-male-mega",
        "meowstic-female-mega",
    ),
    (716, "716Xerneas.png"): ("xerneas-active",),
    (716, "716Xerneas2.png"): ("xerneas-neutral",),
    (720, "720Hoopa-Confined.png"): ("hoopa",),
    (774, "774Minior-Core.png"): ("minior-red",),
    (849, "849Toxtricity-Gigantamax.png"): (
        "toxtricity-amped-gmax",
        "toxtricity-low-key-gmax",
    ),
    (888, "888Zacian-Hero.png"): ("zacian",),
    (889, "889Zamazenta-Hero.png"): ("zamazenta",),
    (901, "901BUrsaluna-Bloodmoon.png"): ("ursaluna-bloodmoon",),
    (925, "925Maushold-Three.png"): ("maushold-family-of-three",),
    (925, "925Maushold-Four.png"): ("maushold-family-of-four",),
    (931, "931Squawkabilly-Green.png"): ("squawkabilly-green-plumage",),
    (982, "982Dudunsparce-Two.png"): ("dudunsparce-two-segment",),
    (982, "982Dudunsparce-Three.png"): ("dudunsparce-three-segment",),
    (1024, "1024Terapagos-Normal.png"): ("terapagos",),
}

_AUXILIARY_FILES = {
    (646, "646Kyurem-AltForme2.png"),
    (646, "646Kyurem-AltForme2a.png"),
    (646, "646Kyurem-AltForme1.png"),
    (646, "646Kyurem-AltForme1a.png"),
    (706, "705Sliggoo-Hisui.png"),
    (718, "718Zygarde-Cell.png"),
    (718, "718Zygarde-Core.png"),
    (842, "841Flapple-Gigantamax.png"),
}

_ALCREMIE_CREAMS = {
    "VanillaCream": "vanilla-cream",
    "CaramelSwirl": "caramel-swirl",
    "RubyCream": "ruby-cream",
    "RubySwirl": "ruby-swirl",
    "MatchaCream": "matcha-cream",
    "LemonCream": "lemon-cream",
    "SaltedCream": "salted-cream",
    "MintCream": "mint-cream",
    "RainbowSwirl": "rainbow-swirl",
}
_ALCREMIE_SWEETS = {
    "SbS": "strawberry-sweet",
    "LS": "love-sweet",
    "BS": "berry-sweet",
    "CS": "clover-sweet",
    "FS": "flower-sweet",
    "StS": "star-sweet",
    "RS": "ribbon-sweet",
}


_SPECIAL_CODES: dict[int, dict[str, str]] = {
    25: {
        "pikachu-rock-star": "Ro",
        "pikachu-belle": "Be",
        "pikachu-pop-star": "Po",
        "pikachu-phd": "Ph",
        "pikachu-libre": "Li",
        "pikachu-cosplay": "Co",
        "pikachu-original-cap": "O",
        "pikachu-hoenn-cap": "H",
        "pikachu-sinnoh-cap": "S",
        "pikachu-unova-cap": "U",
        "pikachu-kalos-cap": "K",
        "pikachu-alola-cap": "A",
        "pikachu-partner-cap": "P",
        "pikachu-starter": "Pa",
        "pikachu-world-cap": "W",
    },
    128: {
        "tauros-paldea-combat-breed": "PC",
        "tauros-paldea-blaze-breed": "PB",
        "tauros-paldea-aqua-breed": "PA",
    },
    172: {"pichu-spiky-eared": "S"},
    351: {"castform-sunny": "S", "castform-rainy": "R", "castform-snowy": "H"},
    386: {"deoxys-attack": "A", "deoxys-defense": "D", "deoxys-speed": "S"},
    412: {"burmy-sandy": "S", "burmy-trash": "G"},
    413: {"wormadam-sandy": "S", "wormadam-trash": "G"},
    414: {"mothim-sandy": "S", "mothim-trash": "G"},
    421: {"cherrim-sunshine": "S"},
    422: {"shellos-east": "E"},
    423: {"gastrodon-east": "E"},
    479: {
        "rotom-heat": "H",
        "rotom-wash": "W",
        "rotom-frost": "F",
        "rotom-fan": "Fa",
        "rotom-mow": "M",
    },
    483: {"dialga-origin": "O"},
    484: {"palkia-origin": "O"},
    487: {"giratina-origin": "O"},
    492: {"shaymin-sky": "S"},
    550: {"basculin-blue-striped": "B", "basculin-white-striped": "W"},
    555: {
        "darmanitan-zen": "Z",
        "darmanitan-galar-standard": "G",
        "darmanitan-galar-zen": "GZ",
    },
    585: {"deerling-summer": "S", "deerling-autumn": "A", "deerling-winter": "W"},
    586: {"sawsbuck-summer": "S", "sawsbuck-autumn": "A", "sawsbuck-winter": "W"},
    641: {"tornadus-therian": "T"},
    642: {"thundurus-therian": "T"},
    645: {"landorus-therian": "T"},
    905: {"enamorus-therian": "T"},
    646: {"kyurem-black": "B", "kyurem-white": "W"},
    647: {"keldeo-resolute": "R"},
    648: {"meloetta-pirouette": "P"},
    649: {
        "genesect-shock": "S",
        "genesect-burn": "B",
        "genesect-chill": "C",
        "genesect-douse": "D",
    },
    658: {"greninja-ash": "A", "greninja-battle-bond": "A"},
    669: {"flabebe-yellow": "Y", "flabebe-orange": "O", "flabebe-blue": "B", "flabebe-white": "W"},
    670: {
        "floette-yellow": "Y",
        "floette-orange": "O",
        "floette-blue": "B",
        "floette-white": "W",
        "floette-eternal": "E",
    },
    671: {"florges-yellow": "Y", "florges-orange": "O", "florges-blue": "B", "florges-white": "W"},
    676: {
        "furfrou-heart": "He",
        "furfrou-star": "St",
        "furfrou-diamond": "Di",
        "furfrou-debutante": "De",
        "furfrou-matron": "Ma",
        "furfrou-dandy": "Da",
        "furfrou-la-reine": "La",
        "furfrou-kabuki": "Ka",
        "furfrou-pharaoh": "Ph",
    },
    681: {"aegislash-blade": "B"},
    710: {"pumpkaboo-small": "Sm", "pumpkaboo-large": "La", "pumpkaboo-super": "Su"},
    711: {"gourgeist-small": "Sm", "gourgeist-large": "La", "gourgeist-super": "Su"},
    716: {"xerneas-neutral": "N", "xerneas-active": ""},
    718: {
        "zygarde-10": "T",
        "zygarde-10-power-construct": "T",
        "zygarde-50": "",
        "zygarde-50-power-construct": "",
        "zygarde-complete": "C",
        "zygarde-mega": "M",
    },
    720: {"hoopa-unbound": "U"},
    741: {"oricorio-pom-pom": "Po", "oricorio-pau": "Pa", "oricorio-sensu": "Se"},
    745: {"lycanroc-midnight": "Mn", "lycanroc-dusk": "D"},
    746: {"wishiwashi-school": "Sc"},
    778: {"mimikyu-busted": "B", "mimikyu-totem-busted": "B"},
    800: {"necrozma-dusk": "DM", "necrozma-dawn": "DW", "necrozma-ultra": "U"},
    801: {"magearna-original": "O", "magearna-mega": "M", "magearna-original-mega": "OM"},
    842: {"appletun-gmax": "GM"},
    845: {"cramorant-gulping": "Gu", "cramorant-gorging": "Go"},
    854: {"sinistea-phony": "P", "sinistea-antique": "A"},
    855: {"polteageist-phony": "P", "polteageist-antique": "A"},
    849: {"toxtricity-low-key": "L", "toxtricity-amped-gmax": "GM", "toxtricity-low-key-gmax": "GM"},
    875: {"eiscue-noice": "NF"},
    877: {"morpeko-hangry": "HM"},
    888: {"zacian-crowned": "C"},
    889: {"zamazenta-crowned": "C"},
    890: {"eternatus-eternamax": "E"},
    892: {
        "urshifu-rapid-strike": "R",
        "urshifu-single-strike-gmax": "GM",
        "urshifu-rapid-strike-gmax": "RGM",
    },
    893: {"zarude-dada": "D"},
    898: {"calyrex-ice": "I", "calyrex-shadow": "S"},
    901: {"ursaluna-bloodmoon": "B"},
    925: {"maushold-family-of-four": "F", "maushold-family-of-three": ""},
    931: {"squawkabilly-blue-plumage": "B", "squawkabilly-yellow-plumage": "Y", "squawkabilly-white-plumage": "W"},
    964: {"palafin-hero": "H"},
    978: {
        "tatsugiri-droopy": "D",
        "tatsugiri-stretchy": "S",
        "tatsugiri-curly-mega": "M",
        "tatsugiri-droopy-mega": "DM",
        "tatsugiri-stretchy-mega": "SM",
    },
    982: {"dudunsparce-three-segment": "Th"},
    999: {"gimmighoul-roaming": "R"},
    1007: {
        "koraidon-limited-build": "L",
        "koraidon-sprinting-build": "L",
        "koraidon-swimming-build": "L",
        "koraidon-gliding-build": "L",
    },
    1008: {
        "miraidon-low-power-mode": "L",
        "miraidon-drive-mode": "L",
        "miraidon-aquatic-mode": "L",
        "miraidon-glide-mode": "L",
    },
    1012: {"poltchageist-counterfeit": "C", "poltchageist-artisan": "A"},
    1013: {"sinistcha-unremarkable": "U", "sinistcha-masterpiece": "M"},
    1017: {"ogerpon-wellspring-mask": "W", "ogerpon-hearthflame-mask": "H", "ogerpon-cornerstone-mask": "C"},
    1024: {"terapagos-terastal": "T", "terapagos-stellar": "S"},
}

_VIVILLON_CODES = {
    "meadow": "",
    "icy-snow": "Icy",
    "polar": "Pol",
    "tundra": "Tun",
    "continental": "Con",
    "garden": "Gar",
    "elegant": "Ele",
    "modern": "Mod",
    "marine": "Mar",
    "archipelago": "Arc",
    "high-plains": "Hig",
    "sandstorm": "San",
    "river": "Riv",
    "monsoon": "Mon",
    "savanna": "Sav",
    "sun": "Sun",
    "ocean": "Oce",
    "jungle": "Jun",
    "fancy": "Fan",
    "poke-ball": "Pok",
}
_CREAM_CODES = {
    "vanilla-cream": "VC",
    "ruby-cream": "RC",
    "matcha-cream": "MaC",
    "mint-cream": "MiC",
    "lemon-cream": "LC",
    "salted-cream": "SC",
    "ruby-swirl": "RuS",
    "caramel-swirl": "CS",
    "rainbow-swirl": "RaS",
}
_SWEET_CODES = {
    "strawberry-sweet": "S",
    "berry-sweet": "B",
    "love-sweet": "L",
    "flower-sweet": "F",
    "star-sweet": "St",
    "clover-sweet": "C",
    "ribbon-sweet": "R",
}


def _slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def _species_root(name_en: str, forms: list[dict[str, Any]]) -> str:
    keys = [str(form.get("key") or "") for form in forms if form.get("key")]
    if len(keys) > 1:
        prefix = os.path.commonprefix(keys).rstrip("-")
        if prefix:
            if "-" in prefix and not all(
                key == prefix or key.startswith(f"{prefix}-") for key in keys
            ):
                prefix = prefix.rsplit("-", 1)[0]
            if prefix:
                return prefix
    return _slug(name_en)


def form_codes(
    species_id: int, form: dict[str, Any], species_root: str
) -> set[str]:
    key = str(form.get("key") or "")
    special = _SPECIAL_CODES.get(species_id, {}).get(key)
    if special is not None:
        return (
            {special, ""}
            if form.get("isDefault") and species_id in {854, 855, 1012, 1013}
            else {special}
        )
    suffix = key.removeprefix(species_root).lstrip("-")
    if species_id == 201:
        token = suffix or "a"
        code = "EX" if token == "exclamation" else "QU" if token == "question" else token.upper()
        return {code, ""} if form.get("isDefault") else {code}
    if species_id in {493, 773} and suffix not in {"", "normal", "unknown"}:
        return {suffix.title()}
    if species_id in {664, 665, 666}:
        return {_VIVILLON_CODES.get(suffix, suffix[:3].title())}
    if species_id == 774:
        if suffix.endswith("-meteor"):
            return {""}
        return {
            {
                "red": "R",
                "orange": "O",
                "yellow": "Y",
                "green": "G",
                "blue": "B",
                "indigo": "I",
                "violet": "V",
            }.get(suffix, "")
        }
    if species_id == 869:
        if suffix == "gmax":
            return {"GM"}
        for cream, cream_code in _CREAM_CODES.items():
            if suffix.startswith(f"{cream}-"):
                sweet = suffix[len(cream) + 1 :]
                if cream == "vanilla-cream" and sweet == "strawberry-sweet":
                    return {""}
                return {f"{cream_code}{_SWEET_CODES.get(sweet, '')}"}
    if suffix in {"mega-x", "mega-y", "mega-z", "mega", "gmax"}:
        code = {
            "mega-x": "MX",
            "mega-y": "MY",
            "mega-z": "MZ",
            "mega": "M",
            "gmax": "GM",
        }[suffix]
        return {code}
    if suffix.endswith("-mega"):
        return {"M"}
    generic_suffixes = {
        "alola": "A",
        "galar": "G",
        "hisui": "H",
        "paldea": "P",
        "female": "F",
        "male": "",
        "totem": "T",
        "primal": "P",
        "origin": "O",
        "therian": "T",
    }
    for token, code in generic_suffixes.items():
        if suffix == token or suffix.endswith(f"-{token}"):
            return {code}
    if form.get("isDefault"):
        return {""}
    return set()


def _home_code(file_name: str, species_id: int) -> str | None:
    match = re.fullmatch(r"HOME_0*([0-9]+)([A-Za-z]*)\.png", file_name)
    if not match or int(match.group(1)) != species_id:
        return None
    return match.group(2)


def _form_file_suffix(file_name: str, species_root: str) -> str | None:
    stem = Path(file_name).stem
    stem = re.sub(r"^0*\d+", "", stem)
    name_token = re.sub(r"[^a-z0-9]", "", species_root.lower())
    normalized = re.sub(r"[^a-z0-9]", "", stem.lower())
    if not normalized.startswith(name_token):
        return None
    return normalized[len(name_token) :]


def _form_aliases(key: str, species_root: str) -> set[str]:
    suffix = key.removeprefix(species_root).lstrip("-")
    if not suffix:
        return {""}
    aliases = {re.sub(r"[^a-z0-9]", "", suffix)}
    replacements = {
        "gmax": "gigantamax",
        "alola": "alola",
        "galar": "galar",
        "hisui": "hisui",
        "originalcap": "original",
        "hoenncap": "hoenn",
        "sinnohcap": "sinnoh",
        "unovacap": "unova",
        "kaloscap": "kalos",
        "alolacap": "alola",
        "partnercap": "partner",
        "worldcap": "world",
    }
    compact = next(iter(aliases))
    for source, target in replacements.items():
        if source in compact:
            aliases.add(compact.replace(source, target))
    return aliases


def _explicit_file_form_keys(species_id: int, file_name: str) -> tuple[str, ...]:
    explicit = _EXPLICIT_FILE_FORM_KEYS.get((species_id, file_name))
    if explicit is not None:
        return explicit
    if species_id == 869:
        match = re.fullmatch(r"869Alcremie-([A-Za-z]+)\.png", file_name)
        if match:
            token = match.group(1)
            for cream_token, cream in _ALCREMIE_CREAMS.items():
                if not token.startswith(cream_token):
                    continue
                sweet = _ALCREMIE_SWEETS.get(token[len(cream_token) :])
                if sweet:
                    return (f"alcremie-{cream}-{sweet}",)
    return ()


def map_form_keys(
    file_name: str,
    species_id: int,
    name_en: str,
    forms: list[dict[str, Any]],
) -> tuple[list[str], str | None]:
    species_root = _species_root(name_en, forms)
    code = (
        "GM"
        if species_id == 842 and file_name == "HOME_841GM.png"
        else _home_code(file_name, species_id)
    )
    if code is not None:
        matches = [
            str(form["key"])
            for form in forms
            if code in form_codes(species_id, form, species_root)
        ]
        return matches, code
    explicit = _explicit_file_form_keys(species_id, file_name)
    if explicit:
        available = {str(form["key"]) for form in forms}
        return [key for key in explicit if key in available], None
    file_suffix = _form_file_suffix(file_name, species_root)
    if file_suffix is None:
        return [], None
    matches = [
        str(form["key"])
        for form in forms
        if file_suffix in _form_aliases(str(form["key"]), species_root)
    ]
    if not matches and file_suffix == "":
        matches = [str(form["key"]) for form in forms if form.get("isDefault")]
    return matches, None


def _chunks(values: list[str], size: int) -> Iterable[list[str]]:
    for index in range(0, len(values), size):
        yield values[index : index + size]


def resolve_imageinfo(
    session: requests.Session, files: list[str]
) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for batch in _chunks(sorted(set(files)), 40):
        requested_names = {
            name.replace("_", " ").casefold(): name for name in batch
        }
        payload: dict[str, Any] | None = None
        for attempt in range(RETRIES):
            try:
                response = session.get(
                    WIKI_API,
                    params={
                        "action": "query",
                        "titles": "|".join(f"File:{name}" for name in batch),
                        "prop": "imageinfo",
                        "iiprop": "url|size|mime|sha1|timestamp",
                        "redirects": 1,
                        "format": "json",
                        "formatversion": 2,
                    },
                    timeout=(20, 90),
                )
                response.raise_for_status()
                payload = response.json()
                break
            except (requests.RequestException, ValueError):
                if attempt == RETRIES - 1:
                    raise
        for page in (payload or {}).get("query", {}).get("pages", []):
            info = (page.get("imageinfo") or [None])[0]
            if not info:
                continue
            title = str(page.get("title") or "")
            name = title.split(":", 1)[-1]
            original_name = requested_names.get(
                name.replace("_", " ").casefold(), name
            )
            result[original_name] = {
                "url": info.get("url"),
                "descriptionUrl": info.get("descriptionurl"),
                "width": info.get("width"),
                "height": info.get("height"),
                "mime": info.get("mime"),
                "sha1": info.get("sha1"),
                "timestamp": info.get("timestamp"),
            }
    return result


def verify_url(url: str) -> bool:
    for _ in range(RETRIES):
        try:
            response = requests.get(
                url,
                headers={
                    "User-Agent": USER_AGENT,
                    "Referer": "https://wiki.52poke.com/",
                    "Range": "bytes=0-1023",
                },
                stream=True,
                timeout=(20, 60),
            )
            try:
                content_type = response.headers.get("content-type", "")
                if response.status_code in {200, 206} and (
                    content_type.startswith("image/")
                    or bool(next(response.iter_content(1), b""))
                ):
                    return True
            finally:
                response.close()
        except requests.RequestException:
            continue
    return False


def _in_ranges(resource_id: int, ranges: list[list[int]]) -> bool:
    return any(start <= resource_id <= end for start, end in ranges)


def _pinned_url(commit: str, template: str, resource_id: int) -> str:
    return (
        f"https://raw.githubusercontent.com/PokeAPI/sprites/{commit}/"
        f"{template.format(id=resource_id)}"
    )


def _named_form_stem(
    species_id: int, form_key: str, species_root: str
) -> str | None:
    suffix = form_key.removeprefix(species_root).lstrip("-")
    return f"{species_id}-{suffix}" if suffix else None


def _named_path(paths: Iterable[str], stem: str | None) -> str | None:
    if stem is None:
        return None
    for value in paths:
        if Path(value).stem == stem:
            return str(value)
    return None


def _raw_pokeapi_url(commit: str, path: str) -> str:
    return (
        f"https://raw.githubusercontent.com/PokeAPI/sprites/{commit}/{path}"
    )


def _file_sha(path: Path) -> str | None:
    if not path.is_file():
        return None
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _bundle_exact_static(
    staging: Path,
    summary: dict[str, Any],
    form: dict[str, Any],
) -> bool:
    if form.get("isDefault"):
        return True
    form_path = str(form.get("localSpritePath") or "")
    species_path = str(summary.get("localSpritePath") or "")
    if not form_path:
        return False
    form_hash = _file_sha(staging / form_path)
    species_hash = _file_sha(staging / species_path) if species_path else None
    return form_hash is not None and form_hash != species_hash


def _mapping_status(keys: list[str]) -> str:
    return "exact" if len(keys) == 1 else "shared" if keys else "unresolved"


def _ensure_pokeapi_catalog_art(
    entry_art: list[dict[str, Any]],
    form_key: str,
    pokeapi: dict[str, dict[str, Any]],
) -> None:
    def add_best(asset_keys: tuple[str, ...], *, shiny: bool) -> None:
        if any(
            art.get("mappingStatus") == "exact"
            and form_key in (art.get("formKeys") or [])
            and art.get("isShiny") is shiny
            and art.get("urlVerified") is True
            for art in entry_art
        ):
            return
        selected = next(
            (
                pokeapi[key]
                for key in asset_keys
                if pokeapi.get(key, {}).get("exists")
                and pokeapi.get(key, {}).get("url")
            ),
            None,
        )
        if selected is None:
            return
        url = str(selected["url"])
        entry_art.append(
            {
                "file": url,
                "kind": "PokeAPI exact",
                "formKeys": [form_key],
                "formKey": form_key,
                "formCode": None,
                "mappingStatus": "exact",
                "url": url,
                "source": "PokeAPI",
                "license": "upstream credits; media rights vary",
                "mediaType": "static",
                "isShiny": shiny,
                "urlVerified": True,
            }
        )

    add_best(("home", "officialArtwork", "default"), shiny=False)
    add_best(
        ("homeShiny", "officialArtworkShiny", "defaultShiny"), shiny=True
    )


def build_audit(args: argparse.Namespace) -> dict[str, Any]:
    catalog: dict[str, dict[str, Any]] = json.loads(
        args.catalog.read_text(encoding="utf-8")
    )
    existence = json.loads(args.existence.read_text(encoding="utf-8"))
    commit = str(existence["sourceCommit"])
    details: dict[int, dict[str, Any]] = {}
    for path in sorted(args.details_dir.glob("*.json")):
        detail = json.loads(path.read_text(encoding="utf-8"))
        details[int(detail["summary"]["id"])] = detail

    wiki_files = {
        str(art["file"])
        for entry in catalog.values()
        for art in entry.get("forms") or []
        if not str(art.get("file") or "").startswith("http")
    }
    if args.discover_home:
        for species_id, detail in details.items():
            summary = detail["summary"]
            forms = detail.get("forms") or [
                {
                    "key": _slug(str(summary.get("nameEn") or "")),
                    "isDefault": True,
                }
            ]
            species_root = _species_root(str(summary.get("nameEn") or ""), forms)
            for form in forms:
                for code in form_codes(species_id, form, species_root):
                    wiki_files.add(f"HOME_{species_id:03d}{code}.png")
    imageinfo: dict[str, dict[str, Any]] = {}
    if args.resolve_52poke:
        session = requests.Session()
        session.headers.update({"User-Agent": USER_AGENT})
        imageinfo = resolve_imageinfo(session, sorted(wiki_files))

    if args.discover_home:
        existing = {
            str(art.get("file") or "")
            for entry in catalog.values()
            for art in entry.get("forms") or []
        }
        for file_name in sorted(imageinfo):
            match = re.fullmatch(r"HOME_0*([0-9]+)[A-Za-z]*\.png", file_name)
            if not match or file_name in existing:
                continue
            species_id = int(match.group(1))
            detail = details.get(species_id)
            if not detail:
                continue
            summary = detail["summary"]
            entry = catalog.setdefault(
                str(species_id),
                {
                    "id": species_id,
                    "nameZh": summary.get("nameZh") or f"#{species_id}",
                    "cries": [],
                    "forms": [],
                    "source": "52poke imageinfo discovery",
                },
            )
            entry.setdefault("forms", []).append({"file": file_name, "kind": "HOME"})
            existing.add(file_name)

    verified: dict[str, bool] = {}
    if args.verify_urls:
        urls = [
            str(info["url"])
            for info in imageinfo.values()
            if info.get("url")
        ]
        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            futures = {executor.submit(verify_url, url): url for url in urls}
            for done, future in enumerate(as_completed(futures), 1):
                url = futures[future]
                verified[url] = bool(future.result())
                if done % 100 == 0 or done == len(futures):
                    print(f"verified 52poke files {done}/{len(futures)}", flush=True)

    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    for species_id, detail in details.items():
        entry = catalog.get(str(species_id))
        if not entry:
            continue
        summary = detail["summary"]
        forms = detail.get("forms") or [
            {
                "key": _slug(str(summary.get("nameEn") or "")),
                "isDefault": True,
            }
        ]
        for art in entry.get("forms") or []:
            file_name = str(art.get("file") or "")
            if (
                file_name.startswith("http")
                and art.get("source") == "PokeAPI"
                and art.get("formKeys")
            ):
                keys = [str(key) for key in art["formKeys"]]
                code = art.get("formCode")
            else:
                keys, code = map_form_keys(
                    file_name,
                    species_id,
                    str(summary.get("nameEn") or ""),
                    forms,
                )
            previous_url = art.get("url")
            info = imageinfo.get(file_name) or art.get("imageInfo") or {}
            direct_url = (
                file_name
                if file_name.startswith("http")
                else info.get("url") or previous_url
            )
            source = "PokeAPI" if file_name.startswith("http") else "52poke"
            is_shiny = bool(art.get("isShiny")) or (
                source == "PokeAPI" and "/shiny/" in file_name
            )
            art.update(
                {
                    "formKeys": keys,
                    "formKey": keys[0] if len(keys) == 1 else None,
                    "formCode": code,
                    "mappingStatus": "auxiliary"
                    if (species_id, file_name) in _AUXILIARY_FILES
                    else _mapping_status(keys),
                    "url": direct_url,
                    "source": source,
                    "license": "upstream credits; media rights vary"
                    if source == "PokeAPI"
                    else WIKI_MEDIA_RIGHTS,
                    "mediaType": "static",
                    "isShiny": is_shiny,
                }
            )
            if info:
                art["imageInfo"] = info
            if direct_url:
                art["urlVerified"] = True if source == "PokeAPI" else (
                    verified.get(str(direct_url), False)
                    if args.verify_urls
                    else bool(art.get("urlVerified")) and direct_url == previous_url
                )
        species_root = _species_root(str(summary.get("nameEn") or ""), forms)
        for cry in entry.get("cries") or []:
            title = str(cry.get("title") or "")
            match = re.match(r"^\d+([^_]*)_cry\.", title)
            code = match.group(1) if match else ""
            keys = [
                str(form["key"])
                for form in forms
                if code in form_codes(species_id, form, species_root)
            ]
            cry.update(
                {
                    "formKeys": keys,
                    "formKey": keys[0] if len(keys) == 1 else None,
                    "formCode": code,
                    "mappingStatus": _mapping_status(keys),
                    "isFormSpecific": bool(code),
                    "fallbackForAllForms": not bool(code),
                    "source": "PokeAPI" if "raw.githubusercontent.com" in str(cry.get("url")) else "52poke",
                }
            )
        entry["schemaVersion"] = 2
        entry["mappedAt"] = generated_at

    media_assets = existence.get("mediaAssets") or {}
    audit_forms: list[dict[str, Any]] = []
    for species_id, detail in sorted(details.items()):
        summary = detail["summary"]
        detail_forms = detail.get("forms") or []
        species_root = _species_root(
            str(summary.get("nameEn") or ""), detail_forms
        )
        entry = catalog.get(str(species_id), {})
        entry_art = entry.setdefault("forms", [])
        entry_cries = entry.get("cries") or []
        for form in detail_forms:
            form_key = str(form["key"])
            media_id = int(form.get("pokemonId") or species_id)
            exact_id = bool(form.get("isDefault")) or media_id != species_id
            named_stem = _named_form_stem(species_id, form_key, species_root)
            pokeapi: dict[str, Any] = {}
            for asset, payload in media_assets.items():
                named_path = _named_path(
                    payload.get("namedPaths") or [], named_stem
                )
                numeric_exists = exact_id and _in_ranges(
                    media_id, payload.get("ranges") or []
                )
                exists = numeric_exists or named_path is not None
                pokeapi[asset] = {
                    "exists": exists,
                    "url": _raw_pokeapi_url(commit, named_path)
                    if named_path is not None
                    else _pinned_url(commit, payload["pathTemplate"], media_id)
                    if numeric_exists
                    else None,
                }
            if not form.get("isDefault"):
                _ensure_pokeapi_catalog_art(entry_art, form_key, pokeapi)
            versions = []
            for version, payload in existence.get("versionGroups", {}).items():
                fields = {
                    "front": ("frontRanges", "namedFront"),
                    "frontShiny": ("shinyFrontRanges", "namedShinyFront"),
                    "back": ("backRanges", "namedBack"),
                    "backShiny": ("shinyBackRanges", "namedShinyBack"),
                    "animated": ("animatedFrontRanges", "namedAnimatedFront"),
                    "animatedShiny": (
                        "animatedShinyFrontRanges",
                        "namedAnimatedShinyFront",
                    ),
                }
                availability: dict[str, bool] = {}
                urls: dict[str, str] = {}
                for key, (range_key, named_key) in fields.items():
                    path = _named_path(payload.get(named_key) or [], named_stem)
                    numeric_exists = exact_id and _in_ranges(
                        media_id, payload.get(range_key) or []
                    )
                    availability[key] = numeric_exists or path is not None
                    if path is not None:
                        urls[key] = _raw_pokeapi_url(commit, path)
                if any(availability.values()):
                    versions.append(
                        {"versionGroup": version, **availability, "urls": urls}
                    )
            mapped_wiki_art = [
                art for art in entry_art if form_key in (art.get("formKeys") or [])
            ]
            wiki_art = [
                art
                for art in mapped_wiki_art
                if art.get("url") and art.get("urlVerified") is True
                and (
                    art.get("mappingStatus") == "exact"
                    or species_id in INTENTIONALLY_SHARED_VISUAL_SPECIES
                )
            ]
            shared_fallback_art = [
                art
                for art in mapped_wiki_art
                if art.get("url")
                and art.get("urlVerified") is True
                and art.get("mappingStatus") == "shared"
                and species_id not in INTENTIONALLY_SHARED_VISUAL_SPECIES
            ]
            specific_cries = [
                cry
                for cry in entry_cries
                if cry.get("isFormSpecific")
                and form_key in (cry.get("formKeys") or [])
            ]
            bundle_exact = _bundle_exact_static(args.staging, summary, form)
            intentionally_shared = (
                not form.get("isDefault")
                and species_id in INTENTIONALLY_SHARED_VISUAL_SPECIES
            )
            pokeapi_static = any(
                pokeapi.get(key, {}).get("exists")
                for key in ("home", "officialArtwork", "default")
            ) or any(row.get("front") or row.get("back") for row in versions)
            pokeapi_shiny = any(
                pokeapi.get(key, {}).get("exists")
                for key in ("homeShiny", "officialArtworkShiny", "defaultShiny")
            ) or any(
                row.get("frontShiny") or row.get("backShiny")
                for row in versions
            )
            animated = bool(pokeapi.get("showdownAnimated", {}).get("exists")) or any(
                row.get("animated") for row in versions
            )
            animated_shiny = bool(
                pokeapi.get("showdownAnimatedShiny", {}).get("exists")
            ) or any(row.get("animatedShiny") for row in versions)
            static = (
                bundle_exact or pokeapi_static or bool(wiki_art) or intentionally_shared
            )
            audit_forms.append(
                {
                    "speciesId": species_id,
                    "pokemonId": media_id,
                    "formKey": form_key,
                    "nameZh": form.get("nameZh") or summary.get("nameZh"),
                    "formType": {
                        "isDefault": bool(form.get("isDefault")),
                        "isCosmetic": bool(form.get("isCosmetic")),
                        "isBattleOnly": bool(form.get("isBattleOnly")),
                        "isMega": bool(form.get("isMega")),
                    },
                    "bundleExactStatic": bundle_exact,
                    "intentionallySharedStatic": intentionally_shared,
                    "pokeapi": pokeapi,
                    "versionMedia": versions,
                    "wiki52poke": {
                        "art": wiki_art,
                        "mappedArt": mapped_wiki_art,
                        "sharedFallbackArt": shared_fallback_art,
                        "cries": specific_cries,
                    },
                    "coverage": {
                        "static": static,
                        "shinyStatic": pokeapi_shiny,
                        "animated": animated,
                        "shinyAnimated": animated_shiny,
                        "cry": bool(entry_cries),
                        "formSpecificCry": bool(specific_cries),
                    },
                    "selected": {
                        "staticSource": "bundle"
                        if bundle_exact
                        else "PokeAPI"
                        if pokeapi_static
                        else "52poke"
                        if wiki_art
                        else "shared fallback"
                        if shared_fallback_art
                        else None,
                        "crySource": specific_cries[0].get("source")
                        if specific_cries
                        else entry_cries[0].get("source")
                        if entry_cries
                        else None,
                    },
                    "attribution": [
                        "PokeAPI/sprites (upstream credits; media rights vary)",
                        *(
                            [f"52Poké Wiki ({WIKI_MEDIA_RIGHTS})"]
                            if wiki_art or specific_cries
                            else []
                        ),
                    ],
                }
            )

    alternates = [row for row in audit_forms if not row["formType"]["isDefault"]]
    coverage_keys = (
        "static",
        "shinyStatic",
        "animated",
        "shinyAnimated",
        "cry",
        "formSpecificCry",
    )
    summary_counts = {
        key: sum(bool(row["coverage"][key]) for row in alternates)
        for key in coverage_keys
    }
    for entry in catalog.values():
        deduplicated: dict[tuple[Any, ...], dict[str, Any]] = {}
        for art in entry.get("forms") or []:
            key = (
                str(art.get("url") or art.get("file") or ""),
                tuple(art.get("formKeys") or []),
                bool(art.get("isShiny")),
                str(art.get("mappingStatus") or ""),
            )
            deduplicated.setdefault(key, art)
        entry["forms"] = list(deduplicated.values())

    unresolved_art = [
        {"speciesId": int(entry["id"]), "file": art.get("file")}
        for entry in catalog.values()
        for art in entry.get("forms") or []
        if art.get("mappingStatus") == "unresolved"
    ]
    all_catalog_art = [
        art for entry in catalog.values() for art in entry.get("forms") or []
    ]
    wiki_catalog_art = [
        art for art in all_catalog_art if art.get("source") == "52poke"
    ]
    pokeapi_catalog_art = [
        art for art in all_catalog_art if art.get("source") == "PokeAPI"
    ]
    downloadable_art = [
        art for art in all_catalog_art if art.get("url") and art.get("urlVerified")
    ]
    verified_wiki_urls = {
        str(art["url"])
        for art in all_catalog_art
        if art.get("source") == "52poke"
        and art.get("url")
        and art.get("urlVerified") is True
    }
    failed_wiki_urls = {
        str(art["url"])
        for art in all_catalog_art
        if art.get("source") == "52poke"
        and art.get("url")
        and art.get("urlVerified") is False
    }
    payload = {
        "schemaVersion": 1,
        "generatedAt": generated_at,
        "sourceCommit": commit,
        "summary": {
            "species": len(details),
            "formRecords": len(audit_forms),
            "alternateForms": len(alternates),
            "alternateCoverage": summary_counts,
            "unresolved52pokeArt": len(unresolved_art),
            "mapped52pokeArt": sum(
                bool(art.get("formKeys")) for art in wiki_catalog_art
            ),
            "downloadable52pokeArt": sum(
                bool(art.get("url") and art.get("urlVerified"))
                for art in wiki_catalog_art
            ),
            "mappedPokeapiArt": sum(
                bool(art.get("formKeys")) for art in pokeapi_catalog_art
            ),
            "downloadableCatalogArt": len(downloadable_art),
            "unavailable52pokeArt": sum(
                not art.get("url") for art in wiki_catalog_art
            ),
            "verified52pokeFiles": len(verified_wiki_urls),
            "failed52pokeFiles": len(failed_wiki_urls),
        },
        "gaps": {
            key: [row["formKey"] for row in alternates if not row["coverage"][key]]
            for key in coverage_keys
        },
        "unresolved52pokeArt": unresolved_art,
        "forms": audit_forms,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    args.catalog.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--details-dir", type=Path, default=DEFAULT_DETAILS)
    parser.add_argument("--staging", type=Path, default=DEFAULT_STAGING)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--existence", type=Path, default=DEFAULT_EXISTENCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--resolve-52poke", action="store_true")
    parser.add_argument("--discover-home", action="store_true")
    parser.add_argument("--verify-urls", action="store_true")
    parser.add_argument("--workers", type=int, default=8)
    args = parser.parse_args()
    payload = build_audit(args)
    print(json.dumps(payload["summary"], ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
