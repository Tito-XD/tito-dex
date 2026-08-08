#!/usr/bin/env python3
"""Build per-game item availability and shop prices from 52poke wikitext.

52poke item pages use two stable templates:

* ``道具信息框/game`` lists the games in which an item exists.
* ``包包信息框`` carries generation/game, buy price and sell price.

The resulting compact matrix is bundled as an app asset. It deliberately
keeps availability separate from price: an item can exist in a game without
being sold in a normal shop, and an absent price must never become zero.
"""

from __future__ import annotations

import argparse
import csv
import html
import io
import json
import re
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import requests


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TITLES = ROOT / "data/l10n/zh/items_v19_enrichment.json"
DEFAULT_ITEMS = ROOT / "dist/dex-v19/upload/v5/items.json"
DEFAULT_OUTPUT = ROOT / "flutter/assets/data/item_version_matrix.json"
DEFAULT_CACHE = ROOT / "dist/item-version-wikitext-cache.json"
API = "https://wiki.52poke.com/api.php"
POKEAPI_CSV = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv"

# 52poke display-group code -> TitoDex/PokeAPI version-group keys. The wiki
# combines games when availability and bag data are identical; TitoDex keeps
# the corresponding selectable editions separate.
GAME_CODE_GROUPS: dict[str, tuple[str, ...]] = {
    "RGBY": ("red-blue", "yellow"),
    "RBY": ("red-blue", "yellow"),
    "RGB": ("red-blue",),
    "RG": ("red-blue",),
    "Y": ("yellow",),
    "GSC": ("gold-silver", "crystal"),
    "GS": ("gold-silver",),
    "C": ("crystal",),
    "RSE": ("ruby-sapphire", "emerald"),
    "RS": ("ruby-sapphire",),
    "E": ("emerald",),
    "FRLG": ("firered-leafgreen",),
    "DPPT": ("diamond-pearl", "platinum"),
    "DP": ("diamond-pearl",),
    "PT": ("platinum",),
    "HGSS": ("heartgold-soulsilver",),
    "BWB2W2": ("black-white", "black-2-white-2"),
    "BW": ("black-white",),
    "B2W2": ("black-2-white-2",),
    "XY": ("x-y",),
    "ORAS": ("omega-ruby-alpha-sapphire",),
    "SMUSUM": ("sun-moon", "ultra-sun-ultra-moon"),
    "SM": ("sun-moon",),
    "USUM": ("ultra-sun-ultra-moon",),
    "LPLE": ("lets-go-pikachu-lets-go-eevee",),
    "LGPE": ("lets-go-pikachu-lets-go-eevee",),
    "SWSH": ("sword-shield",),
    "BDSP": ("brilliant-diamond-shining-pearl",),
    "LA": ("legends-arceus",),
    "SV": ("scarlet-violet",),
    "ZA": ("legends-z-a",),
}

EXACT_FLAVOR_GROUPS: dict[str, tuple[str, str]] = {
    "D": ("diamond", "diamond-pearl"),
    "P": ("pearl", "diamond-pearl"),
    "HG": ("heartgold", "heartgold-soulsilver"),
    "SS": ("soulsilver", "heartgold-soulsilver"),
    "B": ("black", "black-white"),
    "W": ("white", "black-white"),
    "B2": ("black-2", "black-2-white-2"),
    "W2": ("white-2", "black-2-white-2"),
    "OR": ("omega-ruby", "omega-ruby-alpha-sapphire"),
    "AS": ("alpha-sapphire", "omega-ruby-alpha-sapphire"),
    "US": ("ultra-sun", "ultra-sun-ultra-moon"),
    "UM": ("ultra-moon", "ultra-sun-ultra-moon"),
    "SW": ("sword", "sword-shield"),
    "SH": ("shield", "sword-shield"),
}


def normalized_code(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9]", "", value).upper()


def groups_for_code(value: str) -> tuple[str, ...]:
    return GAME_CODE_GROUPS.get(normalized_code(value), ())


