#!/usr/bin/env python3
"""Build the expanded TitoDex items dataset (a few hundred player-relevant items).

Scope & taxonomy follow Bulbapedia's Browse:Items player-facing grouping, but the
data is sourced from PokeAPI (list, English name, category, cost, sprite) and the
Simplified-Chinese in-game description comes from PokeAPI `flavor_text_entries`
(`zh-hans`). 52poke is only consulted as a fallback for the rare items PokeAPI has
no zh-hans flavor for (see enrich step). Nothing here runs in the app — this is a
build-time tool feeding the offline bundle + CDN.

Output (under --output, default dist/items-v11-work/):
  items.json                 dict keyed by str(id), full schema
  item-sprites/<slug>.png    downloaded PokeAPI item sprites
  coverage.json              zh description coverage report + gap slug list

Run: python3 tools/build_items_dataset.py [--limit N] [--workers 8]
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POKEAPI = "https://pokeapi.co/api/v2"
CDN_ITEM_SPRITES = "https://dex.tito.cafe/v5/item-sprites"

# Pockets we pull from; 'key'/'mail'/'machines' (TMs) are intentionally excluded.
POCKETS = ["pokeballs", "medicine", "berries", "battle", "misc"]

# misc-pocket categories we keep (held/battle-relevant + evolution). Everything
# else in misc (collectibles, loot, mail, event, unused, plot, gameplay, …) drops.
MISC_HELD = {
    "held-items", "choice", "type-enhancement", "type-protection",
    "bad-held-items", "jewels", "scarves", "species-specific", "plates",
    "memories", "mega-stones", "z-crystals", "tera-shard",
}
MISC_EVO = {"evolution"}
# medicine-pocket categories that are really stat/EV training, not healing.
MED_STAT = {"vitamins", "effort-training", "effort-drop", "nature-mints"}


def group_for(pocket: str, category: str) -> str | None:
    """Map a (pocket, category) to a Bulbapedia-style player group, or None to skip."""
    if pocket == "pokeballs":
        return "精灵球"
    if pocket == "berries":
        return "树果"
    if pocket == "battle":
        return "战斗道具"
    if pocket == "medicine":
        return "能力提升" if category in MED_STAT else "回复药品"
    if pocket == "misc":
        if category in MISC_EVO:
            return "进化道具"
        if category in MISC_HELD:
            return "携带道具"
    return None


def _get(url: str, *, retries: int = 3, binary: bool = False):
    last: Exception | None = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "TitoDex/1.0 (+bundle build)"})
            with urllib.request.urlopen(req, timeout=40) as resp:
                data = resp.read()
            return data if binary else json.loads(data.decode("utf-8"))
        except Exception as exc:  # noqa: BLE001
            last = exc
            time.sleep(0.6 * (attempt + 1))
    raise last  # type: ignore[misc]


def resolve_category_groups() -> dict[str, str]:
    """category slug -> zh group, discovered live from PokeAPI pockets."""
    groups: dict[str, str] = {}
    for pocket in POCKETS:
        data = _get(f"{POKEAPI}/item-pocket/{pocket}")
        for cat in data["categories"]:
            group = group_for(pocket, cat["name"])
            if group:
                groups[cat["name"]] = group
    return groups


def collect_slugs(category_groups: dict[str, str]) -> dict[str, str]:
    """slug -> zh group, for every item in the included categories."""
    slugs: dict[str, str] = {}
    for category, group in sorted(category_groups.items()):
        data = _get(f"{POKEAPI}/item-category/{category}")
        for item in data["items"]:
            slugs[item["name"]] = group
    return slugs


def _pick(entries: list[dict], lang: str, field: str) -> str | None:
    """Latest entry for a language, cleaned of the games' full-width padding."""
    picked = [e for e in entries if e["language"]["name"] == lang]
    if not picked:
        return None
    text = picked[-1][field]
    return " ".join(text.replace("\n", " ").replace("\x0c", " ").split()) or None


def build_item(slug: str, group: str, labels_zh: dict) -> dict | None:
    try:
        data = _get(f"{POKEAPI}/item/{slug}")
    except Exception as exc:  # noqa: BLE001
        print(f"  warn item {slug}: {exc}", file=sys.stderr, flush=True)
        return None

    name_en = _pick(data.get("names", []), "en", "name") or slug.replace("-", " ").title()
    name_zh = (
        _pick(data.get("names", []), "zh-hans", "name")
        or labels_zh.get(slug, {}).get("nameZh")
        or name_en
    )
    desc_zh = _pick(data.get("flavor_text_entries", []), "zh-hans", "text")
    effect_en = _pick(data.get("effect_entries", []), "en", "short_effect")
    sprite = (data.get("sprites") or {}).get("default")

    return {
        "id": data["id"],
        "slug": slug,
        "nameEn": name_en,
        "nameZh": name_zh,
        "category": data.get("category", {}).get("name", ""),
        "categoryZh": group,
        "cost": data.get("cost"),
        "spriteUrl": f"{CDN_ITEM_SPRITES}/{slug}.png",
        "descriptionZh": desc_zh,          # may be None -> enrich fallback fills it
        "effectZh": desc_zh,               # mirror; keeps the detail sheet's fallback aligned
        "shortEffectEn": effect_en,        # English short effect, last-resort fallback
        "_pokeSprite": sprite,             # transient: download source, stripped before write
    }


