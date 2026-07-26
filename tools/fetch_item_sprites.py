"""Download PokeAPI item sprites (24x24) and upload to R2.
Also enrich items.json with category_zh and sprite_url fields.

Usage:
    python3 tools/fetch_item_sprites.py             # download + enrich + upload
    python3 tools/fetch_item_sprites.py --skip-upload  # download + enrich only
"""

from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ITEMS_JSON = ROOT / "dist" / "dex-v10" / "staging" / "items.json"
SPRITE_DIR = ROOT / "dist" / "dex-v10" / "staging" / "item-sprites"
CDN_PREFIX = "v5"
CDN_BASE = "https://dex.tito.cafe"
SPRITE_BASE = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items"

# PokeAPI item category slug -> user-facing Chinese category label.
CATEGORY_ZH: dict[str, str] = {
    # 宝可梦球
    "special-balls": "特殊球",
    "standard-balls": "标准球",
    "apricorn-balls": "柑果球",
    # 树果
    # (PokeAPI doesn't have a dedicated berry category; berries are in
    #  held-items / medicine.  We'll keep the label for future grouping.)
    # 药品/状态恢复
    "healing": "药品",
    "medicine": "药品",
    "picky-healing": "药品",
    "status-cures": "状态恢复",
    "pp-recovery": "PP恢复",
    "revival": "复活",
    # 战斗道具
    "held-items": "携带道具",
    "choice": "携带道具",
    "type-enhancement": "携带道具",
    "type-protection": "携带道具",
    "bad-held-items": "携带道具",
    "in-a-pinch": "携带道具",
    "stat-boosts": "携带道具",
    # 进化道具
    "evolution": "进化道具",
    # 招式学习器
    # (PokeAPI item list doesn't have TM/HM/TR rows here; they are separate.
    #  We'll reserve the label for future integration.)
    # 重要物品
    "spelunking": "重要物品",
    "gameplay": "重要物品",
    "event-items": "重要物品",
    "collectibles": "重要物品",
    # 训练
    "training": "道具",
    "effort-training": "道具",
    "vitamins": "道具",
    "picnic": "道具",
    "other": "道具",
}

# PokeAPI item slug -> sprite filename.
# Most match the slug directly; some have special naming.
SPRITE_OVERRIDES: dict[str, str] = {
    "tm-normal": "tm-normal",
    "tm-fighting": "tm-fighting",
    # Add more overrides if PokeAPI returns 404.
}


def _http_get(url: str) -> bytes | None:
    result = subprocess.run(
        ["curl", "-sfL", "--retry", "2", url],
        capture_output=True,
        timeout=30,
    )
    if result.returncode == 0:
        return result.stdout
    return None


def main() -> None:
    skip_upload = "--skip-upload" in sys.argv

    with open(ITEMS_JSON, encoding="utf-8") as fh:
        items: dict[str, dict] = json.load(fh)

    SPRITE_DIR.mkdir(parents=True, exist_ok=True)

    updated = 0
    downloaded = 0
    for item_id, item in sorted(items.items(), key=lambda x: int(x[0])):
        slug = item["slug"]
        category_raw = item.get("category", "other")
        category_zh = CATEGORY_ZH.get(category_raw, "道具")
        sprite_name = slug + ".png"
        sprite_url = f"{CDN_BASE}/{CDN_PREFIX}/item-sprites/{sprite_name}"
        local_path = SPRITE_DIR / sprite_name

        item["categoryZh"] = category_zh
        item["spriteUrl"] = sprite_url
        updated += 1

        if local_path.exists():
            continue

        # Try PokeAPI sprite URL (slug-based).
        remote_url = f"{SPRITE_BASE}/{slug}.png"
        data = _http_get(remote_url)
        if data is None:
            # Sometimes PokeAPI uses a different naming.
            # Try with hyphens instead of underscores etc.
            alt_slug = slug.replace("-", "_")
            remote_url = f"{SPRITE_BASE}/{alt_slug}.png"
            data = _http_get(remote_url)
        if data is None:
            print(f"  warn: no sprite for {slug}", file=sys.stderr)
            continue

        local_path.write_bytes(data)
        downloaded += 1
        if downloaded % 50 == 0:
            print(f"  ... {downloaded} sprites downloaded")
        time.sleep(0.3)  # Be gentle to GitHub

    # Write enriched items.json back.
    with open(ITEMS_JSON, "w", encoding="utf-8") as fh:
        json.dump(items, fh, ensure_ascii=False, indent=2)

    print(f"Enriched {updated} items with categoryZh + spriteUrl")
    print(f"Downloaded {downloaded} new sprites")

    if skip_upload:
        print("Skipping CDN upload (--skip-upload)")
        return

    # Upload to R2.
    total = len(list(SPRITE_DIR.iterdir()))
    print(f"Uploading {total} sprites to R2 ...")
    uploaded = 0
    for png in sorted(SPRITE_DIR.iterdir()):
        subprocess.run(
            [
                "npx", "wrangler", "r2", "object", "put",
                f"titodex-dex/{CDN_PREFIX}/item-sprites/{png.name}",
                f"--file={png}",
                "--remote", "--content-type=image/png",
            ],
            cwd=ROOT / "cloudflare" / "dex-cdn",
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        uploaded += 1
        if uploaded % 40 == 0:
            print(f"  ... {uploaded}/{total} uploaded")
    print(f"Uploaded {uploaded} sprites.")


if __name__ == "__main__":
    main()
