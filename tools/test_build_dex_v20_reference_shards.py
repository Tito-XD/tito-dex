from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from build_dex_v20_reference_shards import (
    MAX_SHARD_BYTES,
    build_reference_shards,
    slug_bucket,
    verify_reference_shards,
)


COMMIT = "a" * 40


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")


class ReferenceShardTests(unittest.TestCase):
    def _fixture(self, root: Path) -> Path:
        provenance = {"sourceCommit": COMMIT}
        write_json(root / "moves.json", {"14": {
            "id": 14, "stableId": "move:14", "slug": "swords-dance",
            "nameZh": "剑舞", "nameEn": "Swords Dance", "type": "normal",
            "category": "status", "pp": 20, "priority": 0, "generation": 1,
            "descriptionZh": "大幅提高自己的攻击。", "provenance": provenance,
        }})
        write_json(root / "abilities.json", {"1": {
            "id": 1, "stableId": "ability:1", "slug": "stench",
            "nameZh": "恶臭", "nameEn": "Stench", "generation": 3,
            "descriptionZh": "攻击时有时会使对手畏缩。", "provenance": provenance,
        }})
        write_json(root / "items.json", {"1": {
            "id": 1, "stableId": "item:master-ball", "slug": "master-ball",
            "nameZh": "大师球", "nameEn": "Master Ball", "categoryZh": "精灵球",
            "descriptionZh": "必定能捉到野生宝可梦。", "provenance": provenance,
        }})
        return root

    def test_builds_complete_bounded_projection_and_slug_index(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = self._fixture(Path(raw))
            audit = build_reference_shards(root)
            self.assertEqual(audit, verify_reference_shards(root))
            self.assertLess(audit["collections"]["moves"]["maximumObjectBytes"], MAX_SHARD_BYTES)
            bucket = slug_bucket("master-ball")
            index = json.loads((root / "reference/item-slug-index" / f"{bucket}.json").read_text())
            self.assertEqual(index["entries"]["master-ball"], {"id": 1, "nameZh": "大师球"})
            self.assertEqual(len(list((root / "reference/item-slug-index").glob("*.json"))), 256)

    def test_missing_and_oversized_shards_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = self._fixture(Path(raw))
            build_reference_shards(root)
            (root / "reference/moves/14.json").unlink()
            with self.assertRaisesRegex(ValueError, "missing, altered, or oversized"):
                verify_reference_shards(root)
            build_reference_shards(root)
            (root / "reference/moves/14.json").write_bytes(b"{" + b"x" * MAX_SHARD_BYTES + b"}")
            with self.assertRaisesRegex(ValueError, "missing, altered, or oversized"):
                verify_reference_shards(root)


if __name__ == "__main__":
    unittest.main()