def extract_templates(text: str, prefix: str) -> Iterable[str]:
    """Yield balanced ``{{...}}`` templates whose name starts with prefix."""

    start = 0
    needle = "{{" + prefix
    while True:
        begin = text.find(needle, start)
        if begin < 0:
            return
        depth = 0
        cursor = begin
        while cursor < len(text) - 1:
            pair = text[cursor : cursor + 2]
            if pair == "{{":
                depth += 1
                cursor += 2
                continue
            if pair == "}}":
                depth -= 1
                cursor += 2
                if depth == 0:
                    yield text[begin:cursor]
                    start = cursor
                    break
                continue
            cursor += 1
        else:
            return


def split_template(template: str) -> list[str]:
    """Split top-level template arguments while preserving nested markup."""

    body = template[2:-2]
    parts: list[str] = []
    current: list[str] = []
    curly = square = 0
    cursor = 0
    while cursor < len(body):
        pair = body[cursor : cursor + 2]
        if pair == "{{":
            curly += 1
            current.append(pair)
            cursor += 2
            continue
        if pair == "}}" and curly:
            curly -= 1
            current.append(pair)
            cursor += 2
            continue
        if pair == "[[":
            square += 1
            current.append(pair)
            cursor += 2
            continue
        if pair == "]]" and square:
            square -= 1
            current.append(pair)
            cursor += 2
            continue
        char = body[cursor]
        if char == "|" and curly == 0 and square == 0:
            parts.append("".join(current).strip())
            current = []
        else:
            current.append(char)
        cursor += 1
    parts.append("".join(current).strip())
    return parts


def parse_price(value: str) -> int | str | None:
    cleaned = value.strip()
    if not cleaned or cleaned.lower() in {"-", "—", "&mdash;", "none"}:
        return None
    cleaned = re.sub(r"<!--.*?-->", "", cleaned).strip()
    digits = cleaned.replace(",", "").replace("，", "")
    if re.fullmatch(r"\d+", digits):
        return int(digits)
    # Multiple shop offers are commonly written as ``200／{{currency...}}``.
    # The first value is the standard Poké Mart price; keep it usable instead
    # of leaking raw wikitext into the app.
    standard_offer = re.match(r"^([\d,，]+)\s*[／/]", cleaned)
    if standard_offer:
        return int(standard_offer.group(1).replace(",", "").replace("，", ""))
    # Preserve non-money currencies / ranges visibly rather than guessing.
    cleaned = re.sub(
        r"\{\{tt\|([^|{}]+)\|([^{}]+)\}\}",
        lambda match: f"{match.group(1)}（{match.group(2)}）",
        cleaned,
    )
    cleaned = re.sub(
        r"\{\{sup/\d+\|([^{}|]+)\}\}", r"（\1）", cleaned
    )
    cleaned = re.sub(
        r"\[\[[^\]|]+\|([^\]]+)\]\]", r"\1", cleaned
    )
    cleaned = re.sub(r"\[\[([^\]]+)\]\]", r"\1", cleaned)
    # Any remaining simple wiki template is presentation metadata. Retain its
    # final visible argument, never the template source itself.
    for _ in range(4):
        updated = re.sub(
            r"\{\{[^{}]*?(?:\|([^{}|]*))?\}\}",
            lambda match: match.group(1) or "",
            cleaned,
        )
        if updated == cleaned:
            break
        cleaned = updated
    cleaned = html.unescape(cleaned).replace("—／", "／").strip()
    cleaned = re.sub(r"<[^>]+>", "", cleaned).strip()
    return cleaned or None


