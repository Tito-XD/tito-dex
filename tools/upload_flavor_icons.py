#!/usr/bin/env python3
"""Upload generated per-flavor game icons to the R2 CDN (incremental)."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_dex_bundle import GAME_EDITIONS  # noqa: E402

UPLOAD_DIR = ROOT / "dist" / "dex-v9" / "upload" / "v5" / "game_icons"


def main() -> None:
    flavors = {
        flavor
        for edition in GAME_EDITIONS
        if len(edition.flavor_versions) > 1
        for flavor in edition.flavor_versions
    }
    for flavor in sorted(flavors):
        path = UPLOAD_DIR / f"{flavor}.png"
        if not path.exists():
            print(f"  skip: {path} not found")
            continue
        key = f"v5/game_icons/{flavor}.png"
        subprocess.run(
            [
                "npx",
                "wrangler",
                "r2",
                "object",
                "put",
                f"titodex-dex/{key}",
                f"--file={path}",
                "--remote",
                "--content-type=image/png",
            ],
            check=True,
            cwd=ROOT / "cloudflare" / "dex-cdn",
        )
        print(f"→ {key}")
    print(f"\nUploaded {len(flavors)} flavor icons.")


if __name__ == "__main__":
    main()
