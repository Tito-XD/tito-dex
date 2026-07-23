#!/usr/bin/env python3
"""Stage l10n / maps / config slices for incremental CDN upload."""

from __future__ import annotations

import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "dist" / "l10n-upload"
CDN_PREFIX = "v5"


def _import_build_helpers():
    sys.path.insert(0, str(ROOT / "tools"))
    from build_dex_bundle import (  # noqa: WPS433
        DEFAULT_APP_CONFIG,
        APP_CONFIG_VERSION,
        build_hgss_map_list_with_zh,
        write_json,
    )

    return DEFAULT_APP_CONFIG, APP_CONFIG_VERSION, build_hgss_map_list_with_zh, write_json


def stage_l10n_upload(output_dir: Path) -> dict[str, str | int]:
    """Copy compact l10n assets + maps + config into [output_dir]/v5/…"""
    from generate_zh_catalog_assets import write_compact_l10n

    DEFAULT_APP_CONFIG, APP_CONFIG_VERSION, build_hgss_map_list_with_zh, write_json = (
        _import_build_helpers()
    )

    version_root = output_dir / CDN_PREFIX
    l10n_dir = version_root / "l10n" / "zh"
    maps_dir = version_root / "maps"
    config_dir = version_root / "config"

    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)

    l10n_stats = write_compact_l10n(l10n_dir)

    maps_dir.mkdir(parents=True, exist_ok=True)
    hgss_map_list = build_hgss_map_list_with_zh()
    write_json(maps_dir / "hgss_map_list.json", hgss_map_list)

    published_at = datetime.now(timezone.utc).isoformat()
    config_dir.mkdir(parents=True, exist_ok=True)
    app_config = {
        **DEFAULT_APP_CONFIG,
        "publishedAt": published_at,
    }
    write_json(config_dir / "app_config.json", app_config)

    l10n_version = str(l10n_stats.get("l10nVersion") or published_at)

    return {
        "l10nVersion": l10n_version,
        "configVersion": APP_CONFIG_VERSION,
        "outputDir": str(output_dir),
        "l10nFileCount": len(list(l10n_dir.glob("*.json"))),
        "hgssMapCount": len(hgss_map_list),
    }


def _fetch_remote_manifest(url: str) -> dict[str, object]:
    import urllib.request

    request = urllib.request.Request(
        url,
        headers={"User-Agent": "TitoDex-maintainer/1.0 (+https://github.com/Tito-XD/tito-dex)"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))  # type: ignore[return-value]


def update_bundle_manifest(
    output_dir: Path,
    *,
    l10n_version: str,
    config_version: int,
    remote_manifest_path: Path | None = None,
) -> Path:
    """Write bundle-manifest.json with updated l10nVersion / publishedAt."""
    manifest: dict[str, object] = {}
    if remote_manifest_path and remote_manifest_path.is_file():
        manifest = json.loads(remote_manifest_path.read_text(encoding="utf-8"))
    else:
        url = "https://dex.tito.cafe/bundle-manifest.json"
        try:
            manifest = _fetch_remote_manifest(url)
        except OSError as exc:
            raise RuntimeError(
                "refusing to stage a root manifest without the current published manifest"
            ) from exc

    required = {
        "bundleVersion": 7,
        "cdnPrefix": "v5",
        "pokemonCount": 1025,
        "complete": True,
    }
    for key, expected in required.items():
        if manifest.get(key) != expected:
            raise RuntimeError(
                f"refusing l10n update: root manifest {key}={manifest.get(key)!r}, "
                f"expected {expected!r}"
            )
    if not manifest.get("archiveSha256"):
        raise RuntimeError("refusing l10n update: current root manifest has no archive SHA")

    manifest["l10nVersion"] = l10n_version
    manifest["configVersion"] = config_version
    manifest["publishedAt"] = datetime.now(timezone.utc).isoformat()

    out_path = output_dir / "bundle-manifest.json"
    out_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return out_path


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUT,
        help=f"Output directory (default {DEFAULT_OUT})",
    )
    parser.add_argument(
        "--remote-manifest",
        type=Path,
        default=None,
        help="Existing bundle-manifest.json to merge (optional)",
    )
    args = parser.parse_args()

    stats = stage_l10n_upload(args.output)
    manifest_path = update_bundle_manifest(
        args.output,
        l10n_version=str(stats["l10nVersion"]),
        config_version=int(stats["configVersion"]),
        remote_manifest_path=args.remote_manifest,
    )

    print(
        f"Staged {stats['l10nFileCount']} l10n files, "
        f"{stats['hgssMapCount']} HGSS maps → {stats['outputDir']}",
        flush=True,
    )
    print(f"bundle-manifest.json → {manifest_path}", flush=True)
    print(f"l10nVersion={stats['l10nVersion']}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
