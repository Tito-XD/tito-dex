#!/usr/bin/env python3
"""Prepare and verify a manifest-last Dex v20 release without publishing it.

Network locations are supplied through the environment at runtime.  This tool
never uploads and never prints a production URL.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tarfile
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urljoin, urlparse

import zstandard

from build_dex_v20_candidate import tree_fingerprint
from publish_dex_bundle_incremental import changed_files
from verify_dex_v20_candidate import verify_candidate
from verify_dex_v20_gameplay import verify as verify_gameplay
from verify_dex_v20_reference import verify as verify_reference


BASE_VERSION = 19
TARGET_VERSION = 20
CDN_PREFIX = "v5"
ARCHIVE_NAME = "bundle-v20.tar.zst"
USER_AGENT = "TitoDex-v20-release-gate/1.0"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def read_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(payload, dict), f"expected a JSON object: {path.name}")
    return payload


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _production_base(env_name: str) -> str:
    value = os.environ.get(env_name, "").strip()
    require(bool(value), f"missing runtime environment value: {env_name}")
    parsed = urlparse(value)
    require(parsed.scheme == "https" and bool(parsed.netloc), "runtime CDN base must use HTTPS")
    require(not parsed.username and not parsed.password, "runtime CDN base must not contain credentials")
    return value.rstrip("/") + "/"


def _download(url: str, output: Path, *, expected_size: int | None = None) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".part")
    try:
        with urllib.request.urlopen(request, timeout=60) as response, temporary.open("wb") as sink:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                sink.write(chunk)
    except (OSError, urllib.error.HTTPError, urllib.error.URLError):
        temporary.unlink(missing_ok=True)
        raise RuntimeError("failed to download a required production release object") from None
    if expected_size is not None and temporary.stat().st_size != expected_size:
        temporary.unlink(missing_ok=True)
        raise ValueError("downloaded production object size does not match the approved manifest")
    temporary.replace(output)


def _safe_extract_archive(archive: Path, output: Path) -> None:
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    with archive.open("rb") as raw:
        with zstandard.ZstdDecompressor().stream_reader(raw) as stream:
            with tarfile.open(fileobj=stream, mode="r|") as bundle:
                for member in bundle:
                    path = Path(member.name)
                    require(member.isfile(), f"base archive contains a non-file member: {member.name}")
                    require(
                        not path.is_absolute() and ".." not in path.parts,
                        f"unsafe base archive member: {member.name}",
                    )
                    source = bundle.extractfile(member)
                    require(source is not None, f"cannot read base archive member: {member.name}")
                    destination = output / path
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    with destination.open("wb") as sink:
                        shutil.copyfileobj(source, sink)


def _archive_tree_fingerprint(archive: Path) -> str:
    digest = hashlib.sha256()
    with archive.open("rb") as raw:
        with zstandard.ZstdDecompressor().stream_reader(raw) as stream:
            with tarfile.open(fileobj=stream, mode="r|") as bundle:
                for member in bundle:
                    require(member.isfile(), f"archive contains a non-file member: {member.name}")
                    path = Path(member.name)
                    require(
                        not path.is_absolute() and ".." not in path.parts,
                        f"unsafe archive member: {member.name}",
                    )
                    source = bundle.extractfile(member)
                    require(source is not None, f"cannot read archive member: {member.name}")
                    name = path.as_posix().encode("utf-8")
                    digest.update(len(name).to_bytes(4, "big"))
                    digest.update(name)
                    digest.update(int(member.size).to_bytes(8, "big"))
                    for chunk in iter(lambda: source.read(1024 * 1024), b""):
                        digest.update(chunk)
    return digest.hexdigest()


def validate_base_manifest(manifest: dict[str, Any]) -> None:
    require(manifest.get("bundleVersion") == BASE_VERSION, "approved base is not bundle v19")
    require(manifest.get("cdnPrefix") == CDN_PREFIX, "approved v19 base is not on v5")
    require(manifest.get("complete") is True, "approved v19 base is incomplete")
    archive_sha = manifest.get("archiveSha256")
    archive_size = manifest.get("archiveSizeBytes")
    require(
        isinstance(archive_sha, str) and len(archive_sha) == 64,
        "approved v19 base has no archive SHA-256",
    )
    require(
        isinstance(archive_size, int) and archive_size > 0,
        "approved v19 base has no archive size",
    )


def fetch_base(
    *, output: Path, approved_root_sha256: str, cdn_base_env: str
) -> dict[str, Any]:
    require(
        len(approved_root_sha256) == 64
        and all(character in "0123456789abcdef" for character in approved_root_sha256),
        "approved v19 root manifest SHA-256 must be lowercase hexadecimal",
    )
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    base = _production_base(cdn_base_env)
    root_manifest = output / "base-root-manifest.json"
    _download(urljoin(base, "bundle-manifest.json"), root_manifest)
    require(
        sha256_file(root_manifest) == approved_root_sha256,
        "live root manifest differs from the approved local v19 manifest",
    )
    manifest = read_json(root_manifest)
    validate_base_manifest(manifest)

    archive_url = str(manifest.get("archiveUrl") or "")
    parsed_archive = urlparse(archive_url)
    parsed_base = urlparse(base)
    require(
        parsed_archive.scheme == "https" and parsed_archive.netloc == parsed_base.netloc,
        "approved v19 archive must use the configured production origin",
    )
    require(
        Path(parsed_archive.path).parent.name == CDN_PREFIX,
        "approved v19 archive is outside the active v5 prefix",
    )
    archive = output / "base-v19.tar.zst"
    _download(
        archive_url,
        archive,
        expected_size=int(manifest["archiveSizeBytes"]),
    )
    require(
        sha256_file(archive) == manifest["archiveSha256"],
        "downloaded v19 archive SHA-256 differs from the approved root manifest",
    )
    staging = output / "staging"
    _safe_extract_archive(archive, staging)
    local_manifest = read_json(staging / "manifest.json")
    require(local_manifest.get("version") == BASE_VERSION, "v19 archive staging manifest mismatch")
    require(local_manifest.get("complete") is True, "v19 archive staging is incomplete")
    require(
        _archive_tree_fingerprint(archive) == tree_fingerprint(staging),
        "v19 staging is not byte-bound to the approved archive",
    )
    rollback = output / "rollback" / "bundle-manifest-v19.json"
    rollback.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root_manifest, rollback)
    return {
        "bundleVersion": BASE_VERSION,
        "rootManifestSha256": approved_root_sha256,
        "archiveSha256": manifest["archiveSha256"],
        "archiveSizeBytes": manifest["archiveSizeBytes"],
        "baseTreeSha256": tree_fingerprint(staging),
        "rollbackArtifact": rollback.relative_to(output).as_posix(),
    }


def verify_release_inputs(
    *, candidate: Path, base_root_manifest: Path, base_archive: Path, base_staging: Path
) -> dict[str, Any]:
    base_root = read_json(base_root_manifest)
    validate_base_manifest(base_root)
    require(base_archive.stat().st_size == base_root["archiveSizeBytes"], "base archive size mismatch")
    require(sha256_file(base_archive) == base_root["archiveSha256"], "base archive SHA mismatch")
    base_tree_sha = tree_fingerprint(base_staging)
    require(
        _archive_tree_fingerprint(base_archive) == base_tree_sha,
        "local v19 staging is not bound to the approved archive",
    )
    report = read_json(candidate / "build-report.json")
    require(report.get("baseBundleVersion") == BASE_VERSION, "candidate lacks v19 lineage")
    require(report.get("baseUnchanged") is True, "candidate changed its v19 base")
    require(
        report.get("baseRootManifestSha256") == sha256_file(base_root_manifest),
        "candidate was built from a different v19 root manifest",
    )
    require(
        report.get("baseTreeSha256") == base_tree_sha,
        "candidate was built from a different v19 staging tree",
    )
    foundation = verify_candidate(candidate)
    reference = verify_reference(candidate / "staging")
    gameplay = verify_gameplay(candidate / "staging")
    return {
        "foundation": foundation,
        "reference": reference,
        "gameplay": gameplay,
        "baseRootManifestSha256": report["baseRootManifestSha256"],
        "baseTreeSha256": base_tree_sha,
    }


def prepare_release(
    *,
    candidate: Path,
    base_root_manifest: Path,
    base_archive: Path,
    base_staging: Path,
    output: Path,
    cdn_base_env: str,
    published_at: str | None,
) -> dict[str, Any]:
    verification = verify_release_inputs(
        candidate=candidate,
        base_root_manifest=base_root_manifest,
        base_archive=base_archive,
        base_staging=base_staging,
    )
    if output.exists():
        shutil.rmtree(output)
    objects_root = output / "objects"
    objects_root.mkdir(parents=True)
    selected = [
        item
        for item in changed_files(candidate / "upload", base_staging)
        if item[0] != "bundle-manifest.json"
    ]
    require(bool(selected), "v20 candidate has no changed objects")
    for key, source in selected:
        require(key.startswith(f"{CDN_PREFIX}/"), f"release object escapes v5: {key}")
        require(not key.startswith("v4/"), "release must never modify v4")
        destination = objects_root / key
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

    pending = read_json(
        candidate / "release-manifest" / "bundle-manifest.v20.candidate.json"
    )
    require(pending.get("bundleVersion") == TARGET_VERSION, "pending manifest is not v20")
    require(pending.get("baseBundleVersion") == BASE_VERSION, "pending manifest lacks v19 lineage")
    archive = objects_root / CDN_PREFIX / ARCHIVE_NAME
    require(archive.is_file(), "v20 archive is absent from the immutable-object stage")
    require(sha256_file(archive) == pending.get("archiveSha256"), "v20 archive SHA mismatch")
    require(archive.stat().st_size == pending.get("archiveSizeBytes"), "v20 archive size mismatch")

    production_base = _production_base(cdn_base_env)
    manifest = dict(pending)
    manifest.pop("archiveFile", None)
    manifest.pop("candidate", None)
    manifest["releaseState"] = "production"
    manifest["archiveUrl"] = urljoin(production_base, f"{CDN_PREFIX}/{ARCHIVE_NAME}")
    manifest["publishedAt"] = published_at or datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    root_path = output / "manifest" / "bundle-manifest.json"
    write_json(root_path, manifest)

    rollback = output / "rollback" / "bundle-manifest-v19.json"
    rollback.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(base_root_manifest, rollback)
    object_records = [
        {
            "key": key,
            "sizeBytes": source.stat().st_size,
            "sha256": sha256_file(source),
        }
        for key, source in selected
    ]
    plan = {
        "schemaVersion": 1,
        "baseBundleVersion": BASE_VERSION,
        "targetBundleVersion": TARGET_VERSION,
        "cdnPrefix": CDN_PREFIX,
        "baseRootManifestSha256": sha256_file(base_root_manifest),
        "targetRootManifestSha256": sha256_file(root_path),
        "objects": object_records,
        "objectCount": len(object_records),
        "objectBytes": sum(row["sizeBytes"] for row in object_records),
        "manifestLast": True,
        "v4Touched": False,
        "verifiers": ["foundation", "reference", "gameplay"],
    }
    write_json(output / "release-plan.json", plan)
    return {
        "baseBundleVersion": BASE_VERSION,
        "targetBundleVersion": TARGET_VERSION,
        "objects": plan["objectCount"],
        "objectBytes": plan["objectBytes"],
        "targetRootManifestSha256": plan["targetRootManifestSha256"],
        "verifiers": list(verification.keys())[:3],
        "manifestPublished": False,
    }


def assert_live_base(
    *, approved_manifest: Path, approved_sha256: str, cdn_base_env: str
) -> dict[str, Any]:
    require(sha256_file(approved_manifest) == approved_sha256, "rollback artifact is not the approved v19 manifest")
    approved = read_json(approved_manifest)
    validate_base_manifest(approved)
    with tempfile.TemporaryDirectory() as raw:
        live_path = Path(raw) / "live-root.json"
        _download(
            urljoin(_production_base(cdn_base_env), "bundle-manifest.json"),
            live_path,
        )
        require(
            sha256_file(live_path) == approved_sha256,
            "production root changed after v20 objects were staged",
        )
        live = read_json(live_path)
        require(
            live.get("archiveSha256") == approved.get("archiveSha256")
            and live.get("archiveSizeBytes") == approved.get("archiveSizeBytes"),
            "production v19 archive identity changed",
        )
    return {"bundleVersion": BASE_VERSION, "rootManifestSha256": approved_sha256}


def wait_live_target(
    *, target_manifest: Path, cdn_base_env: str, timeout: int, interval: int
) -> dict[str, Any]:
    target = read_json(target_manifest)
    target_version = target.get("bundleVersion")
    require(target_version in {BASE_VERSION, TARGET_VERSION}, "target manifest is not v19 or v20")
    target_sha = sha256_file(target_manifest)
    live_manifest_url = urljoin(
        _production_base(cdn_base_env), "bundle-manifest.json"
    )
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        with tempfile.TemporaryDirectory() as raw:
            live_path = Path(raw) / "live-root.json"
            try:
                _download(
                    live_manifest_url,
                    live_path,
                )
                live = read_json(live_path)
                if (
                    sha256_file(live_path) == target_sha
                    and live.get("bundleVersion") == target_version
                    and live.get("archiveSha256") == target.get("archiveSha256")
                    and live.get("archiveSizeBytes") == target.get("archiveSizeBytes")
                ):
                    return {
                        "bundleVersion": target_version,
                        "rootManifestSha256": target_sha,
                        "archiveSha256": target["archiveSha256"],
                        "archiveSizeBytes": target["archiveSizeBytes"],
                    }
            except (RuntimeError, ValueError, OSError):
                pass
        time.sleep(interval)
    raise RuntimeError("production root did not converge to the approved manifest")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    fetch = subparsers.add_parser("fetch-base")
    fetch.add_argument("--output", type=Path, required=True)
    fetch.add_argument("--approved-root-sha256", required=True)
    fetch.add_argument("--cdn-base-env", default="TITODEX_DEX_CDN_BASE")

    verify = subparsers.add_parser("verify")
    verify.add_argument("--candidate", type=Path, required=True)
    verify.add_argument("--base-root-manifest", type=Path, required=True)
    verify.add_argument("--base-archive", type=Path, required=True)
    verify.add_argument("--base-staging", type=Path, required=True)

    prepare = subparsers.add_parser("prepare")
    prepare.add_argument("--candidate", type=Path, required=True)
    prepare.add_argument("--base-root-manifest", type=Path, required=True)
    prepare.add_argument("--base-archive", type=Path, required=True)
    prepare.add_argument("--base-staging", type=Path, required=True)
    prepare.add_argument("--output", type=Path, required=True)
    prepare.add_argument("--cdn-base-env", default="TITODEX_DEX_CDN_BASE")
    prepare.add_argument("--published-at")

    live = subparsers.add_parser("assert-live-base")
    live.add_argument("--approved-manifest", type=Path, required=True)
    live.add_argument("--approved-sha256", required=True)
    live.add_argument("--cdn-base-env", default="TITODEX_DEX_CDN_BASE")

    wait = subparsers.add_parser("wait-live-target")
    wait.add_argument("--target-manifest", type=Path, required=True)
    wait.add_argument("--cdn-base-env", default="TITODEX_DEX_CDN_BASE")
    wait.add_argument("--timeout", type=int, default=600)
    wait.add_argument("--interval", type=int, default=10)

    args = parser.parse_args()
    if args.command == "fetch-base":
        result = fetch_base(
            output=args.output,
            approved_root_sha256=args.approved_root_sha256,
            cdn_base_env=args.cdn_base_env,
        )
    elif args.command == "verify":
        result = verify_release_inputs(
            candidate=args.candidate,
            base_root_manifest=args.base_root_manifest,
            base_archive=args.base_archive,
            base_staging=args.base_staging,
        )
    elif args.command == "prepare":
        result = prepare_release(
            candidate=args.candidate,
            base_root_manifest=args.base_root_manifest,
            base_archive=args.base_archive,
            base_staging=args.base_staging,
            output=args.output,
            cdn_base_env=args.cdn_base_env,
            published_at=args.published_at,
        )
    elif args.command == "assert-live-base":
        result = assert_live_base(
            approved_manifest=args.approved_manifest,
            approved_sha256=args.approved_sha256,
            cdn_base_env=args.cdn_base_env,
        )
    else:
        result = wait_live_target(
            target_manifest=args.target_manifest,
            cdn_base_env=args.cdn_base_env,
            timeout=args.timeout,
            interval=args.interval,
        )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
