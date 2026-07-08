#!/usr/bin/env python3
"""Generate HGSS map list Dart source from Project Pokémon map list markdown export."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = ROOT / "docs" / "hgss-map-list.md"
OUT_JSON = ROOT / "tools" / "hgss_map_list.json"
OUT_DART = ROOT / "flutter" / "lib" / "features" / "parser" / "hgss_map_list.dart"


def parse_markdown_table(path: Path) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    for line in path.read_text().splitlines():
        if not line.startswith("|") or "---" in line or "name | code_name" in line:
            continue
        parts = [part.strip() for part in line.split("|")]
        if len(parts) < 17:
            continue
        name, code = parts[1], parts[2]
        if not re.match(r"^[A-Za-z0-9]", name):
            continue
        entries.append({"name": name, "code": code})
    return entries


def write_dart(entries: list[dict[str, str]]) -> None:
    lines = [
        "// Generated from Project Pokémon HGSS Map List (list index = save Map ID @0x1234).",
        "const hgssMapEntries = <Map<String, String>>[",
    ]
    for entry in entries:
        name = entry["name"].replace("'", "\\'")
        code = entry["code"].replace("'", "\\'")
        lines.append(f"  {{'name': '{name}', 'code': '{code}'}},")
    lines.append("];")
    OUT_DART.write_text("\n".join(lines) + "\n")


def main() -> None:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SRC
    if not src.exists():
        raise SystemExit(f"Source map list not found: {src}")

    entries = parse_markdown_table(src)
    OUT_JSON.write_text(json.dumps(entries, ensure_ascii=False, indent=2))
    write_dart(entries)
    print(f"Wrote {len(entries)} entries to {OUT_DART}")


if __name__ == "__main__":
    main()
