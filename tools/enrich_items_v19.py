#!/usr/bin/env python3
"""Refresh TitoDex item names, zh-Hans descriptions, and bundled icons.

Priority is deliberately deterministic:

1. PokeAPI supplies current zh-Hans names/descriptions when an item endpoint
   exists.
2. 52poke fills missing text and supplies newer bag artwork. The original
   image file is downloaded into ``data/assets/item-sprites``; a 52poke image
   only replaces an existing icon when its pixel area is larger.

The script never publishes. It writes a reviewable enrichment snapshot that
``patch_dex_bundle_v19_items.py`` applies to the local v18 bundle.
"""

from __future__ import annotations

import argparse
import json
import re
import struct
import threading
import time
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

from wiki52poke_client import Wiki52PokeClient

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ITEMS = ROOT / "dist" / "dex-v18" / "staging" / "items.json"
DEFAULT_OUTPUT = ROOT / "data" / "l10n" / "zh" / "items_v19_enrichment.json"
DEFAULT_SPRITES = ROOT / "data" / "assets" / "item-sprites"
DEFAULT_CACHE = ROOT / "tools" / ".icon_cache" / "52poke-pages"
DEFAULT_NAME_OVERRIDES = (
    ROOT / "data" / "l10n" / "zh" / "item_name_overrides_v19.json"
)
DEFAULT_POKEAPI_ENRICHMENT = (
    ROOT / "data" / "l10n" / "zh" / "items_v19_pokeapi_enrichment.json"
)

POKEAPI_BASE = "https://pokeapi.co/api/v2/item"
WIKI_FILE = "https://wiki.52poke.com/wiki/Special:FilePath"
USER_AGENT = "TitoDex-maintainer/1.0 (+https://github.com/Tito-XD/tito-dex)"
CDN_ITEM_SPRITES = "https://dex.tito.cafe/v5/item-sprites"

CJK_RE = re.compile(r"[\u3400-\u9fff]")
SPRITE_FIELD_RE = re.compile(
    r"^\|sprite\d*\s*=\s*([^|\n{}]+?\.png)", re.I | re.M
)
ZH_HANS_RE = re.compile(r"-\{zh-hans:(.*?);zh-hant:", re.I)
BAG_INFO_RE = re.compile(r"\{\{包包信息框\|([^\n]+)")
GAME_PRIORITY = {
    "ZA": 100,
    "SV": 90,
    "LA": 80,
    "BDSP": 70,
    "SWSH": 60,
    "USUM": 50,
    "SM": 45,
    "ORAS": 40,
    "XY": 35,
    "B2W2": 30,
    "BW": 25,
    "HGSS": 20,
    "DPPt": 15,
    "FRLG": 12,
    "E": 11,
    "RSE": 10,
    "GSC": 5,
    "RBY": 1,
}

_thread_local = threading.local()
_wiki_client = Wiki52PokeClient(cache_dir=DEFAULT_CACHE / "revisions")


def session() -> requests.Session:
    cached = getattr(_thread_local, "session", None)
    if cached is None:
        cached = requests.Session()
        cached.headers.update(
            {"User-Agent": USER_AGENT, "Accept-Language": "zh-CN,zh;q=0.9"}
        )
        _thread_local.session = cached
    return cached


def normalize(text: str | None) -> str:
    return " ".join((text or "").replace("\n", " ").replace("\f", " ").split())


def latest_zh(entries: list[dict[str, Any]], field: str) -> str:
    values = [
        normalize(entry.get(field))
        for entry in entries
        if (entry.get("language") or {}).get("name", "").lower() == "zh-hans"
    ]
    return next((value for value in reversed(values) if value), "")


def fetch_pokeapi(item: dict[str, Any]) -> dict[str, str]:
    slug = item.get("slug") or ""
    if not slug:
        return {}
    try:
        response = session().get(f"{POKEAPI_BASE}/{slug}", timeout=25)
        if response.status_code != 200:
            return {}
        payload = response.json()
    except (requests.RequestException, ValueError):
        return {}
    return {
        "nameZh": latest_zh(payload.get("names") or [], "name"),
        "descriptionZh": latest_zh(
            payload.get("flavor_text_entries") or [], "text"
        ),
    }


def cache_path(cache_dir: Path, title: str) -> Path:
    safe = re.sub(r"[^0-9A-Za-z\u3400-\u9fff._-]+", "_", title).strip("_")
    return cache_dir / f"{safe[:120]}.txt"


