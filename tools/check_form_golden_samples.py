#!/usr/bin/env python3
"""Validate long-lived form-system golden samples in an extracted bundle."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

EXPECTED: dict[int, set[str]] = {
    6: {"charizard-mega-x", "charizard-mega-y", "charizard-gmax"},
    25: {"pikachu-gmax", "pikachu-starter", "pikachu-world-cap"},
    157: {"typhlosion-hisui"},
    194: {"wooper-paldea"},
    479: {"rotom-heat", "rotom-wash", "rotom-frost", "rotom-fan", "rotom-mow"},
    648: {"meloetta-aria", "meloetta-pirouette"},
    678: {"meowstic-male", "meowstic-female"},
    710: {"pumpkaboo-average", "pumpkaboo-small", "pumpkaboo-large", "pumpkaboo-super"},
    718: {"zygarde-10", "zygarde-50", "zygarde-complete"},
    800: {"necrozma-dusk", "necrozma-dawn", "necrozma-ultra"},
    876: {"indeedee-male", "indeedee-female"},
    898: {"calyrex-ice", "calyrex-shadow"},
    1017: {"ogerpon-wellspring-mask", "ogerpon-hearthflame-mask", "ogerpon-cornerstone-mask"},
    1024: {"terapagos", "terapagos-terastal", "terapagos-stellar"},
}


def validate(bundle_dir: Path, *, require_all: bool = False) -> list[str]:
    errors: list[str] = []
    for species_id, expected in EXPECTED.items():
        path = bundle_dir / "details" / f"{species_id}.json"
        if not path.is_file():
            if require_all:
                errors.append(f"#{species_id}: missing detail")
            continue
        detail = json.loads(path.read_text(encoding="utf-8"))
        forms = detail.get("forms") or []
        keys = {str(form.get("key")) for form in forms}
        missing = expected - keys
        if missing:
            errors.append(f"#{species_id}: missing {sorted(missing)}")
        if sum(bool(form.get("isDefault")) for form in forms) != 1:
            errors.append(f"#{species_id}: expected exactly one default form")
        if len(keys) != len(forms):
            errors.append(f"#{species_id}: duplicate form key")

    alcremie = bundle_dir / "details/869.json"
    if alcremie.is_file():
        forms = json.loads(alcremie.read_text(encoding="utf-8")).get("forms") or []
        form_ids = [form.get("formId") for form in forms]
        if len(forms) < 64:
            errors.append(f"#869: expected at least 64 forms, found {len(forms)}")
        if len(set(form_ids)) != len(form_ids):
            errors.append("#869: duplicate formId")

    vivillon = bundle_dir / "details/666.json"
    if vivillon.is_file():
        forms = json.loads(vivillon.read_text(encoding="utf-8")).get("forms") or []
        if len(forms) < 20:
            errors.append(f"#666: expected at least 20 patterns, found {len(forms)}")

    spinda = bundle_dir / "details/327.json"
    if spinda.is_file():
        keys = {
            str(form.get("key"))
            for form in json.loads(spinda.read_text(encoding="utf-8")).get("forms") or []
        }
        if any("pattern" in key or "spot" in key for key in keys):
            errors.append("#327: procedural spot patterns must not be enumerated")

    zygarde = bundle_dir / "details/718.json"
    if zygarde.is_file():
        keys = {
            str(form.get("key"))
            for form in json.loads(zygarde.read_text(encoding="utf-8")).get("forms") or []
        }
        if any("1-percent" in key or "cell" in key or "core" in key for key in keys):
            errors.append("#718: fabricated 1%/Cell/Core form")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", type=Path)
    parser.add_argument("--require-all", action="store_true")
    args = parser.parse_args()
    errors = validate(args.bundle_dir, require_all=args.require_all)
    if errors:
        print("\n".join(errors))
        return 1
    print(f"OK: form golden samples in {args.bundle_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
