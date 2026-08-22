#!/usr/bin/env python3
"""Upload verified Journey packs to R2 with immutable objects first, catalog last."""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

from verify_journey_data_packs import EXPECTED_BUCKET, verify_candidate_dir


def wrangler_prefix() -> list[str]:
    configured = os.environ.get("WRANGLER", "wrangler")
    executable = shutil.which(configured)
    return [executable] if executable else ["npx", "wrangler"]


def run_wrangler(arguments: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [*wrangler_prefix(), *arguments],
        capture_output=True,
        check=False,
    )


def read_remote(bucket: str, key: str) -> bytes | None:
    with tempfile.TemporaryDirectory(prefix="titodex-journey-readback-") as temporary:
        target = Path(temporary) / "object"
        result = run_wrangler(
            [
                "r2",
                "object",
                "get",
                f"{bucket}/{key}",
                f"--file={target}",
                "--remote",
            ]
        )
        if result.returncode == 0 and target.is_file():
            return target.read_bytes()
        combined = (result.stdout + result.stderr).decode("utf-8", errors="replace").lower()
        if "not found" in combined or "nosuchkey" in combined or "404" in combined:
            return None
        raise RuntimeError(f"unable to read back R2 object {key}")


def put_remote(bucket: str, key: str, source: Path, content_type: str) -> None:
    result = run_wrangler(
        [
            "r2",
            "object",
            "put",
            f"{bucket}/{key}",
            f"--file={source}",
            f"--content-type={content_type}",
            "--remote",
        ]
    )
    if result.returncode != 0:
        raise RuntimeError(f"unable to upload R2 object {key}")


def verify_bytes(body: bytes, record: dict[str, Any], label: str) -> None:
    if len(body) != record["sizeBytes"]:
        raise RuntimeError(f"{label} readback size mismatch")
    if hashlib.sha256(body).hexdigest() != record["sha256"]:
        raise RuntimeError(f"{label} readback hash mismatch")


def upload_candidate(
    candidate: Path,
    *,
    publish_catalog: bool,
    dry_run: bool,
) -> None:
    verified = verify_candidate_dir(candidate)
    plan = verified["plan"]
    bucket = plan["bucket"]
    if bucket != EXPECTED_BUCKET:
        raise RuntimeError("refusing an unexpected R2 bucket")

    print(
        f"verified {verified['packCount']} packs / "
        f"{verified['entryCount']} entries for two-phase upload"
    )
    if dry_run:
        print("dry run: immutable objects would be uploaded and read back first")
        print("dry run: catalog publication remains the final explicit phase")
        return

    for record in plan["objects"]:
        source = candidate / record["sourcePath"]
        remote = read_remote(bucket, record["objectKey"])
        if remote is not None:
            try:
                verify_bytes(remote, record, record["objectKey"])
            except RuntimeError as exc:
                raise RuntimeError(
                    f"immutable key already exists with different bytes: {record['objectKey']}"
                ) from exc
            print(f"verified existing immutable object {record['objectKey']}")
            continue
        put_remote(bucket, record["objectKey"], source, record["contentType"])
        readback = read_remote(bucket, record["objectKey"])
        if readback is None:
            raise RuntimeError(f"missing R2 readback for {record['objectKey']}")
        verify_bytes(readback, record, record["objectKey"])
        print(f"uploaded and verified immutable object {record['objectKey']}")

    if not publish_catalog:
        print("immutable objects are verified; catalog was not published")
        print("rerun with --publish-catalog to make this candidate discoverable")
        return

    catalog = plan["catalog"]
    source = candidate / catalog["sourcePath"]
    put_remote(bucket, catalog["objectKey"], source, catalog["contentType"])
    readback = read_remote(bucket, catalog["objectKey"])
    if readback is None:
        raise RuntimeError("catalog readback is missing")
    verify_bytes(readback, catalog, catalog["objectKey"])
    print("published and verified Journey catalog last")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=Path)
    parser.add_argument(
        "--upload",
        action="store_true",
        help="perform R2 writes; without this flag the command is a dry run",
    )
    parser.add_argument(
        "--publish-catalog",
        action="store_true",
        help="after all immutable readbacks pass, publish catalog.json last",
    )
    args = parser.parse_args()
    if args.publish_catalog and not args.upload:
        parser.error("--publish-catalog requires --upload")
    upload_candidate(
        args.candidate.resolve(),
        publish_catalog=args.publish_catalog,
        dry_run=not args.upload,
    )


if __name__ == "__main__":
    main()