def fetch_wikitext(title: str, cache_dir: Path) -> str | None:
    cached = cache_path(cache_dir, title)
    if cached.is_file():
        return cached.read_text(encoding="utf-8")
    try:
        revision = _wiki_client.latest_revision(title)
    except (requests.RequestException, RuntimeError, ValueError):
        revision = None
    text = revision.content if revision is not None else None
    if not text:
        return None
    cached.parent.mkdir(parents=True, exist_ok=True)
    cached.write_text(text, encoding="utf-8")
    return text


def search_wiki_title(name_zh: str) -> list[str]:
    try:
        titles = _wiki_client.search_titles(f'"{name_zh}" 道具', limit=4)
    except (requests.RequestException, RuntimeError, ValueError):
        return []
    return [title for title in titles if "道具" in title]


def wiki_description(wikitext: str) -> str:
    descriptions: list[tuple[int, str]] = []
    for line in wikitext.splitlines():
        stripped = line.strip()
        if not stripped.startswith("{{包包信息框|"):
            continue
        match = ZH_HANS_RE.search(line)
        if match:
            raw_value = match.group(1)
        else:
            fields = stripped.split("|", 5)
            if len(fields) < 6 or not fields[1].strip().isdigit():
                continue
            raw_value = re.sub(r"\}\}\s*$", "", fields[5])
        raw_value = re.sub(r"(?:\|\d*)+$", "", raw_value)
        value = _plain_wikitext(raw_value)
        if value and value not in {"未知", "暂无", "—"}:
            fields = stripped.split("|")
            game = fields[2].strip() if len(fields) > 2 else ""
            generation = int(fields[1]) if len(fields) > 1 and fields[1].isdigit() else 0
            descriptions.append((GAME_PRIORITY.get(game, generation), value))
    return max(descriptions, key=lambda pair: pair[0])[1] if descriptions else ""


def _plain_wikitext(value: str) -> str:
    text = re.sub(r"<br\s*/?>", " ", value, flags=re.I)
    text = re.sub(r"\[\[[^\]|]+\|([^\]]+)\]\]", r"\1", text)
    text = re.sub(r"\[\[([^\]]+)\]\]", r"\1", text)
    # Common inline templates put the user-visible Chinese token last for
    # status/type icons and first for tooltip/name helpers.
    text = re.sub(r"\{\{(?:s|i|t)\|([^{}|]+)\}\}", r"\1", text, flags=re.I)
    text = re.sub(
        r"\{\{(?:tt|N)\|([^{}|]+)(?:\|[^{}]*)?\}\}",
        r"\1",
        text,
        flags=re.I,
    )
    text = re.sub(r"'{2,}", "", text)
    return normalize(text)


def wiki_sprite_candidates(wikitext: str) -> list[str]:
    candidates: list[tuple[int, str]] = []
    for index, match in enumerate(SPRITE_FIELD_RE.finditer(wikitext)):
        candidates.append((20 - index, normalize(match.group(1))))
    for match in BAG_INFO_RE.finditer(wikitext):
        fields = [part.strip() for part in match.group(1).split("|")]
        if len(fields) < 4:
            continue
        game = fields[1]
        image_stem = fields[2]
        if (
            not image_stem
            or image_stem in {"未知", "无", "None"}
            or image_stem.startswith(("无 ", "未知 "))
        ):
            continue
        candidates.append(
            (GAME_PRIORITY.get(game, 0) + 100, f"Bag {image_stem} Sprite.png")
        )
    seen: set[str] = set()
    ordered: list[str] = []
    for _, filename in sorted(candidates, key=lambda pair: pair[0], reverse=True):
        filename = filename.replace("{{!}}30px", "").strip()
        if filename and filename not in seen:
            seen.add(filename)
            ordered.append(filename)
    return ordered


def png_dimensions(data: bytes) -> tuple[int, int] | None:
    if len(data) < 24 or not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return None
    return struct.unpack(">II", data[16:24])


def local_png_dimensions(path: Path) -> tuple[int, int] | None:
    try:
        return png_dimensions(path.read_bytes()[:24])
    except OSError:
        return None


