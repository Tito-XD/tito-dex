#!/usr/bin/env python3
"""Generate the Flutter dex-axis label maps from the canonical zh JSON."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data" / "l10n" / "zh" / "dex_axes.json"
OUTPUT = ROOT / "flutter" / "lib" / "features" / "dex" / "dex_axis_labels.g.dart"

NAMES = {
    "shape": "kDexShapeLabelsZh",
    "color": "kDexColorLabelsZh",
    "growthRate": "kDexGrowthRateLabelsZh",
    "habitat": "kDexHabitatLabelsZh",
}


def render(data: dict[str, dict[str, str]]) -> str:
    lines = ["// Generated from data/l10n/zh/dex_axes.json. Do not edit by hand."]
    for section, dart_name in NAMES.items():
        lines.extend([f"const {dart_name} = <String, String>{{"])
        for slug, label in data[section].items():
            lines.append(f"  {slug!r}: {label!r},")
        lines.extend(["};", ""])
    return "\n".join(lines)


def main() -> int:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    OUTPUT.write_text(render(data), encoding="utf-8")
    print(f"Generated {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
