#!/usr/bin/env python3

from __future__ import annotations

import unittest

from fetch_52poke_location_zh import (
    _fetch_bulbapedia_zh_langlink,
    _normalize_label,
    _resolve_redirect_title_zh,
)


class _Response:
    status_code = 200
    text = "{}"

    def json(self) -> dict:
        return {
            "query": {
                "pages": [
                    {"pageid": 61162, "title": "名水鎮"},
                ]
            }
        }


class _Session:
    last_url = ""

    def get(self, url: str, timeout: int) -> _Response:
        self.last_url = url
        return _Response()


class _LanglinkResponse(_Response):
    def json(self) -> dict:
        return {
            "query": {
                "pages": [
                    {"pageid": 200579, "langlinks": [{"lang": "zh", "title": "弓形島"}]},
                ]
            }
        }


class _LanglinkSession(_Session):
    def get(self, url: str, timeout: int) -> _LanglinkResponse:
        self.last_url = url
        return _LanglinkResponse()


class Fetch52PokeLocationZhTests(unittest.TestCase):
    def test_redirect_title_is_normalized_to_zh_hans(self) -> None:
        session = _Session()
        label, blocked = _resolve_redirect_title_zh(session, "Aquacorde Town")
        self.assertFalse(blocked)
        self.assertEqual(label, "名水镇")
        self.assertIn("redirects=1", session.last_url)

    def test_normalize_converts_traditional_characters(self) -> None:
        self.assertEqual(_normalize_label("阿卡拉島郊外"), "阿卡拉岛郊外")

    def test_bulbapedia_langlink_returns_zh_hans_title(self) -> None:
        session = _LanglinkSession()
        label, blocked = _fetch_bulbapedia_zh_langlink(session, "Crescent Isle")
        self.assertFalse(blocked)
        self.assertEqual(label, "弓形岛")
        self.assertIn("lllang=zh", session.last_url)


if __name__ == "__main__":
    unittest.main()
