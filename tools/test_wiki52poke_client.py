#!/usr/bin/env python3

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from typing import Any

from wiki52poke_client import Wiki52PokeClient


class _Response:
    def __init__(self, value: dict[str, Any]) -> None:
        self._value = value

    def raise_for_status(self) -> None:
        return None

    def json(self) -> dict[str, Any]:
        return self._value


class _Session:
    def __init__(self, responses: list[dict[str, Any]]) -> None:
        self.headers: dict[str, str] = {}
        self.responses = list(responses)
        self.calls: list[dict[str, str]] = []

    def get(self, _url: str, *, params: dict[str, str], timeout: int) -> _Response:
        self.calls.append(params)
        return _Response(self.responses.pop(0))


class Wiki52PokeClientTest(unittest.TestCase):
    def test_reads_latest_revision_without_parse(self) -> None:
        session = _Session(
            [
                {
                    "query": {
                        "pages": [
                            {
                                "title": "利欧路",
                                "revisions": [
                                    {
                                        "revid": 123,
                                        "timestamp": "2026-08-01T00:00:00Z",
                                        "slots": {"main": {"content": "source"}},
                                    }
                                ],
                            }
                        ]
                    }
                }
            ]
        )
        client = Wiki52PokeClient(session=session)

        revision = client.latest_revision("利欧路")

        self.assertIsNotNone(revision)
        assert revision is not None
        self.assertEqual(revision.revision_id, 123)
        self.assertEqual(revision.content, "source")
        self.assertEqual(session.calls[0]["action"], "query")
        self.assertEqual(session.calls[0]["prop"], "revisions")
        self.assertNotIn("parse", session.calls[0].values())

    def test_serializes_requests_after_previous_completion(self) -> None:
        session = _Session(
            [
                {"query": {"search": []}},
                {"query": {"search": []}},
            ]
        )
        clock = [10.0]
        sleeps: list[float] = []

        def monotonic() -> float:
            return clock[0]

        def sleeper(seconds: float) -> None:
            sleeps.append(seconds)
            clock[0] += seconds

        client = Wiki52PokeClient(
            session=session,
            minimum_interval=0.55,
            monotonic=monotonic,
            sleeper=sleeper,
        )
        client.search_titles("test")
        clock[0] += 0.1
        client.search_titles("test 2")

        self.assertEqual(len(sleeps), 1)
        self.assertAlmostEqual(sleeps[0], 0.45)

    def test_uses_revision_cache_without_another_request(self) -> None:
        session = _Session(
            [
                {
                    "query": {
                        "pages": [
                            {
                                "title": "利欧路",
                                "revisions": [
                                    {
                                        "revid": 123,
                                        "timestamp": "2026-08-01T00:00:00Z",
                                        "slots": {"main": {"content": "source"}},
                                    }
                                ],
                            }
                        ]
                    }
                }
            ]
        )
        with tempfile.TemporaryDirectory() as temporary:
            client = Wiki52PokeClient(
                session=session,
                cache_dir=Path(temporary),
            )
            first = client.latest_revision("利欧路")
            second = client.latest_revision("利欧路")

        self.assertEqual(first, second)
        self.assertEqual(len(session.calls), 1)


if __name__ == "__main__":
    unittest.main()
