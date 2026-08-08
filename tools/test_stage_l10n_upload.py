#!/usr/bin/env python3
"""Regression tests for manifest-last l10n staging guards."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from stage_l10n_upload import update_bundle_manifest


class StageL10nUploadTest(unittest.TestCase):
    def _manifest(self, bundle_version: int = 19) -> dict[str, object]:
        return {
            "bundleVersion": bundle_version,
            "cdnPrefix": "v5",
            "pokemonCount": 1025,
            "complete": True,
            "archiveSha256": "a" * 64,
            "archiveUrl": "https://example.invalid/v5/bundle.tar.zst",
            "preservedField": {"doNotReplace": True},
        }

    def test_updates_only_mutable_manifest_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "current.json"
            source.write_text(json.dumps(self._manifest()), encoding="utf-8")

            output = update_bundle_manifest(
                root,
                l10n_version="catalog-2026-08-08",
                config_version=4,
                expected_bundle_version=19,
                remote_manifest_path=source,
            )

            staged = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(staged["bundleVersion"], 19)
            self.assertEqual(staged["archiveSha256"], "a" * 64)
            self.assertEqual(staged["preservedField"], {"doNotReplace": True})
            self.assertEqual(staged["l10nVersion"], "catalog-2026-08-08")
            self.assertEqual(staged["configVersion"], 4)
            self.assertIn("publishedAt", staged)

    def test_rejects_stale_production_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "stale.json"
            source.write_text(json.dumps(self._manifest(18)), encoding="utf-8")

            with self.assertRaisesRegex(RuntimeError, "bundleVersion=18"):
                update_bundle_manifest(
                    root,
                    l10n_version="catalog-2026-08-08",
                    config_version=4,
                    expected_bundle_version=19,
                    remote_manifest_path=source,
                )

    def test_rejects_manifest_without_archive_integrity(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "invalid.json"
            manifest = self._manifest()
            manifest["archiveSha256"] = ""
            source.write_text(json.dumps(manifest), encoding="utf-8")

            with self.assertRaisesRegex(RuntimeError, "no archive SHA"):
                update_bundle_manifest(
                    root,
                    l10n_version="catalog-2026-08-08",
                    config_version=4,
                    expected_bundle_version=19,
                    remote_manifest_path=source,
                )


if __name__ == "__main__":
    unittest.main()
