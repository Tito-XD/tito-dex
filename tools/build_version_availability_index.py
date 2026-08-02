#!/usr/bin/env python3
"""Build the tiny APK-local exchange/evolution progress index.

The detail screen can load one evolution family on demand. The Dex progress
header cannot afford to open many detail files (or CDN URLs) just to classify
uncaught species, so this script precomputes the species IDs whose
selected-version route is evolution, breeding, or trade rather than a direct
encounter.

Usage:
  python3 tools/build_version_availability_index.py \
    --details dist/dex-v13/staging/details \
    --output flutter/assets/config/version_availability_index.json
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


VERSION_GROUPS = {
    "red-blue": ["red", "blue", "red-japan", "green-japan", "blue-japan"],
    "yellow": ["yellow"],
    "gold-silver": ["gold", "silver"],
    "crystal": ["crystal"],
    "ruby-sapphire": ["ruby", "sapphire"],
    "emerald": ["emerald"],
    "firered-leafgreen": ["firered", "leafgreen"],
    "diamond-pearl": ["diamond", "pearl"],
    "platinum": ["platinum"],
    "heartgold-soulsilver": ["heartgold", "soulsilver"],
    "black-white": ["black", "white"],
    "black-2-white-2": ["black-2", "white-2"],
    "x-y": ["x", "y"],
    "omega-ruby-alpha-sapphire": ["omega-ruby", "alpha-sapphire"],
    "sun-moon": ["sun", "moon"],
    "ultra-sun-ultra-moon": ["ultra-sun", "ultra-moon"],
    "lets-go-pikachu-lets-go-eevee": ["lets-go-pikachu", "lets-go-eevee"],
    "sword-shield": [
        "sword",
        "shield",
        "the-isle-of-armor-sword",
        "the-isle-of-armor-shield",
        "the-crown-tundra-sword",
        "the-crown-tundra-shield",
    ],
    "brilliant-diamond-shining-pearl": [
        "brilliant-diamond",
        "shining-pearl",
    ],
    "legends-arceus": ["legends-arceus"],
    "scarlet-violet": [
        "scarlet",
        "violet",
        "the-teal-mask-scarlet",
        "the-teal-mask-violet",
        "the-indigo-disk-scarlet",
        "the-indigo-disk-violet",
    ],
    "legends-za": ["legends-za", "mega-dimension"],
    "champions": ["champions"],
}

NO_BREEDING = {
    "lets-go-pikachu-lets-go-eevee",
    "legends-arceus",
    "legends-za",
    "champions",
}


def accessible_versions(version: str) -> set[str]:
    inherited = {
        "the-isle-of-armor-sword": {"sword"},
        "the-isle-of-armor-shield": {"shield"},
        "the-crown-tundra-sword": {"sword", "the-isle-of-armor-sword"},
        "the-crown-tundra-shield": {"shield", "the-isle-of-armor-shield"},
        "the-teal-mask-scarlet": {"scarlet"},
        "the-teal-mask-violet": {"violet"},
        "the-indigo-disk-scarlet": {"scarlet", "the-teal-mask-scarlet"},
        "the-indigo-disk-violet": {"violet", "the-teal-mask-violet"},
        "mega-dimension": {"legends-za"},
    }
    return {version, *inherited.get(version, set())}


def is_trade(node: dict) -> bool:
    triggers = node.get("triggers") or []
    if triggers:
        return all(trigger.get("trigger") == "trade" for trigger in triggers)
    return node.get("triggerZh") in {"交换", "通讯交换"}


def flatten(chain: dict) -> list[tuple[dict, int | None]]:
    order: list[tuple[dict, int | None]] = []

    def walk(node: dict, parent_index: int | None) -> None:
        index = len(order)
        order.append((node, parent_index))
        for child in node.get("children") or []:
            walk(child, index)

    walk(chain, None)
    return order


def plan_chain(
    chain: dict,
    catchable: set[int],
    supports_breeding: bool,
) -> dict[int, str]:
    order = flatten(chain)
    methods: list[str] = []

    def resolve(node: dict, parent_index: int | None) -> str:
        if int(node["id"]) in catchable:
            return "catch"
        if parent_index is not None and methods[parent_index] != "unavailable":
            return "trade" if is_trade(node) else "evolve"
        return "unavailable"

    for node, parent_index in order:
        methods.append(resolve(node, parent_index))

    if (
        supports_breeding
        and methods[0] == "unavailable"
        and any(method != "unavailable" for method in methods[1:])
    ):
        methods[0] = "breed"
        for index, (node, parent_index) in enumerate(order[1:], start=1):
            if methods[index] == "unavailable":
                methods[index] = resolve(node, parent_index)

    return {int(node["id"]): methods[index] for index, (node, _) in enumerate(order)}


def load_details(details_dir: Path) -> dict[int, dict]:
    details: dict[int, dict] = {}
    for path in sorted(details_dir.glob("*.json"), key=lambda p: int(p.stem)):
        payload = json.loads(path.read_text(encoding="utf-8"))
        details[int(payload["summary"]["id"])] = payload
    return details


def build_index(details: dict[int, dict]) -> dict:
    chains: dict[int, dict] = {}
    catchable_by_version: dict[str, set[int]] = {}
    for species_id, detail in details.items():
        chain = detail.get("evolutionChain")
        if chain:
            chains.setdefault(int(chain["id"]), chain)
        for version, entries in (detail.get("obtainLocationsByVersion") or {}).items():
            if entries:
                catchable_by_version.setdefault(version, set()).add(species_id)

    selections: dict[str, tuple[set[str], bool]] = {}
    for group, versions in VERSION_GROUPS.items():
        selections[f"@{group}"] = (set(versions), group not in NO_BREEDING)
        for version in versions:
            selections[version] = (
                accessible_versions(version),
                group not in NO_BREEDING,
            )

    by_selection: dict[str, list[int]] = {}
    for selection, (versions, supports_breeding) in selections.items():
        catchable: set[int] = set()
        for version in versions:
            catchable.update(catchable_by_version.get(version, set()))
        needs_chain: set[int] = set()
        for chain in chains.values():
            plan = plan_chain(chain, catchable, supports_breeding)
            needs_chain.update(
                species_id
                for species_id, method in plan.items()
                if method in {"evolve", "trade", "breed"}
            )
        by_selection[selection] = sorted(needs_chain)

    return {"version": 1, "bySelection": by_selection}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--details", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    payload = build_index(load_details(args.details))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(
        f"wrote {args.output} "
        f"({len(payload['bySelection'])} selections, {args.output.stat().st_size} bytes)"
    )


if __name__ == "__main__":
    main()
