#!/usr/bin/env python3
"""Verify v20 gameplay sidecars and HGSS/BDSP/SV golden records."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


EXPECTED_POKEAPI_COMMIT = "cd40ffdf0f5c68fc81c39c2ebec256e128fe1966"
EXPECTED_PKHEX_COMMIT = "5c9e949c9f0fa932a1b63511b32c2bee5ce75b4e"
STATUS_VALUES = {"covered", "notApplicable", "unknown"}
COVERAGE_FIELDS = {
    "wild",
    "fixed",
    "raid",
    "gift",
    "inGameTrade",
    "egg",
    "evolution",
    "transfer",
    "unavailable",
    "learnMethods",
    "itemStoryUsage",
    "exactTriggerApplicability",
}


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def find_machine(
    learn: dict[str, Any], group: str, move: str, kind: str, number: int
) -> dict[str, Any]:
    matches = [
        row
        for row in learn["machineMappingsByVersionGroup"][group][move]
        if row["kind"] == kind and row["number"] == number
    ]
    assert len(matches) == 1
    return matches[0]


def verify(staging: Path) -> dict[str, Any]:
    root = staging / "gameplay"
    obtain = read_json(root / "obtain_methods.json")
    evolution = read_json(root / "evolution_methods.json")
    learn = read_json(root / "learn_methods.json")
    story = read_json(root / "item_story_usage.json")
    coverage = read_json(root / "version_coverage.json")
    version_keys = read_json(root / "game_version_keys.json")
    source_lock = read_json(root / "gameplay_sources.json")
    audit = read_json(root / "gameplay_v20_audit.json")

    groups = version_keys["canonicalGroups"]
    assert len(groups) == 23
    assert len({row["key"] for row in groups}) == 23
    exact_versions = [version for row in groups for version in row["exactVersions"]]
    assert len(exact_versions) == 51
    assert len(set(exact_versions)) == 51
    assert version_keys["aliases"]["legends-z-a"] == "legends-za"
    pkhex_lock = next(
        row for row in source_lock["sources"] if row["sourceId"] == "pkhex-overlay"
    )
    assert pkhex_lock["commit"] == EXPECTED_PKHEX_COMMIT
    assert set(coverage["coverage"]) == {row["key"] for row in groups}
    for group, modes in coverage["coverage"].items():
        assert set(modes) == COVERAGE_FIELDS, group
        assert set(modes.values()) <= STATUS_VALUES, group
    assert all(value == "notApplicable" for value in coverage["coverage"]["champions"].values())

    assert obtain["sourceCommit"] == EXPECTED_POKEAPI_COMMIT
    assert len(obtain["species"]) == 1025
    for species in obtain["species"].values():
        assert set(species["verifiedRouteByVersionGroup"]) == set(coverage["coverage"])
        assert set(species["derivedFamilyRouteByVersionGroup"]) == set(
            coverage["coverage"]
        )
        assert set(species["verifiedRouteByVersionGroup"].values()) <= {
            "direct",
            "notApplicable",
            "unknown",
        }
        for exact, direct in species["byExactVersion"].items():
            assert exact in exact_versions
            assert direct["methods"]
            assert direct["encounterCount"] > 0
            assert direct["detailRef"].startswith("details/")
            for source in direct["sources"]:
                if source["sourceId"] == "pokeapi-api-data":
                    assert source["commit"] == EXPECTED_POKEAPI_COMMIT
                else:
                    assert source["sourceId"] == "pkhex-overlay"
                    assert source["commit"] == EXPECTED_PKHEX_COMMIT

    # HGSS: a pinned API encounter and an HM mapping.
    pikachu_hgss = obtain["species"]["25"]
    assert (
        pikachu_hgss["verifiedRouteByVersionGroup"]["heartgold-soulsilver"]
        == "direct"
    )
    assert "wild" in pikachu_hgss["byExactVersion"]["heartgold"]["methods"]
    cut = find_machine(learn, "heartgold-soulsilver", "move:15", "HM", 1)
    assert cut["itemStableId"] == "item:397"

    # BDSP: PKHeX-pinned wild data is exact, but an unrepresented Riolu gift
    # stays unknown instead of being invented.
    bidoof_bdsp = obtain["species"]["399"]
    assert (
        bidoof_bdsp["verifiedRouteByVersionGroup"][
            "brilliant-diamond-shining-pearl"
        ]
        == "direct"
    )
    assert (
        bidoof_bdsp["byExactVersion"]["brilliant-diamond"]["sources"][0][
            "commit"
        ]
        == EXPECTED_PKHEX_COMMIT
    )
    assert (
        obtain["species"]["447"]["verifiedRouteByVersionGroup"][
            "brilliant-diamond-shining-pearl"
        ]
        == "unknown"
    )

    # SV: Riolu is directly verified and TM88 links stable move/item IDs; the
    # recipe is intentionally unknown in the allowed source set.
    riolu_sv = obtain["species"]["447"]
    assert riolu_sv["verifiedRouteByVersionGroup"]["scarlet-violet"] == "direct"
    assert set(riolu_sv["byExactVersion"]["violet"]["methods"]) == {
        "fixed",
        "raid",
        "wild",
    }
    swords_dance = find_machine(learn, "scarlet-violet", "move:14", "TM", 88)
    assert swords_dance["machineStableId"] == "machine:1903"
    assert swords_dance["itemStableId"] == "item:392"
    assert swords_dance["recipeStatus"] == "unknown"

    assert learn["sourceCommit"] == EXPECTED_POKEAPI_COMMIT
    assert len(learn["species"]) == 1025
    assert len(evolution["transitions"]) >= 480
    for transition in evolution["transitions"]:
        assert set(transition["applicabilityByVersionGroup"]) == set(
            coverage["coverage"]
        )
        assert set(transition["applicabilityByVersionGroup"].values()) <= {
            "notApplicable",
            "unknown",
        }
        for trigger in transition["triggers"]:
            if trigger.get("tradeSpecies"):
                assert trigger["tradeSpeciesResolution"] == "resolved"
                assert trigger["tradeSpeciesStableId"].startswith("pokemon:")

    assert story["unresolved"] == []
    assert len(story["links"]) == 9
    assert "held items are never" in story["guardrail"]
    assert all(
        link["source"]["sourceId"] == "reviewed-progression-requirement"
        for link in story["links"]
    )

    actual_coverage = Counter(
        status
        for modes in coverage["coverage"].values()
        for field, status in modes.items()
        if field != "exactTriggerApplicability"
    )
    assert audit["coverageStatusDistribution"] == dict(sorted(actual_coverage.items()))
    assert audit["canonicalVersionGroups"] == 23
    assert audit["exactVersions"] == 51
    assert audit["overlayVersions"] == 17
    assert audit["storyItemUnresolved"] == []
    assert audit["unverifiedEncounterRowsDropped"] == sum(
        audit["unverifiedEncounterRowsByVersion"].values()
    )

    return {
        "canonicalVersionGroups": 23,
        "exactVersions": 51,
        "verifiedDirectSpeciesVersionPairs": audit[
            "verifiedDirectSpeciesVersionPairs"
        ],
        "routeDistribution": audit["routeDistribution"],
        "unknownRoutesByVersionGroup": audit["unknownRoutesByVersionGroup"],
        "coverageStatusDistribution": audit["coverageStatusDistribution"],
        "goldens": ["HGSS", "BDSP", "SV"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("staging", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.staging), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
