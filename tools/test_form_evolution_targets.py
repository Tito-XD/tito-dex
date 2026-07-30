#!/usr/bin/env python3
"""Unit tests for the per-form evolution chain pass.

The important one is :class:`MirrorTests`: the curated table exists twice, once
for the builder and once for the app's older-bundle fallback, and a chain that
disagrees between them is worse than no chain at all.
"""

from __future__ import annotations

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from form_evolution_chains import (  # noqa: E402
    FORM_EVOLUTION_TARGETS,
    DetailStore,
    apply_form_evolution_chains,
    chain_for_form,
    root_form_key,
)

ROOT = Path(__file__).resolve().parents[1]
DART_TABLE = (
    ROOT / "flutter" / "lib" / "features" / "dex" / "form_evolution_targets.dart"
)


def _node(species_id, name_en, name_zh, children=()):
    return {
        "id": species_id,
        "nameEn": name_en,
        "nameZh": name_zh,
        "localSpritePath": f"sprites/{species_id}.png",
        "children": list(children),
    }


def _form(key, name_zh, *, is_default=False, is_cosmetic=False, sprite=None):
    entry = {
        "key": key,
        "nameZh": name_zh,
        "isDefault": is_default,
        "isCosmetic": is_cosmetic,
    }
    if sprite:
        entry["localSpritePath"] = sprite
    return entry


GROWLITHE_CHAIN = _node(
    58, "Growlithe", "卡蒂狗", [_node(59, "Arcanine", "风速狗")]
)
WOOPER_CHAIN = _node(
    194,
    "Wooper",
    "乌波",
    [_node(195, "Quagsire", "沼王"), _node(980, "Clodsire", "土王")],
)


def _tree(details: dict[int, dict]) -> Path:
    directory = Path(tempfile.mkdtemp())
    for species_id, detail in details.items():
        (directory / f"{species_id}.json").write_text(
            json.dumps(detail, ensure_ascii=False), encoding="utf-8"
        )
    return directory


class RootFormKeyTests(unittest.TestCase):
    def test_form_on_the_root_species(self):
        self.assertEqual(
            root_form_key(GROWLITHE_CHAIN, "growlithe-hisui"), "growlithe-hisui"
        )

    def test_form_further_down_maps_back_by_suffix(self):
        self.assertEqual(
            root_form_key(GROWLITHE_CHAIN, "arcanine-hisui"), "growlithe-hisui"
        )

    def test_default_form_deeper_in_the_chain_still_prunes_the_root(self):
        zigzagoon = _node(263, "Zigzagoon", "蛇纹熊")
        self.assertEqual(root_form_key(zigzagoon, "linoone"), "zigzagoon")

    def test_unlisted_form_is_left_alone(self):
        self.assertIsNone(root_form_key(GROWLITHE_CHAIN, "growlithe-gmax"))


