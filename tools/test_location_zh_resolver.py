#!/usr/bin/env python3
"""Tests for location Chinese resolver."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from location_zh_resolver import resolve_location_area_zh  # noqa: E402


class LocationZhResolverTest(unittest.TestCase):
    def test_route_slug(self) -> None:
        label, source = resolve_location_area_zh("route-29-area")
        self.assertEqual(label, "29号道路")
        self.assertEqual(source, "route_slug")

    def test_cherrygrove_slug_override(self) -> None:
        label, source = resolve_location_area_zh("cherrygrove-city-area")
        self.assertEqual(label, "吉花市")
        self.assertEqual(source, "slug_override")

    def test_cherrygrove_from_english(self) -> None:
        label, source = resolve_location_area_zh(
            "some-unknown-slug",
            area_name_en="Cherrygrove City",
            location_name_en="Cherrygrove City",
        )
        self.assertEqual(label, "吉花市")
        self.assertIn(source, {"name_en", "composite_en"})

    def test_floor_suffix(self) -> None:
        label, source = resolve_location_area_zh("ice-path-b1f")
        self.assertIn("冰雪小径", label)
        self.assertIn("B1F", label)
        self.assertIn(source, {"slug_floor", "slug_floor_name"})


if __name__ == "__main__":
    unittest.main()
