#!/usr/bin/env python3

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class Wiki52PokeSourcePolicyTest(unittest.TestCase):
    def test_registry_keeps_52poke_out_of_automatic_imports(self) -> None:
        registry = json.loads(
            (ROOT / "data/journey/sources/source_registry.json").read_text(
                encoding="utf-8"
            )
        )
        source = next(
            item for item in registry["sources"] if item["sourceId"] == "wiki52poke"
        )
        self.assertFalse(source["acquisition"]["automatedImport"])
        self.assertEqual(source["allowedUses"], ["fact_check"])

    def test_active_text_clients_do_not_use_action_parse(self) -> None:
        names = [
            "enrich_items_52poke.py",
            "enrich_items_52poke_search.py",
            "enrich_items_v19.py",
            "fetch_52poke_flavor_text.py",
            "build_item_version_matrix.py",
        ]
        action_parse = re.compile(
            r"(?:['\"]action['\"]\s*:\s*['\"]parse['\"]|action=parse)"
        )
        for name in names:
            text = (ROOT / "tools" / name).read_text(encoding="utf-8")
            self.assertIsNone(action_parse.search(text), name)

    def test_item_matrix_waits_more_than_half_a_second(self) -> None:
        text = (ROOT / "tools/build_item_version_matrix.py").read_text(
            encoding="utf-8"
        )
        self.assertIn("time.sleep(0.55)", text)


if __name__ == "__main__":
    unittest.main()
