#!/usr/bin/env python3
"""Incrementally publish local bundle versions to R2 via wrangler OAuth.

Only files that changed between consecutive local upload trees are uploaded,
then the root manifest is switched last after asserting the live production
version. Rollback manifests are saved under ``dist/rollback/``.

Usage:
  python3 tools/publish_dex_bundle_incremental.py \
    --versions v14=dist/dex-v14/upload v15=dist/dex-v15/upload \
               v16=dist/dex-v16/upload v17=dist/dex-v17/upload \
    --base-v5 dist/dex-audit/extracted
"""

from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
import shutil
import subprocess
import sys
import time
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CDN_BASE = "https://dex.tito.cafe"
BUCKET = "titodex-dex"
USER_AGENT = "TitoDex-release/1.0"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def bundle_files(upload_dir: Path, prefix: str = "v5") -> list[tuple[str, Path]]:
    versioned = upload_dir / prefix
    files = [
        (f"{prefix}/{file.relative_to(versioned).as_posix()}", file)
        for file in sorted(versioned.rglob("*"))
        if file.is_file()
    ]
    root_manifest = upload_dir / "bundle-manifest.json"
    if root_manifest.is_file():
        files.append(("bundle-manifest.json", root_manifest))
    return files


def v5_files(base: Path) -> list[tuple[str, Path]]:
    """Enumerate files when ``base`` may be either an upload dir or a v5 root."""
    if (base / "v5").is_dir():
        return bundle_files(base)
    files = [
        (f"v5/{file.relative_to(base).as_posix()}", file)
        for file in sorted(base.rglob("*"))
        if file.is_file()
    ]
    return files


def changed_files(
    target: Path, base: Path | None
) -> list[tuple[str, Path]]:
    target_files = {key: path for key, path in bundle_files(target)}
    if base is None:
        return sorted(target_files.items())
    base_files = {key: path for key, path in v5_files(base)}
    changed: list[tuple[str, Path]] = []
    for key, path in target_files.items():
        base_path = base_files.get(key)
        if base_path is None or base_path.stat().st_size != path.stat().st_size:
            changed.append((key, path))
            continue
        if sha256(base_path) != sha256(path):
            changed.append((key, path))
    return changed


