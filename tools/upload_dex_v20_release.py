#!/usr/bin/env python3
"""Safely upload a prepared Dex v20 release in explicitly separated phases.

The default is a local dry-run.  Versioned objects, the root manifest and the
v19 rollback manifest each require different explicit command-line approvals.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import mimetypes
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Protocol

from dex_v20_release_gate import BASE_VERSION, CDN_PREFIX, TARGET_VERSION, read_json, sha256_file


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WRANGLER_DIR = ROOT / "cloudflare" / "dex-cdn"
BUCKET_BINDING = "DEX_BUCKET"
MINIMUM_READBACK_SAMPLE = 32
DEFAULT_UPLOAD_WORKERS = 8
MAXIMUM_UPLOAD_WORKERS = 16


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def load_bucket_from_binding(wrangler_dir: Path) -> str:
    config = wrangler_dir / "wrangler.toml"
    text = config.read_text(encoding="utf-8")
    blocks = re.split(r"(?m)^\[\[r2_buckets\]\]\s*$", text)[1:]
    matches: list[dict[str, str]] = []
    for block in blocks:
        block = re.split(r"(?m)^\[", block, maxsplit=1)[0]
        values = {
            key: value
            for key, value in re.findall(
                r'(?m)^\s*(binding|bucket_name)\s*=\s*"([^"\r\n]+)"\s*$',
                block,
            )
        }
        if values.get("binding") == BUCKET_BINDING:
            matches.append(values)
    require(len(matches) == 1, f"wrangler must define exactly one {BUCKET_BINDING} binding")
    bucket = str(matches[0].get("bucket_name") or "").strip()
    require(bool(bucket), f"{BUCKET_BINDING} has no bucket_name")
    return bucket


def _plan_objects(release: Path) -> tuple[dict[str, Any], list[tuple[str, Path]]]:
    plan_path = release / "release-plan.json"
    plan = read_json(plan_path)
    require(plan.get("baseBundleVersion") == BASE_VERSION, "release plan base is not v19")
    require(plan.get("targetBundleVersion") == TARGET_VERSION, "release plan target is not v20")
    require(plan.get("cdnPrefix") == CDN_PREFIX, "release plan prefix is not v5")
    require(plan.get("manifestLast") is True, "release plan is not manifest-last")
    require(plan.get("v4Touched") is False, "release plan may touch v4")
    records = plan.get("objects")
    require(isinstance(records, list) and records, "release plan has no objects")
    expected_keys: set[str] = set()
    objects: list[tuple[str, Path]] = []
    for row in records:
        require(isinstance(row, dict), "invalid release object record")
        key = str(row.get("key") or "")
        require(key.startswith(f"{CDN_PREFIX}/"), f"release object escapes v5: {key}")
        require(not key.startswith("v4/"), "release must never touch v4")
        require(key not in expected_keys, f"duplicate release object: {key}")
        expected_keys.add(key)
        path = release / "objects" / key
        require(path.is_file() and not path.is_symlink(), f"missing release object: {key}")
        require(path.stat().st_size == row.get("sizeBytes"), f"release object size drift: {key}")
        require(sha256_file(path) == row.get("sha256"), f"release object SHA drift: {key}")
        objects.append((key, path))
    actual_keys = {
        path.relative_to(release / "objects").as_posix()
        for path in (release / "objects").rglob("*")
        if path.is_file()
    }
    require(actual_keys == expected_keys, "release object tree differs from release-plan.json")
    require(plan.get("objectCount") == len(objects), "release object count drift")
    require(
        plan.get("objectBytes") == sum(path.stat().st_size for _, path in objects),
        "release object byte count drift",
    )
    target_manifest = release / "manifest" / "bundle-manifest.json"
    rollback_manifest = release / "rollback" / "bundle-manifest-v19.json"
    require(target_manifest.is_file(), "target root manifest is missing")
    require(rollback_manifest.is_file(), "v19 rollback manifest is missing")
    require(
        sha256_file(target_manifest) == plan.get("targetRootManifestSha256"),
        "target root manifest differs from the release plan",
    )
    require(
        sha256_file(rollback_manifest) == plan.get("baseRootManifestSha256"),
        "v19 rollback manifest differs from the release plan",
    )
    return plan, sorted(objects)


def deterministic_readback_sample(
    objects: list[tuple[str, Path]], requested: int
) -> list[tuple[str, Path]]:
    require(requested >= MINIMUM_READBACK_SAMPLE, f"readback sample must be at least {MINIMUM_READBACK_SAMPLE}")
    critical_names = {
        f"{CDN_PREFIX}/bundle-v20.tar.zst",
        f"{CDN_PREFIX}/manifest.json",
        f"{CDN_PREFIX}/summaries.json",
        f"{CDN_PREFIX}/dex_catalog.json",
        f"{CDN_PREFIX}/entity_index.json",
        f"{CDN_PREFIX}/provenance.json",
        f"{CDN_PREFIX}/reference_v20_audit.json",
        f"{CDN_PREFIX}/gameplay/gameplay_v20_audit.json",
    }
    by_key = dict(objects)
    selected = {key for key in critical_names if key in by_key}
    ranked = sorted(
        (key for key in by_key if key not in selected),
        key=lambda key: hashlib.sha256(key.encode("utf-8")).digest(),
    )
    selected.update(ranked[: max(0, requested - len(selected))])
    return [(key, by_key[key]) for key in sorted(selected)]


class Backend(Protocol):
    def put(self, key: str, source: Path, content_type: str) -> None: ...

    def get(self, key: str, destination: Path) -> None: ...

    def try_get(self, key: str, destination: Path) -> bool: ...

    def head_size(self, key: str) -> int | None: ...


class WranglerBackend:
    def __init__(self, *, wrangler_dir: Path, bucket: str) -> None:
        self.wrangler_dir = wrangler_dir
        cli = wrangler_dir / "node_modules" / "wrangler" / "wrangler-dist" / "cli.js"
        require(cli.is_file(), "Wrangler is not installed in the configured Worker directory")
        node = shutil.which("node")
        require(node is not None, "Node.js is required for Wrangler uploads")
        self.prefix = [node, str(cli)]
        self.bucket = bucket

    def _run(self, args: list[str]) -> None:
        result = subprocess.run(
            [*self.prefix, *args],
            cwd=self.wrangler_dir,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise RuntimeError("Wrangler R2 operation failed; sensitive output was suppressed")

    def _try_run(self, args: list[str]) -> bool:
        result = subprocess.run(
            [*self.prefix, *args],
            cwd=self.wrangler_dir,
            capture_output=True,
            text=True,
        )
        return result.returncode == 0

    def put(self, key: str, source: Path, content_type: str) -> None:
        self._run(
            [
                "r2",
                "object",
                "put",
                f"{self.bucket}/{key}",
                f"--file={source.resolve()}",
                "--remote",
                f"--content-type={content_type}",
            ]
        )

    def get(self, key: str, destination: Path) -> None:
        destination.parent.mkdir(parents=True, exist_ok=True)
        self._run(
            [
                "r2",
                "object",
                "get",
                f"{self.bucket}/{key}",
                f"--file={destination.resolve()}",
                "--remote",
            ]
        )

    def try_get(self, key: str, destination: Path) -> bool:
        destination.parent.mkdir(parents=True, exist_ok=True)
        ok = self._try_run(
            [
                "r2",
                "object",
                "get",
                f"{self.bucket}/{key}",
                f"--file={destination.resolve()}",
                "--remote",
            ]
        )
        if not ok:
            destination.unlink(missing_ok=True)
        return ok

    def head_size(self, key: str) -> int | None:
        return None


class S3Backend:
    def __init__(self, *, bucket: str) -> None:
        import boto3
        from botocore.config import Config

        account_id = os.environ.get("CLOUDFLARE_ACCOUNT_ID", "").strip()
        require(bool(account_id), "CLOUDFLARE_ACCOUNT_ID is required for R2 access keys")
        self.client = boto3.client(
            "s3",
            endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
            aws_access_key_id=os.environ["R2_ACCESS_KEY_ID"],
            aws_secret_access_key=os.environ["R2_SECRET_ACCESS_KEY"],
            config=Config(signature_version="s3v4"),
            region_name="auto",
        )
        self.bucket = bucket

    def put(self, key: str, source: Path, content_type: str) -> None:
        self.client.upload_file(
            str(source), self.bucket, key, ExtraArgs={"ContentType": content_type}
        )

    def get(self, key: str, destination: Path) -> None:
        destination.parent.mkdir(parents=True, exist_ok=True)
        self.client.download_file(self.bucket, key, str(destination))

    def try_get(self, key: str, destination: Path) -> bool:
        from botocore.exceptions import ClientError

        destination.parent.mkdir(parents=True, exist_ok=True)
        try:
            self.client.download_file(self.bucket, key, str(destination))
        except ClientError as error:
            destination.unlink(missing_ok=True)
            code = str(error.response.get("Error", {}).get("Code") or "")
            if code in {"404", "NoSuchKey", "NotFound"}:
                return False
            raise
        return True

    def head_size(self, key: str) -> int | None:
        return int(self.client.head_object(Bucket=self.bucket, Key=key)["ContentLength"])


def build_backend(*, wrangler_dir: Path) -> Backend:
    bucket = load_bucket_from_binding(wrangler_dir)
    if os.environ.get("R2_ACCESS_KEY_ID") and os.environ.get("R2_SECRET_ACCESS_KEY"):
        return S3Backend(bucket=bucket)
    require(
        bool(os.environ.get("CLOUDFLARE_API_TOKEN")),
        "CLOUDFLARE_API_TOKEN or R2 access keys are required for execution",
    )
    return WranglerBackend(wrangler_dir=wrangler_dir, bucket=bucket)


def _content_type(path: Path) -> str:
    return mimetypes.guess_type(str(path))[0] or "application/octet-stream"


def _safe_put(backend: Backend, key: str, source: Path, content_type: str) -> None:
    try:
        backend.put(key, source, content_type)
    except Exception:
        raise RuntimeError(f"remote object upload failed: {key}") from None


def _safe_get(backend: Backend, key: str, destination: Path) -> None:
    try:
        backend.get(key, destination)
    except Exception:
        raise RuntimeError(f"remote object readback failed: {key}") from None


def _safe_try_get(backend: Backend, key: str, destination: Path) -> bool:
    try:
        return backend.try_get(key, destination)
    except Exception:
        raise RuntimeError(f"remote object resume probe failed: {key}") from None


def _safe_head_size(backend: Backend, key: str) -> int | None:
    try:
        return backend.head_size(key)
    except Exception:
        raise RuntimeError(f"remote object metadata readback failed: {key}") from None


def _remote_object_matches(source: Path, downloaded: Path) -> bool:
    return (
        downloaded.is_file()
        and downloaded.stat().st_size == source.stat().st_size
        and sha256_file(downloaded) == sha256_file(source)
    )


def _resume_or_upload_object(
    *, backend: Backend, key: str, source: Path, downloaded: Path
) -> str:
    if _safe_try_get(backend, key, downloaded) and _remote_object_matches(source, downloaded):
        return "resumed"

    downloaded.unlink(missing_ok=True)
    _safe_put(backend, key, source, _content_type(source))
    remote_size = _safe_head_size(backend, key)
    if remote_size is not None:
        require(remote_size == source.stat().st_size, f"R2 object size mismatch: {key}")

    _safe_get(backend, key, downloaded)
    require(_remote_object_matches(source, downloaded), f"R2 object SHA mismatch: {key}")
    return "uploaded"


def upload_objects(
    *,
    release: Path,
    backend: Backend,
    sample_size: int,
    receipt: Path,
    workers: int = DEFAULT_UPLOAD_WORKERS,
) -> dict[str, Any]:
    plan, objects = _plan_objects(release)
    require(1 <= workers <= MAXIMUM_UPLOAD_WORKERS, f"workers must be between 1 and {MAXIMUM_UPLOAD_WORKERS}")
    resumed = 0
    uploaded = 0
    with tempfile.TemporaryDirectory() as raw:
        temporary = Path(raw)
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {
                executor.submit(
                    _resume_or_upload_object,
                    backend=backend,
                    key=key,
                    source=source,
                    downloaded=temporary / f"{index:06d}",
                ): key
                for index, (key, source) in enumerate(objects)
            }
            for completed, future in enumerate(as_completed(futures), start=1):
                outcome = future.result()
                resumed += outcome == "resumed"
                uploaded += outcome == "uploaded"
                if completed % 100 == 0 or completed == len(objects):
                    print(
                        f"verified {completed}/{len(objects)} objects "
                        f"(resumed {resumed}, uploaded {uploaded})",
                        flush=True,
                    )

    sample = deterministic_readback_sample(objects, sample_size)

    payload = {
        "schemaVersion": 1,
        "baseBundleVersion": BASE_VERSION,
        "targetBundleVersion": TARGET_VERSION,
        "releasePlanSha256": sha256_file(release / "release-plan.json"),
        "uploadedObjects": len(objects),
        "newlyUploadedObjects": uploaded,
        "resumedObjects": resumed,
        "fullyShaVerifiedObjects": len(objects),
        "headVerifiedObjects": uploaded if isinstance(backend, S3Backend) else 0,
        "readbackVerifiedObjects": len(objects),
        "postUploadSampleSize": len(sample),
        "readbackKeys": [key for key, _ in sample],
        "manifestUploaded": False,
    }
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return payload


def _validate_receipt(release: Path, receipt: Path) -> None:
    plan, objects = _plan_objects(release)
    payload = read_json(receipt)
    require(payload.get("targetBundleVersion") == TARGET_VERSION, "upload receipt is not v20")
    require(
        payload.get("releasePlanSha256") == sha256_file(release / "release-plan.json"),
        "upload receipt belongs to a different release plan",
    )
    require(payload.get("uploadedObjects") == len(objects), "not all release objects were uploaded")
    require(
        payload.get("fullyShaVerifiedObjects") == len(objects),
        "not all release objects passed full SHA readback",
    )
    require(
        int(payload.get("readbackVerifiedObjects") or 0) >= MINIMUM_READBACK_SAMPLE,
        "upload receipt lacks the minimum direct readback sample",
    )
    require(plan.get("manifestLast") is True, "release is not manifest-last")


def upload_root_manifest(
    *, release: Path, receipt: Path, backend: Backend
) -> dict[str, Any]:
    _validate_receipt(release, receipt)
    manifest = release / "manifest" / "bundle-manifest.json"
    payload = read_json(manifest)
    require(payload.get("bundleVersion") == TARGET_VERSION, "target root manifest is not v20")
    require(payload.get("baseBundleVersion") == BASE_VERSION, "target root lacks v19 lineage")
    require(payload.get("cdnPrefix") == CDN_PREFIX, "target root prefix is not v5")
    _safe_put(backend, "bundle-manifest.json", manifest, "application/json")
    with tempfile.TemporaryDirectory() as raw:
        readback = Path(raw) / "bundle-manifest.json"
        _safe_get(backend, "bundle-manifest.json", readback)
        require(sha256_file(readback) == sha256_file(manifest), "root manifest readback mismatch")
    return {
        "bundleVersion": TARGET_VERSION,
        "rootManifestSha256": sha256_file(manifest),
        "manifestUploaded": True,
    }


def restore_v19(*, release: Path, backend: Backend) -> dict[str, Any]:
    rollback = release / "rollback" / "bundle-manifest-v19.json"
    payload = read_json(rollback)
    require(payload.get("bundleVersion") == BASE_VERSION, "rollback manifest is not v19")
    require(payload.get("cdnPrefix") == CDN_PREFIX, "rollback manifest prefix is not v5")
    _safe_put(backend, "bundle-manifest.json", rollback, "application/json")
    with tempfile.TemporaryDirectory() as raw:
        readback = Path(raw) / "bundle-manifest.json"
        _safe_get(backend, "bundle-manifest.json", readback)
        require(sha256_file(readback) == sha256_file(rollback), "rollback manifest readback mismatch")
    return {
        "bundleVersion": BASE_VERSION,
        "rootManifestSha256": sha256_file(rollback),
        "v4Touched": False,
    }


def dry_run(release: Path, phase: str, sample_size: int) -> dict[str, Any]:
    if phase == "rollback":
        rollback = read_json(release / "rollback" / "bundle-manifest-v19.json")
        require(rollback.get("bundleVersion") == BASE_VERSION, "rollback manifest is not v19")
        require(rollback.get("cdnPrefix") == CDN_PREFIX, "rollback manifest prefix is not v5")
        return {
            "dryRun": True,
            "phase": phase,
            "objects": 0,
            "readbackSample": 0,
            "manifestLast": True,
            "v4Touched": False,
        }
    plan, objects = _plan_objects(release)
    if phase == "manifest":
        manifest = read_json(release / "manifest" / "bundle-manifest.json")
        require(manifest.get("bundleVersion") == TARGET_VERSION, "target root manifest is not v20")
    return {
        "dryRun": True,
        "phase": phase,
        "objects": len(objects),
        "readbackSample": len(deterministic_readback_sample(objects, sample_size)),
        "manifestLast": plan["manifestLast"],
        "v4Touched": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("release", type=Path)
    parser.add_argument("--phase", choices=("objects", "manifest", "rollback"), required=True)
    parser.add_argument("--execute", action="store_true", help="Perform the selected remote mutation")
    parser.add_argument("--publish-manifest", action="store_true", help="Required in addition to --execute for root cutover")
    parser.add_argument("--restore-v19", action="store_true", help="Required in addition to --execute for rollback")
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--readback-sample", type=int, default=64)
    parser.add_argument("--workers", type=int, default=DEFAULT_UPLOAD_WORKERS)
    parser.add_argument("--wrangler-dir", type=Path, default=DEFAULT_WRANGLER_DIR)
    args = parser.parse_args()

    require(args.release.is_dir(), "prepared v20 release directory is missing")
    if not args.execute:
        result = dry_run(args.release, args.phase, args.readback_sample)
    else:
        backend = build_backend(wrangler_dir=args.wrangler_dir)
        if args.phase == "objects":
            require(args.receipt is not None, "object execution requires --receipt")
            result = upload_objects(
                release=args.release,
                backend=backend,
                sample_size=args.readback_sample,
                receipt=args.receipt,
                workers=args.workers,
            )
        elif args.phase == "manifest":
            require(args.publish_manifest, "manifest cutover requires --publish-manifest")
            require(args.receipt is not None and args.receipt.is_file(), "manifest cutover requires an upload receipt")
            result = upload_root_manifest(
                release=args.release, receipt=args.receipt, backend=backend
            )
        else:
            require(args.restore_v19, "rollback requires --restore-v19")
            result = restore_v19(release=args.release, backend=backend)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
