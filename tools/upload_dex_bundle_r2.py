#!/usr/bin/env python3
"""Upload prebuilt dex bundle to R2 via S3-compatible API or wrangler."""

from __future__ import annotations

import argparse
import mimetypes
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from threading import Lock
from pathlib import Path

DEFAULT_CDN_PREFIX = "v4"


def _wrangler_oauth_ready() -> bool:
    wrangler = os.environ.get("WRANGLER", "wrangler")
    prefix = ["npx", wrangler] if subprocess.run(
        ["which", wrangler], capture_output=True
    ).returncode != 0 else [wrangler]
    result = subprocess.run(
        [*prefix, "whoami"],
        capture_output=True,
        text=True,
    )
    return result.returncode == 0 and "logged in" in result.stdout.lower()


def resolve_bundle_dir(upload_dir: Path, cdn_prefix: str) -> Path:
    bundle_dir = upload_dir / cdn_prefix
    if bundle_dir.is_dir():
        return bundle_dir
    raise FileNotFoundError(f"Missing bundle directory: {bundle_dir}")


def load_uploaded_keys(log_path: Path | None) -> set[str]:
    uploaded: set[str] = set()
    if log_path is None or not log_path.exists():
        return uploaded
    for line in log_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("✓ "):
            uploaded.add(line[2:].strip())
    return uploaded


def bundle_files(bundle_dir: Path, cdn_prefix: str) -> list[tuple[str, Path]]:
    return [
        (f"{cdn_prefix}/{file.relative_to(bundle_dir).as_posix()}", file)
        for file in sorted(bundle_dir.rglob("*"))
        if file.is_file()
    ]


