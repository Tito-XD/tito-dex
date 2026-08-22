#!/usr/bin/env python3

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from build_dex_v20_candidate import (
    build_candidate,
    build_entity_index,
    tree_fingerprint,
)
from verify_dex_v20_candidate import verify_candidate


GENERATED_AT = "2026-08-22T00:00:00+00:00"


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")


class DexV20FoundationTests(unittest.TestCase):
    def _make_base(self, root: Path) -> tuple[Path, Path]:
        staging = root / "v19" / "staging"
        details = staging / "details"
        labels = staging / "l10n" / "zh"
        details.mkdir(parents=True)
        labels.mkdir(parents=True)
        summaries = [
            {"id": 1, "nameZh": "妙蛙种子", "nameEn": "Bulbasaur", "types": ["grass", "poison"]},
            {"id": 2, "nameZh": "妙蛙草", "nameEn": "Ivysaur", "types": ["grass", "poison"]},
        ]
        for summary in summaries:
            write_json(
                details / f"{summary['id']}.json",
                {
                    "summary": summary,
                    "moveSet": {"levelUp": [{"moveId": 1}]},
                    "moveSets": {},
                    "abilities": [{"nameZh": "茂盛", "nameEn": "Overgrow"}],
                    "heldItems": [{"slug": "master-ball"}],
                    "evolutionChain": {"id": summary["id"], "children": []},
                },
            )
        moves = {
            "1": {"id": 1, "nameZh": "拍击", "nameEn": "Pound", "type": "normal", "pp": 35}
        }
        abilities = {
            "65": {"nameZh": "茂盛", "nameEn": "Overgrow", "pokemonIds": [1, 2]}
        }
        items = {
            "2278": {
                "id": 2278,
                "slug": "master-ball",
                "nameZh": "大师球",
                "nameEn": "Master Ball",
            }
        }
        write_json(staging / "summaries.json", summaries)
        write_json(staging / "moves.json", moves)
        write_json(staging / "abilities.json", abilities)
        write_json(staging / "items.json", items)
        write_json(
            staging / "dex_catalog.json",
            {
                "version": 1,
                "summaries": [{**summaries[0], "nameZh": "旧名字"}, summaries[1]],
                "moves": moves,
                "abilities": abilities,
                "moveLearners": {"1": [1, 2]},
                "abilityPokemonIds": {"65": [1, 2]},
                "eggGroups": {},
            },
        )
        write_json(staging / "games.json", [{"slug": "rb", "versionGroup": "red-blue"}])
        write_json(
            staging / "manifest.json",
            {
                "version": 19,
                "complete": False,
                "downloadedAt": "2026-08-08T00:00:00+00:00",
                "pokemonCount": 2,
                "moveCount": 1,
                "abilityCount": 1,
                "itemCount": 1,
                "schemaFeatures": {},
            },
        )
        write_json(
            labels / "species_labels.json",
            {
                "1": {"zh": "妙蛙种子", "en": "Bulbasaur"},
                "2": {"zh": "妙蛙草", "en": "Ivysaur"},
                "9999": {"zh": "幻影物种", "en": "Phantom"},
            },
        )
        write_json(
            labels / "moves_labels.json",
            {
                "1": {"zh": "拍击", "en": "Pound"},
                "9999": {"zh": "幻影招式", "en": "Phantom Move"},
            },
        )
        write_json(
            labels / "abilities_labels.json",
            {"65": {"zh": "茂盛", "en": "Overgrow"}},
        )
        # Item labels retain upstream IDs, while the full runtime catalog can
        # use a different numeric ID. The name match must join them safely.
        write_json(
            labels / "items_labels.json",
            {
                "1": {"zh": "大师球", "en": "Master Ball"},
                "9999": {"zh": "幻影道具", "en": "Phantom Item"},
            },
        )
        (staging / "ITEMS_ATTRIBUTION.txt").write_text("fixture notice", encoding="utf-8")
        root_manifest = root / "v19" / "upload" / "bundle-manifest.json"
        write_json(
            root_manifest,
            {
                "bundleVersion": 19,
                "cdnPrefix": "v5",
                "complete": True,
                "archiveUrl": "https://private.invalid/v5/bundle-v19.tar.zst",
                "publishedAt": "2026-08-08T00:00:00+00:00",
            },
        )
        return staging, root_manifest

    def test_build_is_additive_and_keeps_root_manifest_pending(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            base, base_root_manifest = self._make_base(root)
            before = tree_fingerprint(base)
            output = root / "candidate"
            report = build_candidate(
                base_staging=base,
                base_root_manifest=base_root_manifest,
                output=output,
                generated_at=GENERATED_AT,
                build_archive=False,
            )

            self.assertEqual(tree_fingerprint(base), before)
            self.assertTrue(report["baseUnchanged"])
            self.assertFalse((output / "upload" / "bundle-manifest.json").exists())
            pending = json.loads(
                (output / "release-manifest" / "bundle-manifest.v20.candidate.json").read_text()
            )
            self.assertNotIn("archiveUrl", pending)
            self.assertEqual(pending["releaseState"], "candidate")

            staging = output / "staging"
            summaries = json.loads((staging / "summaries.json").read_text())
            catalog = json.loads((staging / "dex_catalog.json").read_text())
            self.assertEqual(catalog["summaries"], summaries)
            self.assertEqual(report["repairedDerivedObjects"], ["dex_catalog.json#/summaries"])

            index = json.loads((staging / "entity_index.json").read_text())
            master_ball = next(
                entity for entity in index["entities"] if entity["kind"] == "item"
            )
            self.assertEqual(master_ball["stableId"], "item:master-ball")
            self.assertEqual(master_ball["id"], 2278)
            overgrow = next(
                entity for entity in index["entities"] if entity["kind"] == "ability"
            )
            self.assertEqual(overgrow["ref"]["path"], "abilities.json")
            self.assertEqual(index["audit"]["phantomLabels"]["item"][0]["labelId"], "9999")
            self.assertEqual(index, build_entity_index(staging, generated_at=GENERATED_AT))

            provenance = json.loads((staging / "provenance.json").read_text())
            moves_rule = max(
                (
                    rule
                    for rule in provenance["objects"]
                    if rule["pathPattern"] in {"*.json", "moves.json"}
                ),
                key=lambda rule: rule["priority"],
            )
            self.assertEqual(
                moves_rule["metadata"]["freshness"]["fallbackPolicy"],
                "local-evidence",
            )

    def test_rejects_v20_output_inside_v19(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            base, base_root_manifest = self._make_base(root)
            with self.assertRaisesRegex(ValueError, "must not contain"):
                build_candidate(
                    base_staging=base,
                    base_root_manifest=base_root_manifest,
                    output=base / "candidate",
                    generated_at=GENERATED_AT,
                    build_archive=False,
                )

    def test_overlay_requires_and_merges_field_provenance(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            base, base_root_manifest = self._make_base(root)
            overlay = root / "move-overlay"
            overlay.mkdir()
            moves = json.loads((base / "moves.json").read_text())
            moves["1"]["descriptionZh"] = "用身体拍打对手进行攻击。"
            write_json(overlay / "moves.json", moves)
            evidence = {
                "sourceIds": ["fixture-move-source"],
                "method": "normalized",
                "confidence": "high",
                "scope": {"level": "versionGroup", "versionGroups": ["red-blue"]},
                "freshness": {
                    "class": "versionSensitive",
                    "status": "current",
                    "checkedAt": GENERATED_AT,
                    "sourceAsOf": GENERATED_AT,
                    "maxAgeDays": None,
                    "fallbackPolicy": "local-evidence",
                },
            }
            write_json(
                overlay / "overlay-provenance.json",
                {
                    "schemaVersion": 1,
                    "overlayId": "fixture-moves-v2",
                    "baseBundleVersion": 19,
                    "sources": {
                        "fixture-move-source": {
                            "title": "Fixture move source",
                            "kind": "derived",
                            "revision": "fixture-1",
                            "license": "project source license",
                            "attributionRequired": False,
                            "noticePaths": [],
                        }
                    },
                    "objects": [
                        {
                            "pathPattern": "moves.json",
                            "priority": 20,
                            "metadata": evidence,
                            "fields": [],
                        }
                    ],
                },
            )
            output = root / "candidate"
            report = build_candidate(
                base_staging=base,
                base_root_manifest=base_root_manifest,
                output=output,
                generated_at=GENERATED_AT,
                build_archive=False,
                overlay_dirs=[overlay],
            )
            built_moves = json.loads((output / "staging" / "moves.json").read_text())
            self.assertEqual(built_moves["1"]["descriptionZh"], "用身体拍打对手进行攻击。")
            self.assertEqual(report["overlays"], [{"overlayId": "fixture-moves-v2", "files": 1}])
            provenance = json.loads((output / "staging" / "provenance.json").read_text())
            self.assertIn("fixture-move-source", provenance["sources"])
            self.assertTrue(
                any(
                    rule["pathPattern"] == "moves.json" and rule["priority"] == 20
                    for rule in provenance["objects"]
                )
            )

    def test_full_fixture_archive_and_validator(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            base, base_root_manifest = self._make_base(root)
            output = root / "candidate"
            build_candidate(
                base_staging=base,
                base_root_manifest=base_root_manifest,
                output=output,
                generated_at=GENERATED_AT,
                build_archive=True,
            )
            summary = verify_candidate(output)
            self.assertEqual(summary["bundleVersion"], 20)
            self.assertEqual(summary["entities"], 5)
            self.assertFalse(summary["publishableRootManifestPresent"])

    def test_contract_schemas_are_strict(self) -> None:
        repo = Path(__file__).resolve().parents[1]
        for name in (
            "bundle_overlay.schema.json",
            "bundle_provenance.schema.json",
            "entity_index.schema.json",
        ):
            schema = json.loads((repo / "data" / "dex" / name).read_text())
            self.assertEqual(schema["$schema"], "https://json-schema.org/draft/2020-12/schema")
            self.assertFalse(schema["additionalProperties"])


if __name__ == "__main__":
    unittest.main()