def parse_item_page(wikitext: str) -> dict[str, Any]:
    available: set[str] = set()
    exact_versions: set[str] = set()
    prices: dict[str, dict[str, int | str]] = {}

    for template in extract_templates(wikitext, "道具信息框/game"):
        parts = split_template(template)
        active_codes: set[str] = set()
        all_codes: set[str] = set()
        for part in parts[1:]:
            if "=" not in part:
                continue
            code, flag = part.split("=", 1)
            normalized = normalized_code(code)
            all_codes.add(normalized)
            if flag.strip().lower() in {"", "n", "no", "-", "0"}:
                continue
            active_codes.add(normalized)
            available.update(groups_for_code(normalized))
        exact = dict(EXACT_FLAVOR_GROUPS)
        # S is used for Sun when paired with M/US, and for Scarlet when V is
        # present. Resolve it from the sibling flags instead of guessing.
        if "S" in active_codes:
            exact["S"] = (
                ("scarlet", "scarlet-violet")
                if "V" in all_codes
                else ("sun", "sun-moon")
            )
        if "M" in active_codes:
            exact["M"] = ("moon", "sun-moon")
        if "V" in active_codes:
            exact["V"] = ("violet", "scarlet-violet")
        if "RU" in active_codes:
            exact["RU"] = ("ruby", "ruby-sapphire")
        if "SA" in active_codes:
            exact["SA"] = ("sapphire", "ruby-sapphire")
        for code in active_codes:
            flavor = exact.get(code)
            if flavor is not None:
                exact_versions.add(flavor[0])
                available.add(flavor[1])

    for template in extract_templates(wikitext, "包包信息框"):
        parts = split_template(template)
        if not parts or parts[0] != "包包信息框" or len(parts) < 8:
            continue
        groups = groups_for_code(parts[2])
        if not groups:
            continue
        buy = parse_price(parts[-2])
        sell = parse_price(parts[-1])
        available.update(groups)
        if buy is None and sell is None:
            continue
        record: dict[str, int | str] = {}
        if buy is not None:
            record["buy"] = buy
        if sell is not None:
            record["sell"] = sell
        for group in groups:
            prices[group] = record

    return {
        "versionGroups": sorted(available),
        **({"versions": sorted(exact_versions)} if exact_versions else {}),
        **({"prices": dict(sorted(prices.items()))} if prices else {}),
    }


def chunks(values: list[str], size: int) -> Iterable[list[str]]:
    for start in range(0, len(values), size):
        yield values[start : start + size]


def fetch_pages(
    session: requests.Session,
    titles: list[str],
    cache_path: Path,
) -> dict[str, str]:
    cache: dict[str, Any] = {"requested": [], "pages": {}}
    if cache_path.exists():
        cache = json.loads(cache_path.read_text(encoding="utf-8"))
    pages: dict[str, str] = dict(cache.get("pages") or {})
    requested = set(cache.get("requested") or [])
    pending = [title for title in titles if title not in requested]
    batches = list(chunks(pending, 25))
    for index, batch in enumerate(batches, start=1):
        payload: dict[str, Any] | None = None
        for attempt in range(4):
            try:
                response = session.post(
                    API,
                    data={
                        "action": "query",
                        "prop": "revisions",
                        "rvprop": "content",
                        "rvslots": "main",
                        "redirects": "1",
                        "format": "json",
                        "formatversion": "2",
                        "titles": "|".join(batch),
                    },
                    timeout=90,
                )
                response.raise_for_status()
                candidate = response.json()
                if candidate.get("error"):
                    raise RuntimeError(candidate["error"])
                payload = candidate
                break
            except (requests.RequestException, RuntimeError) as exc:
                if attempt == 3:
                    raise
                print(f"  retry batch {index}: {exc}", flush=True)
                time.sleep(1.5 * (attempt + 1))
        assert payload is not None
        query = payload.get("query", {})
        content_by_title: dict[str, str] = {}
        for page in query.get("pages", []):
            revisions = page.get("revisions") or []
            if not revisions:
                continue
            slot = revisions[0].get("slots", {}).get("main", {})
            content = slot.get("content")
            if content:
                content_by_title[page["title"]] = content
        aliases = {
            item["from"]: item["to"]
            for item in [
                *query.get("normalized", []),
                *query.get("redirects", []),
            ]
        }
        for title in batch:
            resolved = title
            seen: set[str] = set()
            while resolved in aliases and resolved not in seen:
                seen.add(resolved)
                resolved = aliases[resolved]
            content = content_by_title.get(resolved)
            if content:
                pages[title] = content
        requested.update(batch)
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(
            json.dumps(
                {"requested": sorted(requested), "pages": pages},
                ensure_ascii=False,
                separators=(",", ":"),
            ),
            encoding="utf-8",
        )
        print(
            f"  pages {index}/{len(batches)} "
            f"({len(requested)}/{len(titles)} requested, {len(pages)} read)",
            flush=True,
        )
        time.sleep(0.35)
    return pages


def fetch_csv(session: requests.Session, filename: str) -> list[dict[str, str]]:
    response = session.get(f"{POKEAPI_CSV}/{filename}", timeout=90)
    response.raise_for_status()
    return list(csv.DictReader(io.StringIO(response.text)))


