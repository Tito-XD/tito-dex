#!/usr/bin/env python3
"""Keep generated Flutter dex-axis labels synchronized with canonical JSON."""

from __future__ import annotations

import json
import unittest

from generate_dex_axis_labels import OUTPUT, SOURCE, render


class GenerateDexAxisLabelsTest(unittest.TestCase):
    def test_checked_in_dart_matches_canonical_source(self) -> None:
        source = json.loads(SOURCE.read_text(encoding="utf-8"))
        self.assertEqual(OUTPUT.read_text(encoding="utf-8"), render(source))

    def test_all_axis_labels_are_nonempty(self) -> None:
        source = json.loads(SOURCE.read_text(encoding="utf-8"))
        self.assertEqual(set(source), {"shape", "color", "growthRate", "habitat"})
        for labels in source.values():
            self.assertTrue(labels)
            self.assertTrue(all(slug and label.strip() for slug, label in labels.items()))


if __name__ == "__main__":
    unittest.main()
