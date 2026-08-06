#!/usr/bin/env python3
"""Fetch zh-Hans wild held-item data from 52poke wiki (best-effort).

PokeAPI's ``held_items`` only covers up to Gen 7, so modern games (SwSh,
BDSP, LA, SV, Z-A, Mega Dimension) are missing from the bundle. This tool
parses the ``{{携带物品}}`` template per species and writes
``data/l10n/zh/held_items_52poke.json`` for
``patch_dex_bundle_v16_held_items.py``.

52poke may block automated requests (Cloudflare). Failures are logged and the
species is left out so a later run can retry it.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

from fetch_52poke_flavor_text import (
    DEFAULT_BUNDLE,
    DEFAULT_LABELS,
    ROOT,
    USER_AGENT,
    fetch_dedex_wikitext,
)

DEFAULT_OUTPUT = ROOT / "data" / "l10n" / "zh" / "held_items_52poke.json"
DEFAULT_DELAY = 0.7
RETRIES = 3

# 52poke {{携带物品/main}} version-group code -> bundle flavor version slugs
# (matching GAME_EDITIONS flavor_versions in build_dex_bundle.py).
GROUP_VERSIONS: dict[str, tuple[str, ...]] = {
    "GSC": ("gold", "silver", "crystal"),
    "RSE": ("ruby", "sapphire", "emerald"),
    "FRLG": ("firered", "leafgreen"),
    "DPPt": ("diamond", "pearl", "platinum"),
    "HGSS": ("heartgold", "soulsilver"),
    "DPPtHGSS": ("diamond", "pearl", "platinum", "heartgold", "soulsilver"),
    "BW": ("black", "white"),
    "B2W2": ("black-2", "white-2"),
    "BWB2W2": ("black", "white", "black-2", "white-2"),
    "XY": ("x", "y"),
    "ORAS": ("omega-ruby", "alpha-sapphire"),
    "XYORAS": ("x", "y", "omega-ruby", "alpha-sapphire"),
    "SM": ("sun", "moon"),
    "USUM": ("ultra-sun", "ultra-moon"),
    "SMUSUM": ("sun", "moon", "ultra-sun", "ultra-moon"),
    "LPLE": ("lets-go-pikachu", "lets-go-eevee"),
    "SWSH": ("sword", "shield"),
    "BDSP": ("brilliant-diamond", "shining-pearl"),
    "LA": ("legends-arceus",),
    "SV": ("scarlet", "violet"),
    "SVT": ("scarlet", "violet"),
    "ZA": ("legends-za",),
    "ZAM": ("mega-dimension",),
    "XD": ("xd",),
    "CXD": ("colosseum", "xd"),
    "Colosseum": ("colosseum",),
}

ROW_RE = re.compile(r"\{\{携带物品/main\|([^|]+)\|([^|]+)\|(.*?)\}\}", re.DOTALL)
RATE_RE = re.compile(r"rate(\d+)=([\d.]+)")


def write_payload(payload: dict[str, Any], output: Path) -> None:
    data = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    output.parent.mkdir(parents=True, exist_ok=True)
    temp = output.with_suffix(".json.tmp")
    last_error: OSError | None = None
    for _attempt in range(6):
        try:
            temp.write_text(data, encoding="utf-8")
            os.replace(temp, output)
            return
        except OSError as exc:
            last_error = exc
            time.sleep(0.5)
    raise last_error  # type: ignore[misc]


def parse_held_items(wikitext: str) -> dict[str, list[dict[str, Any]]]:
    versions: dict[str, list[dict[str, Any]]] = {}
    for match in ROW_RE.finditer(wikitext):
        _gen, group, body = match.groups()
        targets = GROUP_VERSIONS.get(group.strip())
        if not targets:
            continue
        tokens = [t.strip() for t in body.split("|") if t.strip()]
        if not tokens:
            continue
        items: list[str] = [tokens[0]]
        rates: dict[int, float] = {}
        for token in tokens[1:]:
            rate_match = RATE_RE.match(token)
            if rate_match:
                rates[int(rate_match.group(1)) - 1] = float(rate_match.group(2))
            elif "=" not in token:
                items.append(token)
        for index, item in enumerate(items):
            for version in targets:
                versions.setdefault(version, [])
                entry = {"itemZh": item}
                if index in rates:
                    entry["rate"] = rates[index]
                if entry not in versions[version]:
                    versions[version].append(entry)
    return versions


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fetch zh-Hans wild held-item data from 52poke wiki"
    )
    parser.add_argument("--ids", type=str, default="")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--bundle-dir", type=Path, default=DEFAULT_BUNDLE)
    parser.add_argument("--labels", type=Path, default=DEFAULT_LABELS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--delay", type=float, default=DEFAULT_DELAY)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    labels = json.loads(args.labels.read_text(encoding="utf-8"))
    if args.ids:
        target_ids = [int(x) for x in args.ids.split(",") if x.strip()]
    elif args.all:
        target_ids = sorted(int(k) for k in labels.keys())
    else:
        target_ids = sorted(int(k) for k in labels.keys())

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
            versions = parse_held_items(wikitext)
            if versions:
                entries[key] = {
                    "id": species_id,
                    "nameZh": meta["zh"],
                    "versions": {
                        version: items
                        for version, items in sorted(versions.items())
                    },
                    "fetchedAt": datetime.now(timezone.utc)
                    .replace(microsecond=0)
                    .isoformat(),
                }
                fetched.append(species_id)
                count = sum(len(items) for items in versions.values())
                print(
                    f"ok {species_id:4d} {meta['zh']}: "
                    f"{len(versions)} version(s), {count} entries",
                    flush=True,
                )
            else:
                if args.force:
                    entries.pop(key, None)
                failed.append(species_id)
                print(f"no-held {species_id:4d} {meta['zh']}", flush=True)
            time.sleep(args.delay)
        except requests.RequestException as exc:
            failed.append(species_id)
            print(f"error {species_id:4d}: {exc}", flush=True)
        finally:
            payload = {
                "schemaVersion": 1,
                "source": {
                    "name": "52poke wiki",
                    "url": "https://wiki.52poke.com",
                    "license": "CC BY-NC-SA 4.0",
                    "note": "Wild held items for versions missing from PokeAPI",
                },
                "fetchedAt": datetime.now(timezone.utc)
                .replace(microsecond=0)
                .isoformat(),
                "entries": sorted(entries.values(), key=lambda item: item["id"]),
            }
            args.output.parent.mkdir(parents=True, exist_ok=True)
            write_payload(payload, args.output)

    print(
        f"done: {len(fetched)} fetched, {len(failed)} failed, "
        f"{len(entries)} total entries -> {args.output}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
