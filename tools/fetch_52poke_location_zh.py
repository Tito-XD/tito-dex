#!/usr/bin/env python3
"""Incrementally resolve unresolved location-area slugs via 52poke wiki (best-effort).

Reads data/l10n/zh/location_areas_unresolved.json, attempts to fetch Chinese
labels from wiki.52poke.com, merges into location_areas.json, and rewrites the
unresolved list.

52poke may block automated requests (Cloudflare). Failures are logged and slugs
stay in the unresolved list — run locally or retry weekly via GitHub Actions.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[1]
L10N_DIR = ROOT / "data" / "l10n" / "zh"
AREAS_PATH = L10N_DIR / "location_areas.json"
UNRESOLVED_PATH = L10N_DIR / "location_areas_unresolved.json"
MANIFEST_PATH = L10N_DIR / "manifest.json"

WIKI_BASE = "https://wiki.52poke.com"
USER_AGENT = "TitoDex-maintainer/1.0 (+https://github.com/Tito-XD/tito-dex)"
DEFAULT_DELAY = 1.5

# English labels that indicate we still need a Chinese name.
UNRESOLVED_SOURCES = frozenset(
    {
        "english_fallback",
        "slug_title",
        "slug_title_name",
    }
)

CLOUDFLARE_MARKERS = (
    "just a moment",
    "cf-browser-verification",
    "challenge-platform",
)


def _is_cloudflare_block(html: str, status: int) -> bool:
    if status == 403:
        return True
    lower = html.lower()
    return any(marker in lower for marker in CLOUDFLARE_MARKERS)


def _wiki_session() -> requests.Session:
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": USER_AGENT,
            "Accept-Language": "zh-CN,zh;q=0.9",
        }
    )
    return session


def _search_wiki(session: requests.Session, query: str) -> list[str]:
    """Return wiki page titles from MediaWiki opensearch."""
    params = {
        "action": "opensearch",
        "search": query,
        "limit": 5,
        "namespace": 0,
        "format": "json",
    }
    url = f"{WIKI_BASE}/api.php?{urllib.parse.urlencode(params)}"
    response = session.get(url, timeout=30)
    if response.status_code != 200:
        return []
    if _is_cloudflare_block(response.text, response.status_code):
        return []
    try:
        payload = response.json()
    except json.JSONDecodeError:
        return []
    if not isinstance(payload, list) or len(payload) < 2:
        return []
    titles = payload[1]
    return [t for t in titles if isinstance(t, str)]


def _fetch_page_title_zh(session: requests.Session, title: str) -> str | None:
    """Fetch a wiki page and extract the primary Chinese heading."""
    encoded = urllib.parse.quote(title, safe="")
    url = f"{WIKI_BASE}/wiki/{encoded}"
    response = session.get(url, timeout=30)
    if response.status_code != 200:
        return None
    if _is_cloudflare_block(response.text, response.status_code):
        return None

    soup = BeautifulSoup(response.text, "html.parser")
    h1 = soup.find("h1", id="firstHeading")
    if h1:
        text = h1.get_text(strip=True)
        if text and _looks_chinese(text):
            return _normalize_label(text)

    # Fallback: page title from <title> tag (strip site suffix).
    page_title = soup.find("title")
    if page_title:
        raw = page_title.get_text(strip=True)
        raw = re.sub(r"\s*-\s*神奇宝贝百科.*$", "", raw)
        raw = re.sub(r"\s*-\s*神奇寶貝百科.*$", "", raw)
        if raw and _looks_chinese(raw):
            return _normalize_label(raw)

    return None


def _looks_chinese(text: str) -> bool:
    return bool(re.search(r"[\u4e00-\u9fff]", text))


def _normalize_label(text: str) -> str:
    text = text.strip()
    text = re.sub(r"\s+", " ", text)
    return text


def _search_queries(slug: str, entry: dict[str, object]) -> list[str]:
    """Build search queries from slug metadata."""
    queries: list[str] = []
    area_en = str(entry.get("areaNameEn") or "")
    location_en = str(entry.get("locationNameEn") or "")

    for name in (location_en, area_en):
        if not name or name == slug:
            continue
        queries.append(name)
        # Route N → N号道路
        route_match = re.fullmatch(r"(?:\w+\s+)?Route (\d+)", name.strip())
        if route_match:
            queries.append(f"{route_match.group(1)}号道路")

    # Slug-derived title, e.g. pokemon-tower-1f → Pokemon Tower 1F
    slug_title = slug.replace("-area", "").replace("-", " ").title()
    queries.append(slug_title)

    # Deduplicate preserving order.
    seen: set[str] = set()
    result: list[str] = []
    for q in queries:
        q = q.strip()
        if q and q not in seen:
            seen.add(q)
            result.append(q)
    return result


def _needs_resolution(entry: dict[str, object]) -> bool:
    source = str(entry.get("source") or "")
    label = str(entry.get("labelZh") or "")
    if source in UNRESOLVED_SOURCES:
        return True
    if not _looks_chinese(label):
        return True
    return False


def fetch_label_for_slug(
    session: requests.Session,
    slug: str,
    entry: dict[str, object],
    *,
    delay: float,
) -> tuple[str | None, str]:
    """Return (label_zh, status) where status is resolved|not_found|blocked."""
    for query in _search_queries(slug, entry):
        time.sleep(delay)
        titles = _search_wiki(session, query)
        if not titles and query == _search_queries(slug, entry)[0]:
            # First query got empty — might be Cloudflare; probe once more.
            probe = session.get(f"{WIKI_BASE}/api.php?action=query&meta=siteinfo", timeout=30)
            if _is_cloudflare_block(probe.text, probe.status_code):
                return None, "blocked"

        for title in titles:
            time.sleep(delay)
            label = _fetch_page_title_zh(session, title)
            if label:
                return label, "resolved"

    return None, "not_found"


def load_json(path: Path) -> dict | list:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: object) -> None:
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def update_manifest(*, resolved_count: int, unresolved_count: int) -> str:
    manifest: dict[str, object] = {}
    if MANIFEST_PATH.is_file():
        manifest = load_json(MANIFEST_PATH)  # type: ignore[assignment]

    generated_at = datetime.now(timezone.utc).isoformat()
    counts = dict(manifest.get("counts") or {})
    counts["locationAreasUnresolved"] = unresolved_count
    manifest["generatedAt"] = generated_at
    manifest["counts"] = counts
    manifest.setdefault("locale", "zh-Hans")
    manifest.setdefault("pokeapiBase", "https://pokeapi.co/api/v2")
    write_json(MANIFEST_PATH, manifest)
    return generated_at


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--delay",
        type=float,
        default=DEFAULT_DELAY,
        help=f"Seconds between requests (default {DEFAULT_DELAY})",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Max slugs to process this run (0 = all)",
    )
    parser.add_argument(
        "--force-full",
        action="store_true",
        help="Re-fetch all slugs that still lack proper Chinese labels",
    )
    args = parser.parse_args()

    if not AREAS_PATH.is_file():
        print(f"ERROR: missing {AREAS_PATH}", file=sys.stderr)
        return 1

    areas: dict[str, dict[str, object]] = load_json(AREAS_PATH)  # type: ignore[assignment]

    if args.force_full:
        slugs = [s for s, e in areas.items() if _needs_resolution(e)]
    elif UNRESOLVED_PATH.is_file():
        unresolved_data = load_json(UNRESOLVED_PATH)
        slugs = list(unresolved_data.get("slugs") or [])
    else:
        slugs = [s for s, e in areas.items() if _needs_resolution(e)]

    if args.limit > 0:
        slugs = slugs[: args.limit]

    if not slugs:
        print("No slugs to process.", flush=True)
        return 0

    session = _wiki_session()
    resolved: list[str] = []
    still_unresolved: list[str] = []
    blocked = False

    print(f"Processing {len(slugs)} location-area slug(s)…", flush=True)

    for index, slug in enumerate(slugs, start=1):
        entry = areas.get(slug)
        if not entry:
            print(f"  [{index}/{len(slugs)}] skip {slug}: not in catalog", flush=True)
            still_unresolved.append(slug)
            continue

        label, status = fetch_label_for_slug(
            session, slug, entry, delay=args.delay
        )

        if status == "blocked":
            blocked = True
            print(
                f"  [{index}/{len(slugs)}] BLOCKED by Cloudflare — stopping early",
                file=sys.stderr,
                flush=True,
            )
            still_unresolved.extend(slugs[index - 1 :])
            break

        if label:
            entry["labelZh"] = label
            entry["source"] = "52poke_wiki"
            resolved.append(slug)
            print(f"  [{index}/{len(slugs)}] ✓ {slug} → {label}", flush=True)
        else:
            still_unresolved.append(slug)
            print(f"  [{index}/{len(slugs)}] ✗ {slug}: not found", flush=True)

    if resolved:
        write_json(AREAS_PATH, areas)

    # Merge remaining unresolved from catalog entries still lacking Chinese.
    if args.force_full or not blocked:
        for slug, entry in areas.items():
            if _needs_resolution(entry) and slug not in still_unresolved:
                still_unresolved.append(slug)

    still_unresolved = sorted(set(still_unresolved))
    write_json(UNRESOLVED_PATH, {"slugs": still_unresolved})

    generated_at = ""
    if resolved:
        generated_at = update_manifest(
            resolved_count=len(resolved),
            unresolved_count=len(still_unresolved),
        )
    elif MANIFEST_PATH.is_file():
        manifest = load_json(MANIFEST_PATH)  # type: ignore[assignment]
        generated_at = str(manifest.get("generatedAt") or "")

    print(
        f"\nDone: resolved={len(resolved)}, unresolved={len(still_unresolved)}"
        + (f", l10nVersion={generated_at}" if generated_at else ""),
        flush=True,
    )
    if blocked:
        print(
            "NOTE: 52poke wiki blocked automated access (Cloudflare). "
            "Slugs remain in location_areas_unresolved.json for a later run.",
            file=sys.stderr,
            flush=True,
        )
    return 0 if not blocked or resolved else 2


if __name__ == "__main__":
    raise SystemExit(main())
