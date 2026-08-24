#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import tempfile
import unittest
from unittest.mock import Mock, patch
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
        self.put_keys: list[str] = []

    def put(self, key: str, source: Path, content_type: str) -> None:
        self.put_keys.append(key)
        self.objects[key] = source.read_bytes()

    def get(self, key: str, destination: Path) -> None:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(self.objects[key])

    def try_get(self, key: str, destination: Path) -> bool:
        if key not in self.objects:
            return False
        self.get(key, destination)
        return True

    def head_size(self, key: str) -> int | None:
        return len(self.objects[key])


class OneStaleReadBackend(MemoryBackend):
    def __init__(self) -> None:
        super().__init__()
        self.stale_after_put: dict[str, bytes] = {}

    def put(self, key: str, source: Path, content_type: str) -> None:
        previous = self.objects.get(key)
        super().put(key, source, content_type)
        if previous is not None:
            self.stale_after_put[key] = previous

    def try_get(self, key: str, destination: Path) -> bool:
        stale = self.stale_after_put.pop(key, None)
        if stale is not None:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(stale)
            return True
        return super().try_get(key, destination)


class TransientReadBackend(MemoryBackend):
    def __init__(self, failures: int) -> None:
        super().__init__()
        self.failures = failures
        self.try_get_calls = 0

    def try_get(self, key: str, destination: Path) -> bool:
        self.try_get_calls += 1
        if self.try_get_calls <= self.failures:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(b"partial transient response")
            raise RuntimeError("simulated transient read failure")
        return super().try_get(key, destination)