class ChainForFormTests(unittest.TestCase):
    def test_hisuian_growlithe_reaches_the_hisuian_arcanine(self):
        store = DetailStore(
            _tree(
                {
                    58: {
                        "forms": [
                            _form("growlithe", "卡蒂狗", is_default=True),
                            _form(
                                "growlithe-hisui",
                                "卡蒂狗（洗翠的样子）",
                                sprite="sprites/forms/10398.png",
                            ),
                        ]
                    },
                    59: {
                        "forms": [
                            _form("arcanine", "风速狗", is_default=True),
                            _form(
                                "arcanine-hisui",
                                "风速狗（洗翠的样子）",
                                sprite="sprites/forms/10399.png",
                            ),
                        ]
                    },
                }
            )
        )
        problems: list[str] = []
        chain = chain_for_form(GROWLITHE_CHAIN, "growlithe-hisui", store, problems)

        self.assertEqual(problems, [])
        self.assertEqual(chain["nameZh"], "卡蒂狗（洗翠的样子）")
        self.assertEqual(chain["localSpritePath"], "sprites/forms/10398.png")
        child = chain["children"][0]
        self.assertEqual(child["nameZh"], "风速狗（洗翠的样子）")
        self.assertEqual(child["formKey"], "arcanine-hisui")
        self.assertEqual(child["localSpritePath"], "sprites/forms/10399.png")

    def test_paldean_wooper_drops_the_quagsire_branch(self):
        store = DetailStore(_tree({194: {"forms": []}}))
        problems: list[str] = []
        chain = chain_for_form(WOOPER_CHAIN, "wooper-paldea", store, problems)
        self.assertEqual([c["id"] for c in chain["children"]], [980])

    def test_default_wooper_drops_the_clodsire_branch(self):
        store = DetailStore(_tree({194: {"forms": []}}))
        chain = chain_for_form(WOOPER_CHAIN, "wooper", store, [])
        self.assertEqual([c["id"] for c in chain["children"]], [195])

    def test_unlisted_form_keeps_the_whole_species_chain(self):
        store = DetailStore(_tree({194: {"forms": []}}))
        chain = chain_for_form(WOOPER_CHAIN, "wooper-gmax", store, [])
        self.assertEqual([c["id"] for c in chain["children"]], [195, 980])

    def test_a_missing_variant_is_reported_not_swallowed(self):
        store = DetailStore(_tree({58: {"forms": []}, 59: {"forms": []}}))
        problems: list[str] = []
        chain_for_form(GROWLITHE_CHAIN, "growlithe-hisui", store, problems)
        self.assertTrue(any("arcanine-hisui" in problem for problem in problems))


class ApplyTests(unittest.TestCase):
    def test_every_non_cosmetic_form_gains_a_chain(self):
        directory = _tree(
            {
                58: {
                    "evolutionChain": GROWLITHE_CHAIN,
                    "forms": [
                        _form("growlithe", "卡蒂狗", is_default=True),
                        _form("growlithe-hisui", "卡蒂狗（洗翠的样子）"),
                        _form("growlithe-cosmetic", "卡蒂狗", is_cosmetic=True),
                    ],
                },
                59: {"forms": [_form("arcanine-hisui", "风速狗（洗翠的样子）")]},
            }
        )
        touched, problems = apply_form_evolution_chains(directory)
        self.assertEqual(problems, [])
        self.assertEqual(touched, 2)

        forms = json.loads((directory / "58.json").read_text(encoding="utf-8"))["forms"]
        by_key = {form["key"]: form for form in forms}
        self.assertIn("evolutionChain", by_key["growlithe"])
        self.assertIn("evolutionChain", by_key["growlithe-hisui"])
        # Cosmetic forms inherit the species chain; no copy is written.
        self.assertNotIn("evolutionChain", by_key["growlithe-cosmetic"])


class MirrorTests(unittest.TestCase):
    """The Dart fallback table must match the builder's, entry for entry."""

    @staticmethod
    def _dart_table() -> dict[str, list[tuple[int, str | None]]]:
        source = DART_TABLE.read_text(encoding="utf-8")
        body = source.split("kFormEvolutionTargets = <String, List<FormEvolutionTarget>>{", 1)[1]
        # Strip comments so a species name inside one never parses as an entry.
        body = re.sub(r"//[^\n]*", "", body)
        table: dict[str, list[tuple[int, str | None]]] = {}
        for key, raw in re.findall(r"'([a-z0-9-]+)':\s*\[(.*?)\]", body, re.S):
            targets = []
            for species_id, suffix in re.findall(
                r"FormEvolutionTarget\((\d+)(?:,\s*'([a-z-]+)')?\)", raw
            ):
                targets.append((int(species_id), suffix or None))
            table[key] = targets
        return table

    def test_tables_agree(self):
        self.assertEqual(self._dart_table(), FORM_EVOLUTION_TARGETS)


if __name__ == "__main__":
    unittest.main()