def download_best_sprite(
    candidates: list[str], target: Path
) -> tuple[str, tuple[int, int]] | None:
    current = local_png_dimensions(target)
    current_area = (current[0] * current[1]) if current else 0
    best: tuple[str, str, tuple[int, int]] | None = None
    for filename in candidates:
        params = {
            "action": "query",
            "titles": f"File:{filename}",
            "prop": "imageinfo",
            "iiprop": "url|size|mime",
            "format": "json",
            "formatversion": 2,
        }
        try:
            payload = _wiki_client.query(params)
        except (requests.RequestException, RuntimeError, ValueError):
            payload = None
        pages = payload.get("query", {}).get("pages", []) if payload else []
        info = (pages[0].get("imageinfo") or [None])[0] if pages else None
        if not info or info.get("mime") != "image/png" or not info.get("url"):
            continue
        dimensions = (int(info.get("width") or 0), int(info.get("height") or 0))
        if min(dimensions) <= 0:
            continue
        if (
            best is None
            or dimensions[0] * dimensions[1] > best[2][0] * best[2][1]
        ):
            best = (filename, info["url"], dimensions)
        # Candidates are newest-first; a clear 128px+ original is sufficient.
        if dimensions[0] >= 128 or dimensions[1] >= 128:
            break
    if best is None or best[2][0] * best[2][1] <= current_area:
        return None
    try:
        response = session().get(
            best[1],
            headers={"Referer": "https://wiki.52poke.com/"},
            timeout=35,
        )
    except requests.RequestException:
        return None
    if png_dimensions(response.content) != best[2]:
        return None
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(response.content)
    return best[0], best[2]


def wiki_title(item: dict[str, Any]) -> str | None:
    explicit = normalize(item.get("wikiTitle"))
    if explicit:
        return explicit
    name = normalize(item.get("nameZh"))
    if not name or not CJK_RE.search(name) or name in {"？？？", "???"}:
        return None
    return name if name.endswith("（道具）") else f"{name}（道具）"