def fetch_pokeapi_item_matrix(session: requests.Session) -> dict[str, Any]:
    version_groups = {
        row["id"]: row["identifier"]
        for row in fetch_csv(session, "version_groups.csv")
    }
    currencies = {
        row["id"]: row["identifier"]
        for row in fetch_csv(session, "currencies.csv")
    }
    result: dict[str, Any] = {}
    for row in fetch_csv(session, "item_game_indices.csv"):
        entry = result.setdefault(
            row["item_id"], {"generations": set(), "prices": {}}
        )
        entry["generations"].add(int(row["generation_id"]))
    for row in fetch_csv(session, "item_prices.csv"):
        group = version_groups.get(row["version_group_id"])
        if not group:
            continue
        entry = result.setdefault(
            row["item_id"], {"generations": set(), "prices": {}}
        )
        price: dict[str, int | str] = {}
        if row["purchase_price"]:
            price["buy"] = int(row["purchase_price"])
        if row["sell_price"]:
            price["sell"] = int(row["sell_price"])
        currency = currencies.get(row["currency_id"], "poke-dollar")
        if currency != "poke-dollar":
            price["currency"] = currency
        # A row with null purchase and zero sell still proves that the item is
        # represented in this version group (Master Ball is a common example).
        entry["prices"][group] = price
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--titles", type=Path, default=DEFAULT_TITLES)
    parser.add_argument("--items", type=Path, default=DEFAULT_ITEMS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    args = parser.parse_args()

    title_payload = json.loads(args.titles.read_text(encoding="utf-8"))
    title_by_slug = {
        slug: item["wikiTitle"]
        for slug, item in title_payload["itemsBySlug"].items()
        if item.get("wikiTitle")
    }
    items = json.loads(args.items.read_text(encoding="utf-8"))
    item_by_slug = {item["slug"]: item for item in items.values()}
    unique_titles = sorted(set(title_by_slug.values()))

    session = requests.Session()
    session.headers["User-Agent"] = (
        "TitoDex item-version builder/0.8.9 "
        "(https://github.com/tito/tito-dex; data attribution retained)"
    )
    pages = fetch_pages(session, unique_titles, args.cache)
    pokeapi = fetch_pokeapi_item_matrix(session)

    entries: dict[str, Any] = {}
    for slug, item in sorted(item_by_slug.items()):
        title = title_by_slug.get(slug)
        source = pages.get(title) if title else None
        wiki = parse_item_page(source) if source else {"versionGroups": []}
        official = pokeapi.get(str(item["id"])) or {}
        official_prices = official.get("prices") or {}
        wiki_prices = wiki.get("prices") or {}
        version_groups = sorted(
            {
                *wiki["versionGroups"],
                *official_prices.keys(),
            }
        )
        generations = sorted(official.get("generations") or [])
        prices = {**wiki_prices, **official_prices}
        if not version_groups and not generations:
            continue
        entries[str(item["id"])] = {
            "slug": slug,
            "versionGroups": version_groups,
            **({"versions": wiki["versions"]} if wiki.get("versions") else {}),
            **({"generations": generations} if generations else {}),
            **({"prices": dict(sorted(prices.items()))} if prices else {}),
        }

    payload = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "sources": [
            {
                "name": "PokeAPI",
                "url": "https://github.com/PokeAPI/pokeapi/tree/master/data/v2/csv",
                "license": "CC-BY 4.0",
            },
            {
                "name": "52poke",
                "url": "https://wiki.52poke.com",
                "license": "CC BY-NC-SA 4.0",
            },
        ],
        "coverage": {
            "catalogItems": len(items),
            "mappedTitles": len(title_by_slug),
            "pagesRead": len(pages),
            "versionedItems": sum(
                bool(item.get("versionGroups")) for item in entries.values()
            ),
            "generationIndexedItems": sum(
                bool(item.get("generations")) for item in entries.values()
            ),
            "pricedItems": sum(bool(item.get("prices")) for item in entries.values()),
        },
        "items": entries,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(payload["coverage"], ensure_ascii=False, indent=2))
    print(args.output)


if __name__ == "__main__":
    main()
