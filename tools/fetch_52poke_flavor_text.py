#!/usr/bin/env python3
"""Fetch zh-Hans Pokedex flavor text from 52poke wiki (best-effort).

For each target species id, resolves the wiki page title from the maintained
zh species catalog, parses the ``{{图鉴}}`` template fields (``golddex``,
``dpptdex``, ``scdex``, ...), and writes ``data/l10n/zh/flavor_text_52poke.json``.
The patch tool ``patch_dex_bundle_v15_flavor_text.py`` consumes that file.

52poke may block automated requests (Cloudflare). Failures are logged and the
species is left out of the output so a later run can retry it.
"""

from __future__ import annotations

import argparse
import json
import re
import time
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests
from opencc import OpenCC

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LABELS = ROOT / "flutter" / "assets" / "l10n" / "zh" / "species_labels.json"
DEFAULT_OUTPUT = ROOT / "data" / "l10n" / "zh" / "flavor_text_52poke.json"
DEFAULT_BUNDLE = ROOT / "dist" / "dex-audit" / "extracted"

WIKI_BASE = "https://wiki.52poke.com"
USER_AGENT = "TitoDex-maintainer/1.0 (+https://github.com/Tito-XD/tito-dex)"
DEFAULT_DELAY = 1.2
RETRIES = 3

ZH_HANS_CONVERTER = OpenCC("t2s")

# 52poke {{图鉴}} template field -> bundle flavor version slugs
# (matching GAME_EDITIONS flavor_versions in build_dex_bundle.py).
FIELD_VERSIONS: dict[str, tuple[str, ...]] = {
    "reddex": ("red",),
    "bluedex": ("blue",),
    "yellowdex": ("yellow",),
    "golddex": ("gold",),
    "silverdex": ("silver",),
    "crystaldex": ("crystal",),
    "rsedex": ("ruby", "sapphire"),
    "emeralddex": ("emerald",),
    "firereddex": ("firered",),
    "leafgreendex": ("leafgreen",),
    "dpptdex": ("diamond", "pearl", "platinum"),
    "heartgolddex": ("heartgold",),
    "soulsilverdex": ("soulsilver",),
    "bwdex": ("black", "white"),
    "b2w2dex": ("black-2", "white-2"),
    "xdex": ("x",),
    "ydex": ("y",),
    "orasdex": ("omega-ruby", "alpha-sapphire"),
    "sundex": ("sun",),
    "moondex": ("moon",),
    "ultrasundex": ("ultra-sun",),
    "ultramoondex": ("ultra-moon",),
    "usumdex": ("ultra-sun", "ultra-moon"),
    "lgpedex": ("lets-go-pikachu", "lets-go-eevee"),
    "swdex": ("sword",),
    "shdex": ("shield",),
    "swshdex": ("sword", "shield"),
    "bdspdex": ("brilliant-diamond", "shining-pearl"),
    "ladex": ("legends-arceus",),
    "pladex": ("legends-arceus",),
    "scdex": ("scarlet",),
    "videx": ("violet",),
    "zadex": ("legends-za", "mega-dimension"),
}

CJK_RE = re.compile(r"[\u4e00-\u9fff]")
ZH_HANS_BLOCK = re.compile(
    r"-{zh-hans:(.*?);zh-hant:(.*?)}-", re.DOTALL
)
DEAR_BLOCK = re.compile(r"\{\{(?:图鉴|圖鑑)\s*(.*?)\n\}\}", re.DOTALL)


def normalize(text: str) -> str:
    return " ".join(text.replace("\n", " ").replace("\f", " ").split())


def extract_zh_hans(value: str) -> str | None:
    match = ZH_HANS_BLOCK.search(value)
    if match:
        text = match.group(1).strip()
    else:
        text = value.strip()
    if not text:
        return None
    if "{{" in text or "}}" in text:
        return None
    return normalize(text)


def parse_dedex_block(wikitext: str) -> dict[str, str]:
    block = DEAR_BLOCK.search(wikitext)
    if not block:
        return {}
    fields: dict[str, str] = {}
    for line in block.group(1).splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        body = line[1:]
        if "=" not in body:
            continue
        key, _, value = body.partition("=")
        key = key.strip().lower()
        if key in FIELD_VERSIONS:
            fields[key] = value.strip()
    return fields


def flavors_from_wikitext(wikitext: str) -> dict[str, str]:
    fields = parse_dedex_block(wikitext)
    versions: dict[str, str] = {}
    for field, text in fields.items():
        zh = extract_zh_hans(text)
        if not zh:
            continue
        if not CJK_RE.search(zh):
            zh = normalize(ZH_HANS_CONVERTER.convert(zh))
        for version in FIELD_VERSIONS[field]:
            versions.setdefault(version, zh)
    return versions


def opensearch_titles(session: requests.Session, query: str) -> list[str]:
    params = {
        "action": "opensearch",
        "search": query,
        "limit": 3,
        "namespace": 0,
        "format": "json",
    }
    response = session.get(
        f"{WIKI_BASE}/api.php?{urllib.parse.urlencode(params)}", timeout=30
    )
    if response.status_code != 200:
        return []
    try:
        titles = response.json()[1]
    except (ValueError, IndexError):
        return []
    return titles


def candidate_titles(session: requests.Session, query: str) -> list[str]:
    candidates: list[str] = []
    for variant in (query, ZH_HANS_CONVERTER.convert(query)):
        candidates.append(variant)
        candidates.extend(opensearch_titles(session, variant))
    seen: set[str] = set()
    unique: list[str] = []
    for title in candidates:
        if title and title not in seen:
            seen.add(title)
            unique.append(title)
    return unique


