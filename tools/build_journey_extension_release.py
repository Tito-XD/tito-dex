#!/usr/bin/env python3
"""Stage an immutable Journey Assistant APK and its CDN catalog.

The Android host treats the catalog as transport metadata only. Before opening
the system installer it independently checks the downloaded APK package,
provider contract, and signing certificate against the installed TitoDex app.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path


PACKAGE_ID = "com.tito.titodex.extension.journeyassistant"
EXTENSION_ID = "journey_assistant"
MAX_APK_BYTES = 512 * 1024 * 1024
VERSION_NAME = re.compile(r"^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$")
HOST_VERSION = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


def stage_release(
    apk: Path,
    output: Path,
    *,
    version_name: str,
    version_code: int,
    min_host_version: str,
) -> dict:
    if not apk.is_file():
        raise ValueError(f"APK does not exist: {apk}")
    if version_code < 1:
        raise ValueError("version_code must be positive")
    if not VERSION_NAME.fullmatch(version_name):
        raise ValueError("version_name contains unsupported characters")
    if not HOST_VERSION.fullmatch(min_host_version):
        raise ValueError("min_host_version must be x.y.z")
    source = apk.read_bytes()
    if not source or len(source) > MAX_APK_BYTES:
        raise ValueError("APK size is outside the supported range")
    digest = hashlib.sha256(source).hexdigest()
    immutable_name = (
        f"titodex-journey-assistant-{version_name}-{version_code}-{digest[:12]}.apk"
    )
    objects = output / "objects"
    objects.mkdir(parents=True, exist_ok=True)
    staged_apk = objects / immutable_name
    if staged_apk.exists() and staged_apk.read_bytes() != source:
        raise ValueError(f"immutable output already exists with other bytes: {staged_apk}")
    if not staged_apk.exists():
        shutil.copyfile(apk, staged_apk)

    catalog = {
        "schemaVersion": 1,
        "entries": [
            {
                "extensionId": EXTENSION_ID,
                "packageId": PACKAGE_ID,
                "versionName": version_name,
                "versionCode": version_code,
                "minHostVersion": min_host_version,
                "displayNameZh": "TitoDex 旅程助手扩展",
                "summaryZh": "按需安装的存档优先卡关资料、模糊检索与可选在线 AI 能力。",
                "downloadPath": f"objects/{immutable_name}",
                "sizeBytes": len(source),
                "sha256": digest,
                "capabilities": ["progression_hints", "online_ai_search"],
            }
        ],
    }
    output.mkdir(parents=True, exist_ok=True)
    (output / "extension-catalog.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return catalog


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--version-code", required=True, type=int)
    parser.add_argument("--min-host-version", default="0.8.13")
    args = parser.parse_args()
    stage_release(
        args.apk,
        args.output,
        version_name=args.version_name,
        version_code=args.version_code,
        min_host_version=args.min_host_version,
    )


if __name__ == "__main__":
    main()