class UploadDexV20ReleaseTests(unittest.TestCase):
    def test_binding_is_loaded_from_existing_wrangler_config(self) -> None:
        bucket = upload.load_bucket_from_binding(upload.DEFAULT_WRANGLER_DIR)
        self.assertTrue(bucket)

    def test_api_token_uses_persistent_cloudflare_object_backend(self) -> None:
        environment = {
            "CLOUDFLARE_ACCOUNT_ID": "0" * 32,
            "CLOUDFLARE_API_TOKEN": "test-token-never-log",
            "R2_ACCESS_KEY_ID": "",
            "R2_SECRET_ACCESS_KEY": "",
        }
        with patch.dict(os.environ, environment, clear=False):
            backend = upload.build_backend(wrangler_dir=upload.DEFAULT_WRANGLER_DIR)

        self.assertIsInstance(backend, upload.CloudflareApiBackend)
        self.assertNotIn(environment["CLOUDFLARE_API_TOKEN"], backend.base_url)
        self.assertTrue(backend._url("v5/a b?.json").endswith("/v5/a%20b%3F.json"))

    def test_cloudflare_api_gate_spaces_requests_and_shares_cooldowns(self) -> None:
        clock = [100.0]
        sleeps: list[float] = []

        def fake_sleep(seconds: float) -> None:
            sleeps.append(seconds)
            clock[0] += seconds

        with (
            patch.object(upload.time, "monotonic", side_effect=lambda: clock[0]),
            patch.object(upload.time, "sleep", side_effect=fake_sleep),
        ):
            gate = upload.CloudflareApiRateGate(interval_seconds=0.32)
            gate.wait()
            gate.wait()
            gate.defer(5.0)
            gate.wait()

        self.assertEqual(len(sleeps), 2)
        self.assertAlmostEqual(sleeps[0], 0.32)
        self.assertAlmostEqual(sleeps[1], 5.0)
        self.assertLessEqual(
            300.0 / upload.CLOUDFLARE_API_REQUEST_INTERVAL_SECONDS,
            1000.0,
        )

    def test_cloudflare_429_defers_every_worker_without_logging_response(self) -> None:
        environment = {
            "CLOUDFLARE_ACCOUNT_ID": "0" * 32,
            "CLOUDFLARE_API_TOKEN": "test-token-never-log",
        }
        with patch.dict(os.environ, environment, clear=False):
            backend = upload.CloudflareApiBackend(
                bucket="test-bucket",
                wrangler_dir=upload.DEFAULT_WRANGLER_DIR,
            )
        gate = Mock()
        backend._rate_gate = gate
        response = Mock(status_code=429, headers={"Retry-After": "17"})

        with self.assertRaisesRegex(RuntimeError, "HTTP 429"):
            backend._require_success(response, "readback")

        gate.defer.assert_called_once_with(17.0)

    def test_idempotent_put_and_mandatory_get_retry_transient_failures(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            source = root / "source.json"
            destination = root / "readback.json"
            source.write_bytes(b"frozen bytes")
            backend = Mock()
            backend.put.side_effect = [TimeoutError(), None]
            get_attempts = 0

            def flaky_get(key: str, path: Path) -> None:
                nonlocal get_attempts
                get_attempts += 1
                path.write_bytes(b"partial bytes")
                if get_attempts == 1:
                    raise TimeoutError()
                path.write_bytes(b"frozen bytes")

            backend.get.side_effect = flaky_get
            with (
                patch.object(upload, "REMOTE_WRITE_RETRY_DELAYS_SECONDS", (0.0, 0.0)),
                patch.object(upload, "REMOTE_READ_RETRY_DELAYS_SECONDS", (0.0, 0.0)),
            ):
                upload._safe_put(backend, "v5/data.json", source, "application/json")
                upload._safe_get(backend, "v5/data.json", destination)

            self.assertEqual(backend.put.call_count, 2)
            self.assertEqual(backend.get.call_count, 2)
            self.assertEqual(destination.read_bytes(), b"frozen bytes")

    def test_archive_routes_through_wrangler_backend(self) -> None:
        environment = {
            "CLOUDFLARE_ACCOUNT_ID": "0" * 32,
            "CLOUDFLARE_API_TOKEN": "test-token-never-log",
        }
        with patch.dict(os.environ, environment, clear=False):
            backend = upload.CloudflareApiBackend(
                bucket="test-bucket",
                wrangler_dir=upload.DEFAULT_WRANGLER_DIR,
            )
        archive_backend = MemoryBackend()
        backend._archive_backend = archive_backend

        with tempfile.TemporaryDirectory() as raw:
            source = Path(raw) / upload.ARCHIVE_NAME
            destination = Path(raw) / "readback.tar.zst"
            source.write_bytes(b"frozen-archive")
            key = f"{upload.CDN_PREFIX}/{upload.ARCHIVE_NAME}"

            backend.put(key, source, "application/zstd")
            self.assertTrue(backend.try_get(key, destination))

            self.assertEqual(archive_backend.put_keys, [key])
            self.assertEqual(destination.read_bytes(), b"frozen-archive")

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
            self.assertEqual(result["newlyUploadedObjects"], 40)
            self.assertEqual(result["resumedObjects"], 0)
            self.assertEqual(result["fullyShaVerifiedObjects"], 40)
            self.assertEqual(result["readbackVerifiedObjects"], 40)
            self.assertNotIn("bundle-manifest.json", backend.objects)

            cutover = upload.upload_root_manifest(
                release=release, receipt=receipt, backend=backend
            )
            self.assertTrue(cutover["manifestUploaded"])
            self.assertIn("bundle-manifest.json", backend.objects)

    def test_resume_skips_matching_objects_and_replaces_corrupt_ones(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            release = make_release(root)
            receipt = root / "receipt.json"
            backend = MemoryBackend()
            objects = upload._plan_objects(release)[1]
            for key, source in objects[:10]:
                backend.objects[key] = source.read_bytes()
            corrupt_key, _ = objects[10]
            backend.objects[corrupt_key] = b"corrupt"

            result = upload.upload_objects(
                release=release,
                backend=backend,
                sample_size=32,
                receipt=receipt,
                workers=4,
            )

            self.assertEqual(result["resumedObjects"], 10)
            self.assertEqual(result["newlyUploadedObjects"], 30)
            self.assertEqual(len(backend.put_keys), 30)
            self.assertIn(corrupt_key, backend.put_keys)
            for key, source in objects:
                self.assertEqual(backend.objects[key], source.read_bytes())

    def test_uploaded_object_retries_a_stale_immediate_read(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            release = make_release(root)
            receipt = root / "receipt.json"
            backend = OneStaleReadBackend()
            key, _ = upload._plan_objects(release)[1][0]
            backend.objects[key] = b"previous release bytes"

            with patch.object(upload, "UPLOAD_READBACK_RETRY_DELAYS_SECONDS", (0.0, 0.0)):
                result = upload.upload_objects(
                    release=release,
                    backend=backend,
                    sample_size=32,
                    receipt=receipt,
                    workers=4,
                )

            self.assertEqual(result["newlyUploadedObjects"], 40)
            self.assertEqual(result["fullyShaVerifiedObjects"], 40)

    def test_resume_retries_transient_reads_without_weakening_sha_check(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            release = make_release(root)
            key, source = upload._plan_objects(release)[1][0]
            destination = root / "readback.json"
            backend = TransientReadBackend(failures=2)
            backend.objects[key] = source.read_bytes()

            with patch.object(upload, "REMOTE_READ_RETRY_DELAYS_SECONDS", (0.0, 0.0, 0.0)):
                outcome = upload._resume_or_upload_object(
                    backend=backend,
                    key=key,
                    source=source,
                    downloaded=destination,
                )

            self.assertEqual(outcome, "resumed")
            self.assertEqual(backend.try_get_calls, 3)
            self.assertEqual(backend.put_keys, [])
            self.assertEqual(destination.read_bytes(), source.read_bytes())

    def test_resume_fails_closed_after_all_transient_read_retries(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            destination = Path(raw) / "partial.json"
            backend = TransientReadBackend(failures=2)

            with patch.object(upload, "REMOTE_READ_RETRY_DELAYS_SECONDS", (0.0, 0.0)):
                with self.assertRaisesRegex(RuntimeError, "resume probe failed"):
                    upload._safe_try_get(backend, "v5/data/000.json", destination)

            self.assertEqual(backend.try_get_calls, 2)
            self.assertFalse(destination.exists())

    def test_missing_object_probe_returns_without_retrying(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            destination = Path(raw) / "missing.json"
            backend = TransientReadBackend(failures=0)

            with patch.object(upload, "REMOTE_READ_RETRY_DELAYS_SECONDS", (0.0, 0.0, 0.0)):
                self.assertFalse(
                    upload._safe_try_get(backend, "v5/data/missing.json", destination)
                )

            self.assertEqual(backend.try_get_calls, 1)
            self.assertFalse(destination.exists())

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

    def test_manifest_rejects_incomplete_full_sha_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            release = make_release(root)
            receipt = root / "receipt.json"
            write_json(
                receipt,
                {
                    "targetBundleVersion": 20,
                    "releasePlanSha256": upload.sha256_file(release / "release-plan.json"),
                    "uploadedObjects": 40,
                    "fullyShaVerifiedObjects": 39,
                    "readbackVerifiedObjects": 39,
                },
            )
            with self.assertRaisesRegex(ValueError, "full SHA readback"):
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