def fetch_wikitext(session: requests.Session, title: str) -> str | None:
    params = {
        "action": "parse",
        "page": title,
        "prop": "wikitext",
        "format": "json",
        "formatversion": 2,
        "redirects": 1,
    }
    url = f"{WIKI_BASE}/api.php?{urllib.parse.urlencode(params)}"
    response = None
    for attempt in range(RETRIES):
        try:
            response = session.get(url, timeout=30)
            break
        except requests.RequestException:
            if attempt == RETRIES - 1:
                return None
            time.sleep(2 * (attempt + 1))
    if response is None:
        return None
    if response.status_code != 200:
        return None
    try:
        return response.json()["parse"]["wikitext"]
    except (ValueError, KeyError):
        return None


def fetch_dedex_wikitext(session: requests.Session, query: str) -> str | None:
    for title in candidate_titles(session, query):
        wikitext = fetch_wikitext(session, title)
        if wikitext is not None and (
            "{{图鉴" in wikitext or "{{圖鑑" in wikitext
        ):
            return wikitext
    return None


def compute_missing_ids(bundle_dir: Path) -> list[int]:
    """Species with no zh-Hans flavor entry at all."""
    missing: list[int] = []
    for path in sorted(bundle_dir.glob("details/*.json")):
        detail = json.loads(path.read_text(encoding="utf-8"))
        species_id = int(detail.get("summary", {}).get("id") or path.stem)
        flavor = detail.get("flavorEntries") or []
        if not any(CJK_RE.search(entry.get("text", "")) for entry in flavor):
            missing.append(species_id)
    return missing


def compute_non_cjk_ids(bundle_dir: Path) -> list[int]:
    """Species with at least one flavor entry lacking zh-Hans text."""
    ids: list[int] = []
    for path in sorted(bundle_dir.glob("details/*.json")):
        detail = json.loads(path.read_text(encoding="utf-8"))
        species_id = int(detail.get("summary", {}).get("id") or path.stem)
        flavor = detail.get("flavorEntries") or []
        if any(not CJK_RE.search(entry.get("text", "")) for entry in flavor):
            ids.append(species_id)
    return ids


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fetch zh-Hans dex flavor text from 52poke wiki"
    )
    parser.add_argument("--ids", type=str, default="")
    parser.add_argument(
        "--all-missing",
        action="store_true",
        help="Compute species without any zh flavor entry from --bundle-dir",
    )
    parser.add_argument(
        "--all-non-cjk",
        action="store_true",
        help="Compute species with at least one non-zh flavor entry from --bundle-dir",
    )
    parser.add_argument("--bundle-dir", type=Path, default=DEFAULT_BUNDLE)
    parser.add_argument("--labels", type=Path, default=DEFAULT_LABELS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--delay", type=float, default=DEFAULT_DELAY)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    labels = json.loads(args.labels.read_text(encoding="utf-8"))
    if args.ids:
        target_ids = [int(x) for x in args.ids.split(",") if x.strip()]
    elif args.all_non_cjk:
        target_ids = compute_non_cjk_ids(args.bundle_dir)
    else:
        target_ids = compute_missing_ids(args.bundle_dir)

    existing: dict[str, Any] = {}
    if args.output.is_file():
        existing = json.loads(args.output.read_text(encoding="utf-8"))
    entries = {str(item["id"]): item for item in existing.get("entries", [])}

    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": USER_AGENT,
            "Accept-Language": "zh-CN,zh;q=0.9",
        }
    )

    fetched: list[int] = []
    failed: list[int] = []
    for species_id in target_ids:
        try:
            key = str(species_id)
            if key in entries and not args.force:
                continue
            meta = labels.get(key)
            if not meta or not meta.get("zh"):
                failed.append(species_id)
                continue
            wikitext = fetch_dedex_wikitext(session, meta["zh"])
            if wikitext is None:
                failed.append(species_id)
                print(f"failed {species_id:4d} {meta['zh']}", flush=True)
                continue
            versions = flavors_from_wikitext(wikitext)
            if versions:
                entries[key] = {
                    "id": species_id,
                    "nameZh": meta["zh"],
                    "versions": dict(sorted(versions.items())),
                    "fetchedAt": datetime.now(timezone.utc)
                    .replace(microsecond=0)
                    .isoformat(),
                }
                fetched.append(species_id)
                print(
                    f"ok {species_id:4d} {meta['zh']}: "
                    f"{len(versions)} version(s)",
                    flush=True,
                )
            else:
                if args.force:
                    entries.pop(key, None)
                failed.append(species_id)
                print(f"no-flavor {species_id:4d} {meta['zh']}", flush=True)
            time.sleep(args.delay)
        except requests.RequestException as exc:
            failed.append(species_id)
            print(f"error {species_id:4d}: {exc}", flush=True)
        finally:
            payload = {
                "schemaVersion": 1,
                "source": {
                    "name": "52poke wiki",
                    "url": WIKI_BASE,
                    "license": "CC BY-NC-SA 3.0",
                    "note": "Flavor text for versions missing zh-Hans in PokeAPI",
                },
                "fetchedAt": datetime.now(timezone.utc)
                .replace(microsecond=0)
                .isoformat(),
                "entries": sorted(entries.values(), key=lambda item: item["id"]),
            }
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

    payload = {
        "schemaVersion": 1,
        "source": {
            "name": "52poke wiki",
            "url": WIKI_BASE,
            "license": "CC BY-NC-SA 3.0",
            "note": "Flavor text for versions missing zh-Hans in PokeAPI",
        },
        "fetchedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "entries": sorted(entries.values(), key=lambda item: item["id"]),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"done: {len(fetched)} fetched, {len(failed)} failed, "
        f"{len(entries)} total entries -> {args.output}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
