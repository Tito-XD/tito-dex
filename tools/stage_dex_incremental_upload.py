#!/usr/bin/env python3
"""Stage only changed bundle objects plus the root manifest for R2 upload."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

from publish_dex_bundle_incremental import changed_files


def stage_incremental(target: Path, base: Path, output: Path) -> dict[str, int]:
    if output.exists():
        shutil.rmtree(output)
    selected = changed_files(target, base)
    for key, source in selected:
        destination = output / key
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    root_manifest = output / "bundle-manifest.json"
    if not root_manifest.is_file():
        raise RuntimeError("Incremental upload is missing bundle-manifest.json")
    versioned = [entry for entry in selected if entry[0] != "bundle-manifest.json"]
    return {
        "objects": len(versioned),
        "bytes": sum(path.stat().st_size for _, path in versioned),
        "rootManifest": 1,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", type=Path, help="Full target upload tree")
    parser.add_argument("--base-v5", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    summary = stage_incremental(args.target, args.base_v5, args.output)
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
