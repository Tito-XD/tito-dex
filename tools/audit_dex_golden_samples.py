#!/usr/bin/env python3
"""Strict release-gate audit for TitoDex form and encounter golden samples."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from check_form_golden_samples import validate as validate_forms


def load_detail(bundle_dir: Path, species_id: int) -> dict[str, Any]:
    return json.loads(
        (bundle_dir / "details" / f"{species_id}.json").read_text(encoding="utf-8")
    )


def exact_entries(detail: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        entry
        for entries in (detail.get("obtainLocationsByVersion") or {}).values()
        for entry in entries
    ]


def audit(bundle_dir: Path) -> list[str]:
    errors = validate_forms(bundle_dir, require_all=True)

    identity_samples = {
        157: (10233, "typhlosion-hisui"),
        194: (10253, "wooper-paldea"),
    }
    for species_id, (pokemon_id, form_key) in identity_samples.items():
        entries = exact_entries(load_detail(bundle_dir, species_id))
        if not any(
            entry.get("speciesId") == species_id
            and entry.get("pokemonId") == pokemon_id
            and entry.get("formKey") == form_key
            and not entry.get("formAmbiguous")
            for entry in entries
        ):
            errors.append(
                f"#{species_id}: missing exact encounter identity {pokemon_id}/{form_key}"
            )

    all_entries: list[dict[str, Any]] = []
    for path in sorted((bundle_dir / "details").glob("*.json")):
        all_entries.extend(exact_entries(json.loads(path.read_text(encoding="utf-8"))))
    required_states = {
        "teraType": lambda entry: bool(entry.get("teraType")),
        "isAlpha": lambda entry: bool(entry.get("isAlpha")),
        "formAmbiguous": lambda entry: bool(entry.get("formAmbiguous")),
        "isRaid": lambda entry: bool(entry.get("isRaid")),
        "isFixedEncounter": lambda entry: bool(entry.get("isFixedEncounter")),
    }
    for label, predicate in required_states.items():
        if not any(predicate(entry) for entry in all_entries):
            errors.append(f"encounters: missing golden state {label}")

    for entry in all_entries:
        ambiguous = bool(entry.get("formAmbiguous"))
        has_pair = entry.get("pokemonId") is not None and bool(entry.get("formKey"))
        if ambiguous and has_pair:
            errors.append("encounters: ambiguous record must not claim pokemonId/formKey")
            break
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    errors = audit(args.bundle_dir)
    report = {"ok": not errors, "errors": errors}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if args.strict and errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
