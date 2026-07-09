#!/usr/bin/env python3
"""Upload prebuilt dex bundle to R2 via S3-compatible API or wrangler."""

from __future__ import annotations

import argparse
import mimetypes
import os
import subprocess
import sys
from pathlib import Path


def upload_with_wrangler(upload_dir: Path, bucket: str) -> None:
    v2 = upload_dir / "v2"
    wrangler = os.environ.get("WRANGLER", "wrangler")
    if subprocess.run(["which", wrangler], capture_output=True).returncode != 0:
        wrangler = "npx"
        prefix = ["npx", "wrangler"]
    else:
        prefix = [wrangler]

    def put(key: str, file: Path, content_type: str | None = None) -> None:
        cmd = [*prefix, "r2", "object", "put", f"{bucket}/{key}", f"--file={file}"]
        if content_type:
            cmd.append(f"--content-type={content_type}")
        print(f"→ {key}")
        subprocess.run(cmd, check=True)

    put("bundle-manifest.json", upload_dir / "bundle-manifest.json", "application/json")
    for name in ("manifest.json", "summaries.json", "types.json", "moves.json", "bundle.tar.zst"):
        ct = "application/json" if name.endswith(".json") else "application/octet-stream"
        put(f"v2/{name}", v2 / name, ct)

    for folder, default_ct in (("details", "application/json"), ("sprites", "image/png"), ("type_icons", "image/png")):
        for file in sorted((v2 / folder).rglob("*")):
            if file.is_file():
                rel = file.relative_to(v2).as_posix()
                put(f"v2/{rel}", file, default_ct)


def upload_with_boto3(upload_dir: Path, bucket: str, endpoint: str) -> None:
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
    v2 = upload_dir / "v2"

    def put(key: str, file: Path) -> None:
        ct = mimetypes.guess_type(str(file))[0] or "application/octet-stream"
        print(f"→ {key}")
        client.upload_file(str(file), bucket, key, ExtraArgs={"ContentType": ct})

    put("bundle-manifest.json", upload_dir / "bundle-manifest.json")
    for file in v2.rglob("*"):
        if file.is_file():
            put(f"v2/{file.relative_to(v2).as_posix()}", file)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("upload_dir", type=Path, default=Path("dist/dex-v2/upload"), nargs="?")
    parser.add_argument("--bucket", default="titodex-dex")
    args = parser.parse_args()

    if not args.upload_dir.exists():
        print(f"Missing {args.upload_dir}", file=sys.stderr)
        sys.exit(1)

    account_id = os.environ.get("CLOUDFLARE_ACCOUNT_ID")
    if os.environ.get("R2_ACCESS_KEY_ID") and os.environ.get("R2_SECRET_ACCESS_KEY") and account_id:
        upload_with_boto3(
            args.upload_dir,
            args.bucket,
            f"https://{account_id}.r2.cloudflarestorage.com",
        )
    elif os.environ.get("CLOUDFLARE_API_TOKEN") and account_id:
        upload_with_wrangler(args.upload_dir, args.bucket)
    else:
        print(
            "Set CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID (wrangler)\n"
            "or R2_ACCESS_KEY_ID + R2_SECRET_ACCESS_KEY + CLOUDFLARE_ACCOUNT_ID (boto3)",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
