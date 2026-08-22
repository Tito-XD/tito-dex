#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import io
import json
import os
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import zstandard

import dex_v20_release_gate as gate


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload) + "\n", encoding="utf-8")


def write_archive(staging: Path, output: Path) -> None:
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w") as bundle:
        for path in sorted(item for item in staging.rglob("*") if item.is_file()):
            info = tarfile.TarInfo(path.relative_to(staging).as_posix())
            payload = path.read_bytes()
            info.size = len(payload)
            bundle.addfile(info, io.BytesIO(payload))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(zstandard.ZstdCompressor().compress(raw.getvalue()))


class DexV20ReleaseGateTests(unittest.TestCase):
    def test_fetch_base_binds_live_root_archive_and_staging(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            source_staging = root / "source-staging"
            write_json(source_staging / "manifest.json", {"version": 19, "complete": True})
            (source_staging / "summaries.json").write_text("[]\n", encoding="utf-8")
            archive = root / "source.tar.zst"
            write_archive(source_staging, archive)
            manifest = root / "source-root.json"
            write_json(
                manifest,
                {
                    "bundleVersion": 19,
                    "cdnPrefix": "v5",
                    "complete": True,
                    "archiveUrl": "https://example.invalid/v5/bundle-v19.tar.zst",
                    "archiveSha256": gate.sha256_file(archive),
                    "archiveSizeBytes": archive.stat().st_size,
                },
            )

            def fake_download(url: str, output: Path, *, expected_size=None) -> None:
                source = manifest if url.endswith("bundle-manifest.json") else archive
                output.parent.mkdir(parents=True, exist_ok=True)
                output.write_bytes(source.read_bytes())
                if expected_size is not None:
                    self.assertEqual(output.stat().st_size, expected_size)

            with mock.patch.object(gate, "_download", side_effect=fake_download), mock.patch.dict(
                os.environ, {"TEST_CDN": "https://example.invalid"}
            ):
                result = gate.fetch_base(
                    output=root / "base",
                    approved_root_sha256=gate.sha256_file(manifest),
                    cdn_base_env="TEST_CDN",
                )
            self.assertEqual(result["bundleVersion"], 19)
            self.assertEqual(
                result["baseTreeSha256"], gate.tree_fingerprint(source_staging)
            )
            self.assertTrue((root / "base/rollback/bundle-manifest-v19.json").is_file())

    def test_fetch_base_rejects_unapproved_live_root(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            live = root / "live.json"
            write_json(live, {"bundleVersion": 19})

            def fake_download(_url: str, output: Path, *, expected_size=None) -> None:
                output.parent.mkdir(parents=True, exist_ok=True)
                output.write_bytes(live.read_bytes())

            with mock.patch.object(gate, "_download", side_effect=fake_download), mock.patch.dict(
                os.environ, {"TEST_CDN": "https://example.invalid"}
            ):
                with self.assertRaisesRegex(ValueError, "differs from the approved"):
                    gate.fetch_base(
                        output=root / "base",
                        approved_root_sha256="0" * 64,
                        cdn_base_env="TEST_CDN",
                    )

    def test_release_input_verification_binds_candidate_to_exact_base(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            staging = root / "v19-staging"
            write_json(staging / "manifest.json", {"version": 19, "complete": True})
            archive = root / "v19.tar.zst"
            write_archive(staging, archive)
            base_root = root / "v19-root.json"
            write_json(
                base_root,
                {
                    "bundleVersion": 19,
                    "cdnPrefix": "v5",
                    "complete": True,
                    "archiveSha256": gate.sha256_file(archive),
                    "archiveSizeBytes": archive.stat().st_size,
                },
            )
            candidate = root / "candidate"
            write_json(
                candidate / "build-report.json",
                {
                    "baseBundleVersion": 19,
                    "baseUnchanged": True,
                    "baseRootManifestSha256": gate.sha256_file(base_root),
                    "baseTreeSha256": gate.tree_fingerprint(staging),
                },
            )
            with mock.patch.object(gate, "verify_candidate", return_value={"ok": 1}), mock.patch.object(
                gate, "verify_reference", return_value={"ok": 2}
            ), mock.patch.object(gate, "verify_gameplay", return_value={"ok": 3}):
                result = gate.verify_release_inputs(
                    candidate=candidate,
                    base_root_manifest=base_root,
                    base_archive=archive,
                    base_staging=staging,
                )
            self.assertEqual(result["foundation"], {"ok": 1})
            write_json(
                candidate / "build-report.json",
                {
                    "baseBundleVersion": 19,
                    "baseUnchanged": True,
                    "baseRootManifestSha256": "f" * 64,
                    "baseTreeSha256": gate.tree_fingerprint(staging),
                },
            )
            with self.assertRaisesRegex(ValueError, "different v19 root"):
                gate.verify_release_inputs(
                    candidate=candidate,
                    base_root_manifest=base_root,
                    base_archive=archive,
                    base_staging=staging,
                )

    def test_prepare_keeps_root_manifest_separate_and_v4_absent(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            candidate = root / "candidate"
            archive = candidate / "upload/v5/bundle-v20.tar.zst"
            archive.parent.mkdir(parents=True)
            archive.write_bytes(b"archive-v20")
            (candidate / "upload/v5/manifest.json").write_text("{}\n", encoding="utf-8")
            write_json(
                candidate / "release-manifest/bundle-manifest.v20.candidate.json",
                {
                    "bundleVersion": 20,
                    "baseBundleVersion": 19,
                    "cdnPrefix": "v5",
                    "complete": True,
                    "releaseState": "candidate",
                    "archiveFile": "bundle-v20.tar.zst",
                    "archiveSha256": gate.sha256_file(archive),
                    "archiveSizeBytes": archive.stat().st_size,
                },
            )
            base_root = root / "v19-root.json"
            write_json(
                base_root,
                {
                    "bundleVersion": 19,
                    "cdnPrefix": "v5",
                    "complete": True,
                    "archiveSha256": "a" * 64,
                    "archiveSizeBytes": 1,
                },
            )
            base_archive = root / "v19.tar.zst"
            base_archive.write_bytes(b"x")
            staging = root / "v19-staging"
            staging.mkdir()
            with mock.patch.object(gate, "verify_release_inputs", return_value={"ok": True}), mock.patch.dict(
                os.environ, {"TEST_CDN": "https://example.invalid"}
            ):
                result = gate.prepare_release(
                    candidate=candidate,
                    base_root_manifest=base_root,
                    base_archive=base_archive,
                    base_staging=staging,
                    output=root / "release",
                    cdn_base_env="TEST_CDN",
                    published_at="2026-08-23T00:00:00+00:00",
                )
            self.assertFalse((root / "release/objects/bundle-manifest.json").exists())
            self.assertTrue((root / "release/manifest/bundle-manifest.json").is_file())
            self.assertFalse((root / "release/objects/v4").exists())
            self.assertFalse(result["manifestPublished"])


if __name__ == "__main__":
    unittest.main()