def verify_public_objects(
    objects: list[tuple[str, Path]], *, cdn_base: str, workers: int = 16
) -> None:
    def verify(item: tuple[str, Path]) -> str:
        key, file = item
        request = urllib.request.Request(
            f"{cdn_base.rstrip('/')}/{key}",
            method="HEAD",
            headers={"User-Agent": "TitoDex-release-verifier/1.0"},
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                if response.status != 200:
                    raise RuntimeError(f"HTTP {response.status}")
                remote_size = response.headers.get("Content-Length")
                if remote_size and int(remote_size) != file.stat().st_size:
                    raise RuntimeError(
                        f"size mismatch: local={file.stat().st_size} remote={remote_size}"
                    )
        except (OSError, urllib.error.HTTPError) as exc:
            raise RuntimeError(f"{key}: {exc}") from exc
        return key

    print(f"Verifying {len(objects)} public CDN objects…", flush=True)
    with ThreadPoolExecutor(max_workers=workers) as executor:
        for index, _key in enumerate(executor.map(verify, objects), start=1):
            if index % 250 == 0 or index == len(objects):
                print(f"  verified {index}/{len(objects)}", flush=True)


def upload_with_wrangler(
    upload_dir: Path,
    bucket: str,
    cdn_prefix: str,
    *,
    phase: str,
    cdn_base: str,
    verify: bool,
    workers: int,
    resume: bool = False,
    resume_log: Path | None = None,
) -> None:
    bundle_dir = resolve_bundle_dir(upload_dir, cdn_prefix)
    wrangler = os.environ.get("WRANGLER", "wrangler")
    if subprocess.run(["which", wrangler], capture_output=True).returncode != 0:
        wrangler = "npx"
        prefix = ["npx", "wrangler"]
    else:
        prefix = [wrangler]

    uploaded = load_uploaded_keys(resume_log) if resume else set()
    upload_lock = Lock()

    def put(key: str, file: Path, content_type: str | None = None) -> None:
        with upload_lock:
            if resume and key in uploaded:
                print(f"  skip {key} (already uploaded)", flush=True)
                return
        cmd = [
            *prefix,
            "r2",
            "object",
            "put",
            f"{bucket}/{key}",
            f"--file={file}",
            "--remote",
        ]
        if content_type:
            cmd.append(f"--content-type={content_type}")
        last_error: Exception | None = None
        for attempt in range(6):
            try:
                print(f"→ {key}", flush=True)
                subprocess.run(cmd, check=True)
                with upload_lock:
                    uploaded.add(key)
                    if resume and resume_log is not None:
                        resume_log.parent.mkdir(parents=True, exist_ok=True)
                        with resume_log.open("a", encoding="utf-8") as log:
                            log.write(f"✓ {key}\n")
                print(f"✓ {key}", flush=True)
                return
            except subprocess.CalledProcessError as exc:
                last_error = exc
                wait = min(60.0, 2.0 ** attempt)
                print(
                    f"  warn: upload retry {attempt + 1}/6 {key}: {exc}",
                    file=sys.stderr,
                    flush=True,
                )
                time.sleep(wait)
        raise last_error  # type: ignore[misc]

    objects = bundle_files(bundle_dir, cdn_prefix)
    if phase in ("objects", "all"):
        def upload_item(item: tuple[str, Path]) -> None:
            key, file = item
            put(
                key,
                file,
                mimetypes.guess_type(str(file))[0] or "application/octet-stream",
            )

        with ThreadPoolExecutor(max_workers=workers) as executor:
            list(executor.map(upload_item, objects))
        if verify:
            verify_public_objects(objects, cdn_base=cdn_base)
    if phase in ("manifest", "all"):
        put("bundle-manifest.json", upload_dir / "bundle-manifest.json", "application/json")


def upload_with_boto3(
    upload_dir: Path,
    bucket: str,
    endpoint: str,
    cdn_prefix: str,
    *,
    phase: str,
    verify: bool,
    workers: int,
) -> None:
    import boto3
    from botocore.config import Config

    client = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=os.environ["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["R2_SECRET_ACCESS_KEY"],
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )
    bundle_dir = resolve_bundle_dir(upload_dir, cdn_prefix)

    def put(key: str, file: Path) -> None:
        ct = mimetypes.guess_type(str(file))[0] or "application/octet-stream"
        print(f"→ {key}")
        client.upload_file(str(file), bucket, key, ExtraArgs={"ContentType": ct})

    objects = bundle_files(bundle_dir, cdn_prefix)
    if phase in ("objects", "all"):
        with ThreadPoolExecutor(max_workers=workers) as executor:
            list(executor.map(lambda item: put(*item), objects))
        if verify:
            print(f"Verifying {len(objects)} R2 objects…")
            def verify_item(item: tuple[str, Path]) -> None:
                key, file = item
                head = client.head_object(Bucket=bucket, Key=key)
                if head["ContentLength"] != file.stat().st_size:
                    raise RuntimeError(f"R2 size mismatch for {key}")

            with ThreadPoolExecutor(max_workers=workers * 2) as executor:
                list(executor.map(verify_item, objects))
    if phase in ("manifest", "all"):
        put("bundle-manifest.json", upload_dir / "bundle-manifest.json")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "upload_dir",
        type=Path,
        default=Path("dist/dex-v6/upload"),
        nargs="?",
    )
    parser.add_argument("--bucket", default="titodex-dex")
    parser.add_argument(
        "--cdn-prefix",
        default=DEFAULT_CDN_PREFIX,
        help=f"CDN path prefix under bucket (default: {DEFAULT_CDN_PREFIX})",
    )
    parser.add_argument(
        "--phase",
        choices=("all", "objects", "manifest"),
        default="all",
        help="Two-phase release control. 'all' uploads+verifies versioned objects before the root manifest.",
    )
    parser.add_argument("--cdn-base", default="https://dex.tito.cafe")
    parser.add_argument("--skip-verify", action="store_true")
    parser.add_argument(
        "--workers",
        type=int,
        default=8,
        help="Concurrent object uploads (default: 8)",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Skip keys already listed with → in --resume-log",
    )
    parser.add_argument(
        "--resume-log",
        type=Path,
        default=Path("/tmp/dex-upload.log"),
        help="Log file listing prior successful uploads (default: /tmp/dex-upload.log)",
    )
    args = parser.parse_args()
    if args.workers < 1 or args.workers > 32:
        parser.error("--workers must be between 1 and 32")

    if not args.upload_dir.exists():
        print(f"Missing {args.upload_dir}", file=sys.stderr)
        sys.exit(1)

    try:
        resolve_bundle_dir(args.upload_dir, args.cdn_prefix)
    except FileNotFoundError as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)

    account_id = os.environ.get("CLOUDFLARE_ACCOUNT_ID", "e84aed053d6584bebf0f8a6e4870cd8c")
    if os.environ.get("R2_ACCESS_KEY_ID") and os.environ.get("R2_SECRET_ACCESS_KEY"):
        upload_with_boto3(
            args.upload_dir,
            args.bucket,
            f"https://{account_id}.r2.cloudflarestorage.com",
            args.cdn_prefix,
            phase=args.phase,
            verify=not args.skip_verify,
            workers=args.workers,
        )
    elif os.environ.get("CLOUDFLARE_API_TOKEN") or _wrangler_oauth_ready():
        upload_with_wrangler(
            args.upload_dir,
            args.bucket,
            args.cdn_prefix,
            phase=args.phase,
            cdn_base=args.cdn_base,
            verify=not args.skip_verify,
            workers=args.workers,
            resume=args.resume,
            resume_log=args.resume_log,
        )
    else:
        print(
            "Run `wrangler login`, or set CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID,\n"
            "or R2_ACCESS_KEY_ID + R2_SECRET_ACCESS_KEY + CLOUDFLARE_ACCOUNT_ID",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
