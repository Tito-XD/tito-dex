#!/usr/bin/env python3

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from audit_form_coverage import audit


class FormCoverageAuditTests(unittest.TestCase):
    def write_detail(self, root: Path, payload: dict) -> None:
        details = root / "details"
        details.mkdir(parents=True)
        (details / "194.json").write_text(
            json.dumps(payload, ensure_ascii=False), encoding="utf-8"
        )

    def test_valid_multiform_bundle_passes_strict_invariants(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "sprites/forms").mkdir(parents=True)
            (root / "sprites/forms/10477.png").write_bytes(b"png")
            self.write_detail(
                root,
                {
                    "summary": {"id": 194},
                    "forms": [
                        {
                            "key": "wooper",
                            "pokemonId": 194,
                            "formId": 194,
                            "nameZh": "乌波",
                            "kind": "form",
                            "isDefault": True,
                            "types": ["water", "ground"],
                            "baseStats": {"hp": 55},
                            "availableVersionGroups": ["scarlet-violet"],
                            "dataCompleteness": "complete",
                            "sources": ["https://pokeapi.co/api/v2/pokemon/194/"],
                        },
                        {
                            "key": "wooper-paldea",
                            "pokemonId": 10253,
                            "formId": 10477,
                            "nameZh": "乌波（帕底亚的样子）",
                            "kind": "regional",
                            "isDefault": False,
                            "types": ["poison", "ground"],
                            "baseStats": {"hp": 55},
                            "availableVersionGroups": ["scarlet-violet"],
                            "dataCompleteness": "complete",
                            "sources": ["https://pokeapi.co/api/v2/pokemon/10253/"],
                            "localSpritePath": "sprites/forms/10477.png",
                        },
                    ],
                    "obtainLocationsByVersion": {
                        "scarlet": [{
                            "pokemonId": 10253,
                            "formKey": "wooper-paldea",
                            "areaSlug": "south-province-area-one",
                        }],
                    },
                },
            )
            report = audit(root)
            self.assertTrue(report["ok"])
            self.assertEqual(report["bundlePokemonEntityCount"], 2)
            self.assertEqual(report["encounter"]["formLinked"], 1)

    def test_invalid_identity_and_inheritance_are_reported(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.write_detail(
                root,
                {
                    "summary": {"id": 194},
                    "forms": [{
                        "key": "bad-form",
                        "pokemonId": 20000,
                        "nameZh": "错误形态",
                        "kind": "battle",
                        "isDefault": False,
                        "inheritsFromDefault": True,
                    }],
                    "obtainLocationsByVersion": {
                        "scarlet": [{
                            "pokemonId": 20000,
                            "areaSlug": "test-area",
                        }],
                    },
                },
            )
            report = audit(root)
            self.assertFalse(report["ok"])
            self.assertEqual(report["errors"]["singleFormSpecies"], [194])
            self.assertEqual(report["errors"]["inheritanceErrors"], ["bad-form"])
            self.assertEqual(report["errors"]["encounterIdentityMismatchCount"], 1)


if __name__ == "__main__":
    unittest.main()
