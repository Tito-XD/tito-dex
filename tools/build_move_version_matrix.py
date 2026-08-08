#!/usr/bin/env python3
"""Build a compact move -> version-group matrix from staged dex details."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DETAILS = ROOT / "dist/dex-v19/upload/v5/details"
DEFAULT_OUTPUT = ROOT / "flutter/assets/data/move_version_matrix.json"


def collect_move_groups(details_dir: Path) -> dict[str, list[str]]:
    groups_by_move: dict[int, set[str]] = {}
    for path in sorted(details_dir.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        records: list[dict[str, Any]] = [payload, *(payload.get("forms") or [])]
        for record in records:
            move_sets = record.get("moveSets") or {}
            for version_group, move_set in move_sets.items():
                for method in ("levelUp", "machine", "egg", "tutor"):
                    for ref in move_set.get(method) or []:
                        move_id = ref.get("moveId")
                        if isinstance(move_id, int) and move_id > 0:
                            groups_by_move.setdefault(move_id, set()).add(
                                version_group
                            )
    return {
        str(move_id): sorted(groups)
        for move_id, groups in sorted(groups_by_move.items())
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--details", type=Path, default=DEFAULT_DETAILS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    moves = collect_move_groups(args.details)
    payload = {
        "schemaVersion": 1,
        "source": "TitoDex v19 staged per-game move sets (PokeAPI)",
        "moves": moves,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"moves": len(moves)}, indent=2))
    print(args.output)


if __name__ == "__main__":
    main()
