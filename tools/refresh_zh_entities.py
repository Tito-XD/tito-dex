#!/usr/bin/env python3
"""Refresh zh entity catalogs (items/moves/abilities) from PokeAPI — no location crawl."""

from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from fetch_zh_catalog import (  # noqa: WPS433
    OUT_DIR,
    PokeApiClient,
    fetch_abilities,
    fetch_items,
    fetch_moves,
    write_json,
)


def main() -> int:
    client = PokeApiClient()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print("==> moves", flush=True)
    moves = fetch_moves(client)
    write_json(OUT_DIR / "moves.json", moves)

    print("==> abilities", flush=True)
    abilities = fetch_abilities(client)
    write_json(OUT_DIR / "abilities.json", abilities)

    print("==> items", flush=True)
    items = fetch_items(client)
    write_json(OUT_DIR / "items.json", items)

    manifest_path = OUT_DIR / "manifest.json"
    manifest = {}
    if manifest_path.is_file():
        import json

        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.update(
        {
            "generatedAt": datetime.now(timezone.utc).isoformat(),
            "counts": {
                **(manifest.get("counts") or {}),
                "moves": len(moves),
                "abilities": len(abilities),
                "items": len(items),
            },
        }
    )
    write_json(manifest_path, manifest)

    print(
        f"Done: moves={len(moves)} abilities={len(abilities)} items={len(items)}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