def process_wiki_item(
    item: dict[str, Any], cache_dir: Path, sprites_dir: Path
) -> dict[str, Any]:
    title = wiki_title(item)
    if title is None:
        return {}
    wikitext = fetch_wikitext(title, cache_dir)
    if wikitext is None:
        name_zh = normalize(item.get("nameZh"))
        for candidate in search_wiki_title(name_zh):
            wikitext = fetch_wikitext(candidate, cache_dir)
            if wikitext is not None and "包包信息框" in wikitext:
                title = candidate
                break
    if wikitext is None:
        return {}
    slug = item.get("slug") or ""
    result: dict[str, Any] = {"wikiTitle": title}
    description = wiki_description(wikitext)
    if description:
        result["descriptionZh"] = description
    sprite = download_best_sprite(
        wiki_sprite_candidates(wikitext), sprites_dir / f"{slug}.png"
    )
    if sprite is not None:
        result["spriteFile52poke"] = sprite[0]
        result["spriteDimensions"] = list(sprite[1])
    if (sprites_dir / f"{slug}.png").is_file():
        result["spriteUrl"] = f"{CDN_ITEM_SPRITES}/{slug}.png"
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--items", type=Path, default=DEFAULT_ITEMS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--sprites-dir", type=Path, default=DEFAULT_SPRITES)
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE)
    parser.add_argument(
        "--name-overrides", type=Path, default=DEFAULT_NAME_OVERRIDES
    )
    parser.add_argument(
        "--pokeapi-enrichment", type=Path, default=DEFAULT_POKEAPI_ENRICHMENT
    )
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument(
        "--skip-pokeapi",
        action="store_true",
        help="Reuse the previous PokeAPI-first audit and only retry wiki coverage.",
    )
    parser.add_argument(
        "--skip-wiki",
        action="store_true",
        help="Refresh only PokeAPI text without re-running the wiki/icon pass.",
    )
    parser.add_argument(
        "--allow-wiki-manual",
        action="store_true",
        help=(
            "Explicitly enable the legacy 52Poké manual-review pass. Do not use "
            "for v20 bulk import or without permission matching source_registry.json."
        ),
    )
    parser.add_argument(
        "--slugs",
        nargs="*",
        help="Optional focused run; default refreshes the complete item catalog.",
    )
    parser.add_argument(
        "--slugs-file",
        type=Path,
        help="Optional newline/TSV file whose first field is a focused slug.",
    )
    parser.add_argument(
        "--merge-output",
        action="store_true",
        help="Merge a focused run into an existing enrichment snapshot.",
    )
    args = parser.parse_args()

    items_by_id: dict[str, dict[str, Any]] = json.loads(
        args.items.read_text(encoding="utf-8")
    )
    items = list(items_by_id.values())
    if args.pokeapi_enrichment.is_file():
        pokeapi_snapshot = json.loads(
            args.pokeapi_enrichment.read_text(encoding="utf-8")
        )
        by_slug = pokeapi_snapshot.get("itemsBySlug") or {}
        for item in items:
            name_zh = (by_slug.get(item.get("slug")) or {}).get("nameZh")
            if name_zh and CJK_RE.search(normalize(name_zh)):
                item["nameZh"] = name_zh
    if args.name_overrides.is_file():
        overrides = json.loads(args.name_overrides.read_text(encoding="utf-8"))
        for item in items:
            patch = (overrides.get("itemsBySlug") or {}).get(item.get("slug"))
            if patch:
                item.update(patch)
    original_name_by_slug = {
        item.get("slug", ""): item.get("nameZh") for item in items
    }
    wanted = set(args.slugs or [])
    if args.slugs_file:
        wanted.update(
            line.split("\t", 1)[0].strip()
            for line in args.slugs_file.read_text(encoding="utf-8").splitlines()
            if line.strip()
        )
    if wanted:
        items = [item for item in items if item.get("slug") in wanted]

    # PokeAPI is queried first only where text/name is actually incomplete.
    poke_targets = [] if args.skip_pokeapi else [
        item
        for item in items
        if not (item.get("descriptionZh") or item.get("effectZh"))
        or not CJK_RE.search(normalize(item.get("nameZh")))
    ]
    poke_results: dict[str, dict[str, str]] = {}
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {executor.submit(fetch_pokeapi, item): item for item in poke_targets}
        for done, future in enumerate(as_completed(futures), 1):
            item = futures[future]
            result = future.result()
            if result:
                poke_results[item["slug"]] = result
                if result.get("nameZh"):
                    item["nameZh"] = result["nameZh"]
            if done % 100 == 0 or done == len(futures):
                print(f"PokeAPI {done}/{len(futures)}", flush=True)

    wiki_results: dict[str, dict[str, Any]] = {}
    wiki_targets = (
        items if args.allow_wiki_manual and not args.skip_wiki else []
    )
    if not args.allow_wiki_manual and not args.skip_wiki:
        print(
            "52Poké pass disabled by source policy; reusing committed v19 data.",
            flush=True,
        )
    # The legacy wiki pass is intentionally serial even when explicitly
    # enabled; 52Poké's machine-reading rules do not permit parallel access.
    with ThreadPoolExecutor(max_workers=1) as executor:
        futures = {
            executor.submit(process_wiki_item, item, args.cache_dir, args.sprites_dir): item
            for item in wiki_targets
        }
        for done, future in enumerate(as_completed(futures), 1):
            item = futures[future]
            try:
                result = future.result()
            except Exception as exc:  # noqa: BLE001
                print(f"warn {item.get('slug')}: {exc}", flush=True)
                result = {}
            if result:
                wiki_results[item["slug"]] = result
            if done % 100 == 0 or done == len(futures):
                print(f"52poke {done}/{len(futures)}", flush=True)

    enrichment: dict[str, dict[str, Any]] = {}
    for item in items:
        slug = item["slug"]
        poke = poke_results.get(slug, {})
        wiki = wiki_results.get(slug, {})
        description = (
            normalize(item.get("descriptionZh") or item.get("effectZh"))
            or normalize(poke.get("descriptionZh"))
            or normalize(wiki.get("descriptionZh"))
        )
        name_zh = normalize(poke.get("nameZh")) or normalize(item.get("nameZh"))
        sprite_url = wiki.get("spriteUrl") or item.get("spriteUrl")
        changed: dict[str, Any] = {}
        if name_zh and name_zh != original_name_by_slug.get(slug):
            changed["nameZh"] = name_zh
        if description and not (item.get("descriptionZh") or item.get("effectZh")):
            changed["descriptionZh"] = description
            changed["effectZh"] = description
            changed["descriptionSource"] = (
                "PokeAPI" if poke.get("descriptionZh") else "52poke"
            )
        if sprite_url and sprite_url != item.get("spriteUrl"):
            changed["spriteUrl"] = sprite_url
        for key in ("wikiTitle", "spriteFile52poke", "spriteDimensions"):
            if key in wiki:
                changed[key] = wiki[key]
        if changed:
            enrichment[slug] = changed

    payload = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "sources": [
            {"name": "PokeAPI", "license": "BSD-3-Clause"},
            {
                "name": "52poke original wiki text",
                "license": "CC BY-NC-SA 3.0",
            },
            {
                "name": "52poke-hosted media",
                "license": "source page attribution; underlying media rights vary",
            },
        ],
        "itemsBySlug": enrichment,
    }
    if args.merge_output and args.output.is_file():
        previous = json.loads(args.output.read_text(encoding="utf-8"))
        merged = dict(previous.get("itemsBySlug") or {})
        for slug, patch in enrichment.items():
            merged.setdefault(slug, {}).update(patch)
        payload["itemsBySlug"] = merged
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"wrote {len(enrichment)} focused / {len(payload['itemsBySlug'])} total "
        f"enriched items -> {args.output}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
