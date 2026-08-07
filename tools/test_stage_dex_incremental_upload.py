#!/usr/bin/env python3

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from stage_dex_incremental_upload import stage_incremental


class StageDexIncrementalUploadTests(unittest.TestCase):
    def test_stages_changed_objects_and_manifest_only(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            base = root / "base"
            target = root / "target"
            output = root / "incremental"
            (base / "details").mkdir(parents=True)
            (target / "v5" / "details").mkdir(parents=True)
            (base / "details" / "1.json").write_text("same", encoding="utf-8")
            (target / "v5" / "details" / "1.json").write_text(
                "same", encoding="utf-8"
            )
            (target / "v5" / "details" / "2.json").write_text(
                "new", encoding="utf-8"
            )
            (target / "bundle-manifest.json").write_text(
                json.dumps({"bundleVersion": 19}), encoding="utf-8"
            )

            summary = stage_incremental(target, base, output)

            self.assertEqual(summary["objects"], 1)
            self.assertFalse((output / "v5" / "details" / "1.json").exists())
            self.assertEqual(
                (output / "v5" / "details" / "2.json").read_text(
                    encoding="utf-8"
                ),
                "new",
            )
            self.assertTrue((output / "bundle-manifest.json").is_file())


if __name__ == "__main__":
    unittest.main()