def download_sprites(items: list[dict], sprites_dir: Path, workers: int) -> set[str]:
    """Download available sprites; return the set of slugs that now have a file."""
    sprites_dir.mkdir(parents=True, exist_ok=True)

    def one(item: dict) -> bool:
        url = item.get("_pokeSprite")
        if not url:
            return False
        try:
            png = _get(url, binary=True)
        except Exception as exc:  # noqa: BLE001
            print(f"  warn sprite {item['slug']}: {exc}", file=sys.stderr, flush=True)
            return False
        if not png.startswith(b"\x89PNG\r\n\x1a\n"):
            return False
        (sprites_dir / f"{item['slug']}.png").write_bytes(png)
        return True

    ok: set[str] = set()
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futures = {ex.submit(one, it): it for it in items}
        for done, fut in enumerate(as_completed(futures), start=1):
            if fut.result():
                ok.add(futures[fut]["slug"])
            if done % 100 == 0 or done == len(futures):
                print(f"  sprites {done}/{len(futures)}", flush=True)
    return ok


def main() -> None:
    parser = argparse.ArgumentParser(description="Build expanded items dataset from PokeAPI")
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "items-v11-work")
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--limit", type=int, default=0, help="cap item count for a dry run")
    args = parser.parse_args()

    labels_path = ROOT / "data" / "l10n" / "zh" / "items.json"
    labels_zh = json.loads(labels_path.read_text(encoding="utf-8")) if labels_path.is_file() else {}
    labels_by_slug = {v.get("slug"): v for v in labels_zh.values() if isinstance(v, dict)}

    print("Resolving category groups from PokeAPI pockets…", flush=True)
    category_groups = resolve_category_groups()
    print(f"  included categories: {len(category_groups)}", flush=True)

    print("Collecting item slugs…", flush=True)
    slug_groups = collect_slugs(category_groups)
    slugs = sorted(slug_groups)
    if args.limit:
        slugs = slugs[: args.limit]
    print(f"  items to build: {len(slugs)}", flush=True)

    print("Fetching item details (name/zh/desc/cost/sprite)…", flush=True)
    items: list[dict] = []
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = {ex.submit(build_item, s, slug_groups[s], labels_by_slug): s for s in slugs}
        for done, fut in enumerate(as_completed(futures), start=1):
            item = fut.result()
            if item:
                items.append(item)
            if done % 100 == 0 or done == len(futures):
                print(f"  items {done}/{len(futures)}", flush=True)

    print("Downloading sprites…", flush=True)
    sprite_slugs = download_sprites(items, args.output / "item-sprites", args.workers)
    sprites_ok = len(sprite_slugs)

    # Coverage report before stripping transient fields.
    gaps = sorted(it["slug"] for it in items if not it["descriptionZh"])
    from collections import Counter
    group_counts = Counter(it["categoryZh"] for it in items)

    for it in items:
        it.pop("_pokeSprite", None)
        # Don't point the app at a sprite that was never uploaded — a missing
        # file would just 404 on the CDN. Newer items without a PokeAPI sprite
        # simply render with no icon.
        if it["slug"] not in sprite_slugs:
            it["spriteUrl"] = None
    items.sort(key=lambda it: it["id"])
    payload = {str(it["id"]): it for it in items}

    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "items.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    coverage = {
        "total": len(items),
        "zhDescribed": len(items) - len(gaps),
        "spritesDownloaded": sprites_ok,
        "groupCounts": dict(group_counts.most_common()),
        "zhGapSlugs": gaps,
    }
    (args.output / "coverage.json").write_text(
        json.dumps(coverage, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    print("\n=== summary ===", flush=True)
    print(f"items: {len(items)}", flush=True)
    print(f"zh described: {len(items) - len(gaps)}/{len(items)} (gap {len(gaps)})", flush=True)
    print(f"sprites: {sprites_ok}/{len(items)}", flush=True)
    print(f"groups: {dict(group_counts.most_common())}", flush=True)
    if gaps:
        print(f"zh gap slugs (first 30): {gaps[:30]}", flush=True)


if __name__ == "__main__":
    main()
