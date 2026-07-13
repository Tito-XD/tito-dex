#!/usr/bin/env python3
"""Download Pokémon type icons from msikma/pokesprite (Gen 8 misc sprites).

Source metadata: https://raw.githubusercontent.com/msikma/pokesprite/master/data/misc.json
Images: https://github.com/msikma/pokesprite/tree/master/misc/types
License: see pokesprite repo (MIT).
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "data" / "assets" / "type_icons"
MISC_JSON_URL = (
    "https://raw.githubusercontent.com/msikma/pokesprite/master/data/misc.json"
)
RAW_BASE = "https://raw.githubusercontent.com/msikma/pokesprite/master/misc"

TYPE_NAMES = [
    "normal",
    "fire",
    "water",
    "electric",
    "grass",
    "ice",
    "fighting",
    "poison",
    "ground",
    "flying",
    "psychic",
    "bug",
    "rock",
    "ghost",
    "dragon",
    "dark",
    "steel",
    "fairy",
]


def _fetch_json(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "TitoDex-maintainer/1.0 (+https://github.com/Tito-XD/tito-dex)"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def _fetch_bytes(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "TitoDex-maintainer/1.0 (+https://github.com/Tito-XD/tito-dex)"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def pokesprite_type_path(type_name: str, *, variant: str = "gen-8") -> str:
    """Return relative misc/ path for a type icon (e.g. types/gen8/fire.png)."""
    misc = _fetch_json(MISC_JSON_URL)
    entries = misc.get("types") or []
    for entry in entries:
        name = (entry.get("name") or {}).get("eng", "")
        if name != type_name:
            continue
        files = entry.get("files") or {}
        rel = files.get(variant)
        if rel:
            return rel
        # Fallback to any available variant.
        if files:
            return next(iter(files.values()))
    raise KeyError(f"type {type_name!r} not found in pokesprite misc.json")


def fetch_type_icons(
    output_dir: Path,
    *,
    variant: str = "gen-8",
    optimize: bool = True,
) -> list[Path]:
    """Download all 18 type icons into output_dir/{type}.png."""
    sys.path.insert(0, str(ROOT / "tools"))
    from build_dex_bundle import optimize_png  # noqa: WPS433

    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []

    for type_name in TYPE_NAMES:
        rel = pokesprite_type_path(type_name, variant=variant)
        url = f"{RAW_BASE}/{rel}"
        png = _fetch_bytes(url)
        if optimize:
            png = optimize_png(png, max_width=64)
        out_path = output_dir / f"{type_name}.png"
        out_path.write_bytes(png)
        written.append(out_path)
        print(f"  {type_name} ← {rel} ({len(png)} bytes)", flush=True)

    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUT,
        help=f"Output directory (default: {DEFAULT_OUT})",
    )
    parser.add_argument(
        "--variant",
        default="gen-8",
        choices=("gen-8", "go", "masters"),
        help="Pokesprite type icon set (default: gen-8)",
    )
    parser.add_argument(
        "--no-optimize",
        action="store_true",
        help="Skip PNG resize/compress pass",
    )
    args = parser.parse_args()

    print(f"Fetching pokesprite type icons ({args.variant})…", flush=True)
    paths = fetch_type_icons(
        args.output,
        variant=args.variant,
        optimize=not args.no_optimize,
    )
    print(f"Wrote {len(paths)} icons → {args.output}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
