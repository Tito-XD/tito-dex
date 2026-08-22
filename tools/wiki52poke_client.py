#!/usr/bin/env python3
"""Policy-compliant, build-time-only access to 52Poké MediaWiki.

This module deliberately exposes only the latest source revision and search.
It does not use ``action=parse`` and it serializes every request with a delay
after the previous response completed.  Callers must still respect TitoDex's
source registry: 52Poké is a manual fact-check source unless separate written
permission expands that scope.
"""

from __future__ import annotations

import json
import re
import threading
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Callable

import requests

WIKI_BASE = "https://wiki.52poke.com"
WIKI_API = f"{WIKI_BASE}/api.php"
USER_AGENT = "TitoDex-maintainer/1.0 (+https://github.com/Tito-XD/tito-dex)"
MIN_REQUEST_INTERVAL_SECONDS = 0.55


@dataclass(frozen=True)
class WikiRevision:
    title: str
    revision_id: int
    timestamp: str
    content: str

    @property
    def permalink(self) -> str:
        return f"{WIKI_BASE}/?oldid={self.revision_id}"


class Wiki52PokeClient:
    """Small serial MediaWiki client with optional revision cache."""

    def __init__(
        self,
        *,
        session: requests.Session | None = None,
        cache_dir: Path | None = None,
        minimum_interval: float = MIN_REQUEST_INTERVAL_SECONDS,
        monotonic: Callable[[], float] = time.monotonic,
        sleeper: Callable[[float], None] = time.sleep,
    ) -> None:
        if minimum_interval < 0.5:
            raise ValueError("52Poké requests must be separated by at least 500ms")
        self._session = session or requests.Session()
        self._session.headers.update(
            {
                "User-Agent": USER_AGENT,
                "Accept-Language": "zh-CN,zh;q=0.9",
            }
        )
        self._cache_dir = cache_dir
        self._minimum_interval = minimum_interval
        self._monotonic = monotonic
        self._sleeper = sleeper
        self._last_completed_at: float | None = None
        self._lock = threading.Lock()

    def latest_revision(self, title: str, *, force: bool = False) -> WikiRevision | None:
        cached = self._read_cache(title)
        if cached is not None and not force:
            return cached
        payload = self._request_json(
            {
                "action": "query",
                "prop": "revisions",
                "rvprop": "ids|timestamp|content",
                "rvslots": "main",
                "rvlimit": "1",
                "redirects": "1",
                "titles": title,
                "format": "json",
                "formatversion": "2",
            }
        )
        pages = payload.get("query", {}).get("pages", [])
        page = next((item for item in pages if not item.get("missing")), None)
        if not isinstance(page, dict):
            return None
        revisions = page.get("revisions") or []
        if not revisions:
            return None
        raw = revisions[0]
        slot = (raw.get("slots") or {}).get("main") or {}
        content = slot.get("content") or slot.get("*")
        revision_id = raw.get("revid")
        timestamp = raw.get("timestamp")
        if not isinstance(content, str) or not isinstance(revision_id, int):
            return None
        revision = WikiRevision(
            title=str(page.get("title") or title),
            revision_id=revision_id,
            timestamp=str(timestamp or ""),
            content=content,
        )
        self._write_cache(title, revision)
        return revision

    def search_titles(self, query: str, *, limit: int = 3) -> list[str]:
        payload = self._request_json(
            {
                "action": "query",
                "list": "search",
                "srsearch": query,
                "srlimit": str(max(1, min(limit, 5))),
                "srnamespace": "0",
                "format": "json",
                "formatversion": "2",
            }
        )
        return [
            str(item["title"])
            for item in payload.get("query", {}).get("search", [])
            if isinstance(item, dict) and item.get("title")
        ]

    def query(self, params: dict[str, str]) -> dict[str, Any]:
        """Run a serial read-only ``action=query`` request.

        This exists for narrowly scoped metadata such as ``imageinfo``. Source
        content must still be read through :meth:`latest_revision`.
        """
        values = dict(params)
        action = values.setdefault("action", "query")
        if action != "query":
            raise ValueError("Only read-only action=query requests are allowed")
        values.setdefault("format", "json")
        values.setdefault("formatversion", "2")
        return self._request_json(values)

    def _request_json(self, params: dict[str, str]) -> dict[str, Any]:
        with self._lock:
            if self._last_completed_at is not None:
                elapsed = self._monotonic() - self._last_completed_at
                remaining = self._minimum_interval - elapsed
                if remaining > 0:
                    self._sleeper(remaining)
            try:
                response = self._session.get(WIKI_API, params=params, timeout=40)
                response.raise_for_status()
                payload = response.json()
                if payload.get("error"):
                    raise RuntimeError(payload["error"])
                return payload
            finally:
                self._last_completed_at = self._monotonic()

    def _cache_path(self, title: str) -> Path | None:
        if self._cache_dir is None:
            return None
        safe = re.sub(r"[^0-9A-Za-z\u3400-\u9fff._-]+", "_", title).strip("_")
        return self._cache_dir / f"{safe[:120]}.json"

    def _read_cache(self, title: str) -> WikiRevision | None:
        path = self._cache_path(title)
        if path is None or not path.is_file():
            return None
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
            return WikiRevision(
                title=str(value["title"]),
                revision_id=int(value["revision_id"]),
                timestamp=str(value.get("timestamp") or ""),
                content=str(value["content"]),
            )
        except (KeyError, TypeError, ValueError, json.JSONDecodeError):
            return None

    def _write_cache(self, title: str, revision: WikiRevision) -> None:
        path = self._cache_path(title)
        if path is None:
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(asdict(revision), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