def live_manifest() -> dict:
    request = urllib.request.Request(
        f"{CDN_BASE}/bundle-manifest.json",
        headers={"User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def wait_live_version(
    expected: int, *, timeout: float = 480.0, interval: float = 10.0
) -> None:
    """Poll the public manifest (CDN/KV cached up to ~5 min) until it flips."""
    deadline = time.monotonic() + timeout
    last_actual: int | None = None
    while time.monotonic() < deadline:
        try:
            last_actual = int(live_manifest()["bundleVersion"])
        except (OSError, ValueError, KeyError):
            last_actual = None
        if last_actual == expected:
            print(f"live bundleVersion={expected} confirmed", flush=True)
            return
        print(
            f"  waiting for live bundleVersion={expected} "
            f"(current={last_actual}) ...",
            flush=True,
        )
        time.sleep(interval)
    raise RuntimeError(
        f"live bundleVersion is still {last_actual}, expected {expected}"
    )


def upload_keys(
    keys: list[tuple[str, Path]],
    wrangler_dir: Path,
    *,
    workers: int = 6,
    resume_log: Path | None = None,
) -> None:
    if not keys:
        print("no changed objects", flush=True)
        return
    done: set[str] = set()
    if resume_log and resume_log.is_file():
        done = {
            line[2:].strip()
            for line in resume_log.read_text(encoding="utf-8").splitlines()
            if line.startswith("✓ ")
        }
        remaining = [(key, path) for key, path in keys if key not in done]
        print(
            f"resume: {len(done)} already uploaded, {len(remaining)} to go",
            flush=True,
        )
        keys = remaining
        if not keys:
            print("all objects already uploaded", flush=True)
            return
    print(f"uploading {len(keys)} objects ...", flush=True)

    def put(item: tuple[str, Path]) -> str:
        key, file = item
        content_type = (
            mimetypes.guess_type(str(file))[0] or "application/octet-stream"
        )
        node_exe = shutil.which("node") or os.environ.get(
            "CODEX_NODE",
            r"C:\c\Users\tito\.npm-global\node.exe",
        )
        cli_js = (
            wrangler_dir / "node_modules" / "wrangler" / "wrangler-dist" / "cli.js"
        )
        cmd = [
            node_exe,
            str(cli_js),
            "r2",
            "object",
            "put",
            f"{BUCKET}/{key}",
            f"--file={file.resolve()}",
            "--remote",
            f"--content-type={content_type}",
        ]
        last_error: BaseException | None = None
        for attempt in range(6):
            try:
                subprocess.run(
                    cmd, check=True, cwd=wrangler_dir, capture_output=True
                )
                if resume_log is not None:
                    resume_log.parent.mkdir(parents=True, exist_ok=True)
                    with resume_log.open("a", encoding="utf-8") as log:
                        log.write(f"✓ {key}\n")
                return key
            except subprocess.CalledProcessError as exc:
                last_error = exc
                time.sleep(min(60.0, 2.0 ** attempt))
        raise last_error  # type: ignore[misc]

    with ThreadPoolExecutor(max_workers=workers) as executor:
        for index, key in enumerate(executor.map(put, keys), start=1):
            if index % 50 == 0 or index == len(keys):
                print(f"  uploaded {index}/{len(keys)}", flush=True)


def verify_public(keys: list[tuple[str, Path]]) -> None:
    for index, (key, file) in enumerate(keys, start=1):
        last_error: BaseException | None = None
        for attempt in range(4):
            try:
                request = urllib.request.Request(
                    f"{CDN_BASE}/{key}",
                    method="HEAD",
                    headers={"User-Agent": USER_AGENT},
                )
                with urllib.request.urlopen(request, timeout=20) as response:
                    size = response.headers.get("Content-Length")
                    if size and int(size) != file.stat().st_size:
                        raise RuntimeError(f"{key}: size mismatch")
                last_error = None
                break
            except (urllib.error.HTTPError, OSError, RuntimeError) as exc:
                last_error = exc
                time.sleep(3 * (attempt + 1))
        if last_error is not None:
            raise RuntimeError(f"{key}: verify failed: {last_error}") from last_error
        if index % 100 == 0 or index == len(keys):
            print(f"  verified {index}/{len(keys)}", flush=True)
    print(f"verified {len(keys)} public objects", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--versions",
        nargs="+",
        required=True,
        help="version=upload_dir pairs, e.g. v14=dist/dex-v14/upload",
    )
    parser.add_argument(
        "--base-v5",
        type=Path,
        help="Extracted v5 tree of the live production version (first diff base)",
    )
    parser.add_argument(
        "--wrangler-dir",
        type=Path,
        default=ROOT / "cloudflare" / "dex-cdn",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=1,
        help="Concurrent wrangler uploads (1 is safest on Windows)",
    )
    parser.add_argument("--skip-verify", action="store_true")
    parser.add_argument(
        "--resume-log",
        type=Path,
        default=ROOT / "dist" / "rollback" / "dex-upload.log",
    )
    args = parser.parse_args()

    versions: list[tuple[str, Path]] = []
    for item in args.versions:
        version, _, raw_dir = item.partition("=")
        versions.append((version, Path(raw_dir)))

    rollback_dir = ROOT / "dist" / "rollback"
    rollback_dir.mkdir(parents=True, exist_ok=True)
    previous: Path | None = args.base_v5

    for version, upload_dir in versions:
        expected = int(version[1:])
        changed = changed_files(upload_dir, previous)
        wait_live_version(expected - 1)
        # Save the pre-switch live manifest for rollback.
        live = live_manifest()
        (rollback_dir / f"bundle-manifest-v{live['bundleVersion']}.json").write_text(
            json.dumps(live, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        objects = [item for item in changed if item[0] != "bundle-manifest.json"]
        upload_keys(
            objects,
            args.wrangler_dir,
            workers=args.workers,
            resume_log=args.resume_log,
        )
        if not args.skip_verify and objects:
            verify_public(objects)
        # Switch root manifest last.
        upload_keys(
            [item for item in changed if item[0] == "bundle-manifest.json"],
            args.wrangler_dir,
            workers=1,
            resume_log=None,
        )
        wait_live_version(expected)
        print(f"✅ {version} live: bundleVersion={expected}", flush=True)
        previous = upload_dir

    print("done: incremental publish complete", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
