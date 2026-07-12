#!/usr/bin/env python3
"""Upload prebuilt dex bundle to R2 via S3-compatible API or wrangler."""

from __future__ import annotations

import argparse
import mimetypes
import os
import subprocess
import sys
from pathlib import Path

DEFAULT_CDN_PREFIX = "v3"
LEGACY_CDN_PREFIX = "v2"


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
    if cdn_prefix == DEFAULT_CDN_PREFIX and (upload_dir / LEGACY_CDN_PREFIX).is_dir():
        print(
            f"Note: {bundle_dir} missing; falling back to upload/{LEGACY_CDN_PREFIX}",
            file=sys.stderr,
        )
        return upload_dir / LEGACY_CDN_PREFIX
    raise FileNotFoundError(f"Missing bundle directory: {bundle_dir}")


def upload_with_wrangler(upload_dir: Path, bucket: str, cdn_prefix: str) -> None:
    bundle_dir = resolve_bundle_dir(upload_dir, cdn_prefix)
    wrangler = os.environ.get("WRANGLER", "wrangler")
    if subprocess.run(["which", wrangler], capture_output=True).returncode != 0:
        wrangler = "npx"
        prefix = ["npx", "wrangler"]
    else:
        prefix = [wrangler]

    def put(key: str, file: Path, content_type: str | None = None) -> None:
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
        print(f"→ {key}", flush=True)
        subprocess.run(cmd, check=True)

    put("bundle-manifest.json", upload_dir / "bundle-manifest.json", "application/json")
    for name in (
        "manifest.json",
        "summaries.json",
        "types.json",
        "moves.json",
        "abilities.json",
        "games.json",
        "natures.json",
        "egg_groups.json",
        "status_conditions.json",
        "weather.json",
        "terrains.json",
        "items.json",
        "bundle.tar.zst",
    ):
        file = bundle_dir / name
        if not file.exists():
            if name in ("abilities.json", "games.json", "natures.json", "egg_groups.json",
                        "status_conditions.json", "weather.json", "terrains.json", "items.json"):
                print(f"  skip missing {name} (pre-v0.4.0 bundle)", file=sys.stderr)
                continue
            raise FileNotFoundError(file)
        ct = "application/json" if name.endswith(".json") else "application/octet-stream"
        put(f"{cdn_prefix}/{name}", file, ct)

    for folder, default_ct in (
        ("details", "application/json"),
        ("sprites", "image/png"),
        ("artwork", "image/png"),
        ("type_icons", "image/png"),
        ("game_icons", "image/png"),
    ):
        folder_path = bundle_dir / folder
        if not folder_path.exists():
            continue
        for file in sorted(folder_path.rglob("*")):
            if file.is_file():
                rel = file.relative_to(bundle_dir).as_posix()
                put(f"{cdn_prefix}/{rel}", file, default_ct)


def upload_with_boto3(
    upload_dir: Path, bucket: str, endpoint: str, cdn_prefix: str
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

    put("bundle-manifest.json", upload_dir / "bundle-manifest.json")
    for file in bundle_dir.rglob("*"):
        if file.is_file():
            put(f"{cdn_prefix}/{file.relative_to(bundle_dir).as_posix()}", file)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "upload_dir",
        type=Path,
        default=Path("dist/dex-v5/upload"),
        nargs="?",
    )
    parser.add_argument("--bucket", default="titodex-dex")
    parser.add_argument(
        "--cdn-prefix",
        default=DEFAULT_CDN_PREFIX,
        help=f"CDN path prefix under bucket (default: {DEFAULT_CDN_PREFIX}; use v2 for legacy)",
    )
    args = parser.parse_args()

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
        )
    elif os.environ.get("CLOUDFLARE_API_TOKEN") or _wrangler_oauth_ready():
        upload_with_wrangler(args.upload_dir, args.bucket, args.cdn_prefix)
    else:
        print(
            "Run `wrangler login`, or set CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID,\n"
            "or R2_ACCESS_KEY_ID + R2_SECRET_ACCESS_KEY + CLOUDFLARE_ACCOUNT_ID",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
