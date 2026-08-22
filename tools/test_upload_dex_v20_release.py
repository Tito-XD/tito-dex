#!/usr/bin/env python3

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import upload_dex_v20_release as upload


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def make_release(root: Path, count: int = 40) -> Path:
    release = root / "release"
    records = []
    for index in range(count):
        key = f"v5/data/{index:03}.json"
        path = release / "objects" / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"{index}\n", encoding="utf-8")
        records.append(
            {
                "key": key,
                "sizeBytes": path.stat().st_size,
                "sha256": upload.sha256_file(path),
            }
        )
    manifest = release / "manifest/bundle-manifest.json"
    write_json(
        manifest,
        {
            "bundleVersion": 20,
            "baseBundleVersion": 19,
            "cdnPrefix": "v5",
        },
    )
    rollback = release / "rollback/bundle-manifest-v19.json"
    write_json(rollback, {"bundleVersion": 19, "cdnPrefix": "v5"})
    write_json(
        release / "release-plan.json",
        {
            "schemaVersion": 1,
            "baseBundleVersion": 19,
            "targetBundleVersion": 20,
            "cdnPrefix": "v5",
            "baseRootManifestSha256": upload.sha256_file(rollback),
            "targetRootManifestSha256": upload.sha256_file(manifest),
            "objects": records,
            "objectCount": len(records),
            "objectBytes": sum(row["sizeBytes"] for row in records),
            "manifestLast": True,
            "v4Touched": False,
        },
    )
    return release


class MemoryBackend:
    def __init__(self) -> None:
        self.objects: dict[str, bytes] = {}

    def put(self, key: str, source: Path, content_type: str) -> None:
        self.objects[key] = source.read_bytes()

    def get(self, key: str, destination: Path) -> None:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(self.objects[key])

    def head_size(self, key: str) -> int | None:
        return len(self.objects[key])


class UploadDexV20ReleaseTests(unittest.TestCase):
    def test_binding_is_loaded_from_existing_wrangler_config(self) -> None:
        bucket = upload.load_bucket_from_binding(upload.DEFAULT_WRANGLER_DIR)
        self.assertTrue(bucket)

    def test_dry_run_never_mutates_backend(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            release = make_release(Path(raw))
            result = upload.dry_run(release, "objects", 32)
            self.assertTrue(result["dryRun"])
            self.assertEqual(result["objects"], 40)
            self.assertFalse(result["v4Touched"])

    def test_objects_are_uploaded_then_sampled_before_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            release = make_release(root)
            receipt = root / "receipt.json"
            backend = MemoryBackend()
            result = upload.upload_objects(
                release=release,
                backend=backend,
                sample_size=32,
                receipt=receipt,
            )
            self.assertEqual(result["uploadedObjects"], 40)
            self.assertEqual(result["readbackVerifiedObjects"], 32)
            self.assertNotIn("bundle-manifest.json", backend.objects)

            cutover = upload.upload_root_manifest(
                release=release, receipt=receipt, backend=backend
            )
            self.assertTrue(cutover["manifestUploaded"])
            self.assertIn("bundle-manifest.json", backend.objects)

    def test_manifest_rejects_missing_or_wrong_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            release = make_release(root)
            receipt = root / "receipt.json"
            write_json(
                receipt,
                {
                    "targetBundleVersion": 20,
                    "releasePlanSha256": "0" * 64,
                    "uploadedObjects": 40,
                    "readbackVerifiedObjects": 32,
                },
            )
            with self.assertRaisesRegex(ValueError, "different release plan"):
                upload.upload_root_manifest(
                    release=release, receipt=receipt, backend=MemoryBackend()
                )

    def test_rollback_only_restores_root_and_never_touches_v4(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            release = make_release(Path(raw))
            backend = MemoryBackend()
            result = upload.restore_v19(release=release, backend=backend)
            self.assertEqual(result["bundleVersion"], 19)
            self.assertFalse(result["v4Touched"])
            self.assertEqual(set(backend.objects), {"bundle-manifest.json"})

    def test_rollback_dry_run_accepts_the_separate_rollback_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            release = Path(raw) / "release"
            write_json(
                release / "rollback/bundle-manifest-v19.json",
                {"bundleVersion": 19, "cdnPrefix": "v5"},
            )
            result = upload.dry_run(release, "rollback", 32)
            self.assertTrue(result["dryRun"])
            self.assertEqual(result["objects"], 0)


if __name__ == "__main__":
    unittest.main()
