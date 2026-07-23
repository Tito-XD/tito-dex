#!/usr/bin/env python3
"""Seed starter animated GIFs + cries into the dex CDN (R2 `titodex-dex`).

Downloads Showdown animated GIFs and `latest` cries from the PokeAPI GitHub
mirrors for every core-series starter trio (plus Pikachu / Eevee), lays them
out in the R2 upload structure, and optionally uploads via wrangler.

Usage:
    python3 tools/seed_starter_media.py                # download only
    python3 tools/seed_starter_media.py --upload       # download + wrangler put

R2 layout (matches DexCdnConfig in the Flutter app):
    v4/sprites/animated/{id}.gif
    v4/cries/{id}.ogg
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = REPO_ROOT / "dist" / "starter-media"
WRANGLER_DIR = REPO_ROOT / "cloudflare" / "dex-cdn"
BUCKET = "titodex-dex"

GIF_URL = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/{id}.gif"
CRY_URL = "https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/{id}.ogg"

# Core-series starter trios Gen I–IX, plus the LGPE partners.
STARTER_IDS = [
    1, 4, 7,        # Gen I   妙蛙种子 / 小火龙 / 杰尼龟
    152, 155, 158,  # Gen II  菊草叶 / 火球鼠 / 小锯鳄
    252, 255, 258,  # Gen III 木守宫 / 火稚鸡 / 水跃鱼
    387, 390, 393,  # Gen IV  草苗龟 / 小火焰猴 / 波加曼
    495, 498, 501,  # Gen V   藤藤蛇 / 暖暖猪 / 水水獭
    650, 653, 656,  # Gen VI  哈力栗 / 火狐狸 / 呱呱泡蛙
    722, 725, 728,  # Gen VII 木木枭 / 火斑喵 / 球球海狮
    810, 813, 816,  # Gen VIII 敲音猴 / 炎兔儿 / 泪眼蜥
    906, 909, 912,  # Gen IX  新叶喵 / 呆火鳄 / 润水鸭
    25, 133,        # 皮卡丘 / 伊布（LGPE 搭档）
]


def download(url: str, dest: Path) -> bool:
    if dest.exists() and dest.stat().st_size > 0:
        return True
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            dest.write_bytes(response.read())
        return True
    except Exception as error:  # noqa: BLE001 - report and continue
        print(f"  !! {url} -> {error}")
        return False


def wrangler_put(key: str, file: Path) -> bool:
    result = subprocess.run(
        [
            "npx", "wrangler", "r2", "object", "put",
            f"{BUCKET}/{key}", "--file", str(file), "--remote",
        ],
        cwd=WRANGLER_DIR,
        capture_output=True,
        text=True,
        shell=(sys.platform == "win32"),
    )
    if result.returncode != 0:
        print(f"  !! upload {key}: {result.stderr.strip().splitlines()[-1:]}")
        return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--upload", action="store_true",
                        help="upload to R2 via wrangler after downloading")
    parser.add_argument("--prefix", default="v4")
    args = parser.parse_args()

    upload_root = args.output / "upload"
    ok_gif = ok_cry = 0
    files: list[tuple[str, Path]] = []

    print(f"Seeding {len(STARTER_IDS)} species -> {upload_root}")
    for pid in STARTER_IDS:
        gif = upload_root / args.prefix / "sprites" / "animated" / f"{pid}.gif"
        cry = upload_root / args.prefix / "cries" / f"{pid}.ogg"
        if download(GIF_URL.format(id=pid), gif):
            ok_gif += 1
            files.append((f"{args.prefix}/sprites/animated/{pid}.gif", gif))
        if download(CRY_URL.format(id=pid), cry):
            ok_cry += 1
            files.append((f"{args.prefix}/cries/{pid}.ogg", cry))

    print(f"Downloaded: {ok_gif}/{len(STARTER_IDS)} GIFs, "
          f"{ok_cry}/{len(STARTER_IDS)} cries")

    if not args.upload:
        print("Dry run (no --upload). To push to R2:")
        print(f"  python3 tools/seed_starter_media.py --upload")
        return 0

    uploaded = 0
    for key, file in files:
        if wrangler_put(key, file):
            uploaded += 1
            print(f"  ok {key}")
    print(f"Uploaded {uploaded}/{len(files)} objects to {BUCKET}")
    return 0 if uploaded == len(files) else 1


if __name__ == "__main__":
    raise SystemExit(main())
