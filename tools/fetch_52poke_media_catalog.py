#!/usr/bin/env python3
"""Legacy parser for the existing audited 52Poké media catalog.

For each species, parses the rendered page for:
- cry audio elements (``<audio data-mwtitle="NNNN_cry.opus">`` with webm
  transcode URLs) — one entry per generation/form cry;
- forme/home artwork file names (``File:HOME_*``, ``NNNPikachu-*`` costumes).

Static per-generation front/back sprites are intentionally NOT included:
they are already deterministic from PokeAPI's sprites repo (front via the
existing ``sprite_generation_catalog``, back via the same version folders).

New network refreshes are disabled: TitoDex's current source registry excludes
52Poké images/audio and the site's machine-reading rules disallow the old
``action=parse`` implementation. v20 must inherit the already-audited v19
catalog unchanged unless separate written permission changes that scope.
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
    DEFAULT_LABELS,
    ROOT,
    USER_AGENT,
    candidate_titles,
)

WIKI_BASE = "https://wiki.52poke.com"
DEFAULT_OUTPUT = ROOT / "data" / "l10n" / "zh" / "media_catalog_52poke.json"
DEFAULT_DELAY = 0.5
RETRIES = 4

AUDIO_RE = re.compile(
    r"<audio[^>]+data-mwtitle=\"([^\"]+\.opus)\"[^>]*>(.*?)</audio>",
    re.DOTALL,
)
SRC_RE = re.compile(r'src="([^"]+\.webm)"')
HOME_RE = re.compile(r"File:(HOME_\d+[A-Za-z]*\.png)")
# Full-name forme art is named like ``003Venusaur-Mega.png`` and
# ``100Voltorb-Hisui.png``. The old leading-zero-only expression silently
# stopped collecting these files after National Dex #099.
FORM_ART_RE = re.compile(r"File:((?:\d{3,4})[A-Za-z][A-Za-z0-9-]*\.png)")


def fetch_rendered_html(session: requests.Session, query: str) -> str | None:
    del session, query
    raise RuntimeError(
        "52Poké media refresh is disabled by data/journey/sources/"
        "source_registry.json; reuse the audited v19 catalog"
    )


def parse_cries(html: str) -> list[dict[str, str]]:
    cries: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for match in AUDIO_RE.finditer(html):
        title = match.group(1)
        src_match = SRC_RE.search(match.group(2))
        if not src_match:
            continue
        url = src_match.group(1)
        if url.startswith("//"):
            url = f"https:{url}"
        key = (title, url)
        if key in seen:
            continue
        seen.add(key)
        cries.append({"title": title, "url": url})
    return cries


def parse_form_art(html: str) -> list[dict[str, str]]:
    forms: list[dict[str, str]] = []
    seen: set[str] = set()
    for name in HOME_RE.findall(html):
        if name not in seen:
            seen.add(name)
            forms.append({"file": name, "kind": "HOME"})
    for name in FORM_ART_RE.findall(html):
        if name in seen:
            continue
        if name.startswith("HOME_") or re.match(r"^F\d+\.png$", name):
            continue
        seen.add(name)
        forms.append({"file": name, "kind": "forme"})
    return forms


def write_payload(payload: dict[str, Any], output: Path) -> None:
    data = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    output.parent.mkdir(parents=True, exist_ok=True)
    temp = output.with_suffix(".json.tmp")
    for _attempt in range(6):
        try:
            temp.write_text(data, encoding="utf-8")
            os.replace(temp, output)
            return
        except OSError:
            time.sleep(0.5)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fetch 52poke online media catalog (cries + forme art)"
    )
    parser.add_argument("--ids", type=str, default="")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--labels", type=Path, default=DEFAULT_LABELS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--delay", type=float, default=DEFAULT_DELAY)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    parser.error(
        "52Poké media refresh is disabled; v20 must reuse the audited v19 "
        "media catalog unless separate written permission is recorded"
    )

    labels = json.loads(args.labels.read_text(encoding="utf-8"))
    if args.ids:
        target_ids = [int(x) for x in args.ids.split(",") if x.strip()]
    else:
        target_ids = sorted(int(k) for k in labels.keys())

    entries: dict[str, Any] = {}
    # Focused refreshes must preserve every non-target species already in the
    # catalog. ``--force`` means replace the requested ids, not discard the
    # complete existing file.
    if args.output.is_file():
        raw = json.loads(args.output.read_text(encoding="utf-8"))
        entries = {
            str(item["id"]): item
            for item in raw.get("entries", [])
            if isinstance(item, dict)
        }
        if not entries and isinstance(raw, dict):
            entries = {
                key: value
                for key, value in raw.items()
                if key.isdigit() and isinstance(value, dict)
            }
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
            if args.force:
                entries.pop(key, None)
            if key in entries and not args.force:
                continue
            meta = labels.get(key)
            if not meta or not meta.get("zh"):
                failed.append(species_id)
                continue
            html = fetch_rendered_html(session, meta["zh"])
            if html is None:
                failed.append(species_id)
                print(f"failed {species_id:4d} {meta['zh']}", flush=True)
                continue
            cries = parse_cries(html)
            forms = parse_form_art(html)
            if cries or forms:
                entries[key] = {
                    "id": species_id,
                    "nameZh": meta["zh"],
                    "cries": cries,
                    "forms": forms,
                    "fetchedAt": datetime.now(timezone.utc)
                    .replace(microsecond=0)
                    .isoformat(),
                }
                fetched.append(species_id)
                print(
                    f"ok {species_id:4d} {meta['zh']}: "
                    f"{len(cries)} cries, {len(forms)} art",
                    flush=True,
                )
            else:
                failed.append(species_id)
                print(f"no-media {species_id:4d} {meta['zh']}", flush=True)
        except requests.RequestException as exc:
            failed.append(species_id)
            print(f"error {species_id:4d}: {exc}", flush=True)
        finally:
            # Object keyed by id (items.json style) so the app can read it
            # through DexRepository.getReferenceEntries.
            payload = {
                str(item["id"]): item
                for item in sorted(entries.values(), key=lambda item: item["id"])
            }
            write_payload(payload, args.output)
            time.sleep(args.delay)

    print(
        f"done: {len(fetched)} fetched, {len(failed)} failed, "
        f"{len(entries)} total entries -> {args.output}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
