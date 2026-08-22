#!/usr/bin/env python3
"""Validate a local v20 reference-data candidate without publishing it."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


EXPECTED_SOURCE_COMMIT = "cd40ffdf0f5c68fc81c39c2ebec256e128fe1966"


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def verify(root: Path) -> dict[str, Any]:
    manifest = read_json(root / "manifest.json")
    audit = read_json(root / "reference_v20_audit.json")
    sources = read_json(root / "reference_v20_sources.json")
    moves = read_json(root / "moves.json")
    abilities = read_json(root / "abilities.json")
    items = read_json(root / "items.json")
    catalog = read_json(root / "dex_catalog.json")
    types = read_json(root / "types.json")
    statuses = read_json(root / "status_conditions.json")
    weather = read_json(root / "weather.json")
    terrains = read_json(root / "terrains.json")
    move_version_matrix = read_json(root / "move_version_matrix.json")
    item_version_matrix = read_json(root / "item_version_matrix.json")

    assert manifest["version"] == 20
    assert manifest["complete"] is True
    assert manifest["referenceDataReviewStatus"] == "candidate"
    assert manifest["referenceDataSourceCommit"] == EXPECTED_SOURCE_COMMIT
    assert manifest["schemaFeatures"]["moveDetails"] == 2
    assert manifest["schemaFeatures"]["abilityDetails"] == 2
    assert manifest["schemaFeatures"]["itemDetails"] == 2
    assert manifest["schemaFeatures"]["generationMechanics"] == 1
    assert manifest["moveVersionMatrix"] == "move_version_matrix.json"
    assert manifest["itemVersionMatrix"] == "item_version_matrix.json"
    pinned = next(
        source for source in sources["sources"] if source["sourceId"] == "pokeapi-api-data"
    )
    assert pinned["commit"] == EXPECTED_SOURCE_COMMIT

    assert len(moves) >= 937
    assert len(abilities) >= 373
    assert len(items) == 2130
    assert len(types) == 18
    assert len(statuses) == 22
    assert len(weather) == 10
    assert len(terrains) == 4
    assert len(move_version_matrix["moves"]) >= 830
    assert item_version_matrix["coverage"]["versionedItems"] >= 1400
    assert catalog["version"] == 2
    assert catalog["moves"] == moves
    assert catalog["abilities"] == abilities

    for move_id, move in moves.items():
        assert move["stableId"] == f"move:{move_id}"
        assert move["slug"]
        assert move["generation"]
        assert move["target"]
        assert move["priority"] is not None
        assert move["provenance"]["sourceCommit"] == EXPECTED_SOURCE_COMMIT
    for ability_id, ability in abilities.items():
        assert ability["stableId"] == f"ability:{ability_id}"
        assert ability["slug"]
        assert ability["generation"]
        assert ability["provenance"]["sourceCommit"] == EXPECTED_SOURCE_COMMIT
    for item in items.values():
        if not item.get("stableId"):
            continue
        assert item["stableId"] == f"item:{item['id']}"
        assert item["provenance"]["sourceCommit"] == EXPECTED_SOURCE_COMMIT

    swords_dance = moves["14"]
    assert swords_dance["descriptionZh"]
    assert swords_dance["shortEffect"]
    assert swords_dance["history"]
    assert any(row["versionGroup"] == "scarlet-violet" for row in swords_dance["machines"])
    bind = moves["20"]
    assert bind["history"][0]["changedInVersionGroup"] == "black-white"
    stench = abilities["1"]
    assert stench["descriptionZh"]
    assert stench["history"]
    assert 44 in stench["pokemonIds"]
    assert any(row["pokemonSlug"] == "garbodor-gmax" for row in stench["pokemonAssignments"])

    item_by_slug = {item["slug"]: item for item in items.values()}
    tm01 = item_by_slug["tm01"]
    assert tm01["descriptionZh"]
    assert any(row["versionGroup"] == "heartgold-soulsilver" for row in tm01["machines"])
    assert any(row["versionGroup"] == "scarlet-violet" for row in tm01["machines"])
    assert item_by_slug["choice-band"]["flingPower"] == 10

    assert statuses[0]["descriptionZh"]
    assert all(row["descriptionZh"] for row in weather)
    assert all(row["descriptionZh"] for row in terrains)
    assert types["steel"]["history"]
    assert types["fairy"]["generation"] == 6

    assert audit["sourceCommit"] == EXPECTED_SOURCE_COMMIT
    assert audit["moves"]["records"] == len(moves)
    assert audit["abilities"]["records"] == len(abilities)
    assert audit["items"]["records"] == len(items)
    assert audit["moves"]["description"] >= 900
    assert audit["moves"]["chineseDescription"] >= 800
    assert audit["moves"]["machineMapped"] >= 350
    assert audit["moves"]["versionGroupAvailability"] >= 830
    assert audit["abilities"]["description"] >= 300
    assert audit["items"]["matchedToPinnedSource"] >= 2100
    assert audit["items"]["versionGroupAvailability"] >= 1400
    assert audit["items"]["auditedVersionPrices"] >= 1100

    return {
        "bundleVersion": manifest["version"],
        "sourceCommit": audit["sourceCommit"],
        "moves": audit["moves"],
        "abilities": audit["abilities"],
        "items": audit["items"],
        "mechanics": audit["mechanics"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("staging", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.staging), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
