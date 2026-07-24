#!/usr/bin/env python3
"""Incrementally patch TitoDex v7 bundle into v8 with form artwork on CDN.

This script downloads the current v7 bundle, fetches/creates 220x220 artwork for
every form that has a local sprite, uploads them to R2 under v5/artwork/forms/,
rewrites detail JSON to point artworkUrl at the CDN, and republishes the bundle
archive + root manifest as bundleVersion 8.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import shutil
import subprocess
import sys
import tarfile
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import requests

try:
    import zstandard as zstd
except ImportError:  # pragma: no cover
    zstd = None  # type: ignore[assignment]

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_dex_bundle import (  # noqa: E402
    directory_size,
    optimize_png,
    sha256_file,
)
from pokeapi_assets import official_artwork_url  # noqa: E402

BUNDLE_VERSION = 8
CDN_PREFIX = "v5"
POKEAPI_BASE = "https://pokeapi.co/api/v2"
USER_AGENT = "TitoDex-v8-form-artwork-patcher/1.0"
CDN_BASE = "https://dex.tito.cafe"

_thread_local = threading.local()


def session() -> requests.Session:
    value = getattr(_thread_local, "session", None)
    if value is None:
        value = requests.Session()
        value.headers["User-Agent"] = USER_AGENT
        _thread_local.session = value
    return value


def fetch_bytes(url: str, *, attempts: int = 5) -> bytes:
    last_error: Exception | None = None
    for attempt in range(attempts):
        try:
            response = session().get(url, timeout=90)
            response.raise_for_status()
            return response.content
        except requests.RequestException as exc:
            last_error = exc
            if attempt + 1 == attempts:
                break
    raise RuntimeError(f"Failed to download {url}: {last_error}")


def iter_tar_files(archive: Path):
    if zstd is not None:
        source = archive.open("rb")
        reader = zstd.ZstdDecompressor().stream_reader(source)
        tar = tarfile.open(fileobj=reader, mode="r|")
        try:
            for member in tar:
                if member.isfile():
                    source_file = tar.extractfile(member)
                    if source_file is None:
                        raise RuntimeError(
                            f"Could not read archive member: {member.name}"
                        )
                    yield member.name, source_file
        finally:
            tar.close()
            reader.close()
            source.close()
        return

    import subprocess

    process = subprocess.Popen(
        ["unzstd", "-c", str(archive)],
        stdout=subprocess.PIPE,
    )
    if process.stdout is None:
        raise RuntimeError("unzstd did not expose stdout")
    tar = tarfile.open(fileobj=process.stdout, mode="r|")
    try:
        for member in tar:
            if member.isfile():
                source_file = tar.extractfile(member)
                if source_file is None:
                    raise RuntimeError(
                        f"Could not read archive member: {member.name}"
                    )
                yield member.name, source_file
    finally:
        tar.close()
        process.stdout.close()
        if process.wait() != 0:
            raise RuntimeError(f"unzstd failed for {archive}")


def extract_bundle(archive: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for name, source in iter_tar_files(archive):
        relative = Path(name)
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"Unsafe archive member: {name}")
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        with source, target.open("wb") as output:
            shutil.copyfileobj(source, output)


def download_bundle(manifest_url: str, output: Path) -> tuple[Path, Path]:
    output.mkdir(parents=True, exist_ok=True)
    manifest_path = output / "bundle-manifest.json"
    if not manifest_path.is_file():
        print(f"Downloading manifest {manifest_url}...", flush=True)
        manifest_path.write_bytes(fetch_bytes(manifest_url))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("bundleVersion") != 7:
        raise ValueError(f"Expected v7 manifest, got {manifest.get('bundleVersion')}")
    archive_url = manifest["archiveUrl"]
    archive_path = output / "bundle.tar.zst"
    if not archive_path.is_file():
        print(f"Downloading bundle {archive_url}...", flush=True)
        archive_path.write_bytes(fetch_bytes(archive_url))
    return archive_path, manifest_path


def collect_forms(staging: Path) -> list[tuple[int, dict[str, Any]]]:
    """Return (detail_id, form_json) for every form with a local sprite."""
    results: list[tuple[int, dict[str, Any]]] = []
    details_dir = staging / "details"
    for path in sorted(details_dir.glob("*.json")):
        detail_id = int(path.stem)
        detail = json.loads(path.read_text(encoding="utf-8"))
        for form in detail.get("forms") or []:
            local = str(form.get("localSpritePath") or "")
            if local.startswith("sprites/forms/"):
                results.append((detail_id, form))
    return results


def download_image(url: str) -> bytes | None:
    try:
        return fetch_bytes(url)
    except RuntimeError as exc:
        print(f"  warn download failed: {exc}", flush=True)
        return None


def optimize_or_pass(png_bytes: bytes) -> bytes:
    try:
        return optimize_png(png_bytes, max_width=220)
    except Exception as exc:
        print(f"  warn optimize failed: {exc}", flush=True)
        return png_bytes


def r2_put(local_path: Path, key: str, content_type: str) -> None:
    subprocess.run(
        [
            "npx",
            "wrangler",
            "r2",
            "object",
            "put",
            f"titodex-dex/{key}",
            f"--file={local_path}",
            "--remote",
            f"--content-type={content_type}",
        ],
        check=True,
        cwd=ROOT / "cloudflare" / "dex-cdn",
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def fetch_pokemon_sprites(pokemon_id: int, cache_dir: Path) -> dict[str, Any]:
    cache_path = cache_dir / "pokemon" / f"{pokemon_id}.json"
    if cache_path.is_file():
        return json.loads(cache_path.read_text(encoding="utf-8")).get("sprites") or {}
    url = f"{POKEAPI_BASE}/pokemon/{pokemon_id}"
    data = json.loads(fetch_bytes(url))
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return data.get("sprites") or {}


def fetch_form_sprites(form_id: int, cache_dir: Path) -> dict[str, Any]:
    cache_path = cache_dir / "pokemon-form" / f"{form_id}.json"
    if cache_path.is_file():
        return json.loads(cache_path.read_text(encoding="utf-8")).get("sprites") or {}
    url = f"{POKEAPI_BASE}/pokemon-form/{form_id}"
    data = json.loads(fetch_bytes(url))
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return data.get("sprites") or {}


def process_forms(
    staging: Path,
    cache_dir: Path,
    workers: int,
) -> dict[int, str]:
    """Download/optimize artwork for each form and return form_id -> CDN URL."""
    artwork_dir = staging / "artwork" / "forms"
    artwork_dir.mkdir(parents=True, exist_ok=True)

    forms = collect_forms(staging)
    print(f"Found {len(forms)} forms with local sprites.", flush=True)

    # Prefetch pokemon/form sprites metadata to compute distinct URLs.
    pokemon_ids: set[int] = set()
    form_ids: set[int] = set()
    for _, form in forms:
        pid = form.get("pokemonId")
        if pid is not None:
            pokemon_ids.add(int(pid))
        fid = form.get("formId")
        if fid is not None:
            form_ids.add(int(fid))

    print(
        f"Fetching sprites metadata for {len(pokemon_ids)} Pokémon and "
        f"{len(form_ids)} forms...",
        flush=True,
    )
    pokemon_sprites: dict[int, dict[str, Any]] = {}
    form_sprites: dict[int, dict[str, Any]] = {}

    def fetch_one(kind: str, resource_id: int):
        if kind == "pokemon":
            return kind, resource_id, fetch_pokemon_sprites(resource_id, cache_dir)
        return kind, resource_id, fetch_form_sprites(resource_id, cache_dir)

    jobs = [("pokemon", pid) for pid in sorted(pokemon_ids)] + [
        ("pokemon-form", fid) for fid in sorted(form_ids)
    ]
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(fetch_one, kind, rid) for kind, rid in jobs]
        for completed, future in enumerate(as_completed(futures), start=1):
            kind, resource_id, sprites = future.result()
            if kind == "pokemon":
                pokemon_sprites[resource_id] = sprites
            else:
                form_sprites[resource_id] = sprites
            if completed % 50 == 0 or completed == len(jobs):
                print(f"  metadata {completed}/{len(jobs)}", flush=True)

    # Determine CDN URL for each form.
    form_cdn_urls: dict[int, str] = {}
    for _, form in forms:
        fid = form.get("formId")
        if fid is None:
            continue
        fid = int(fid)
        pid = form.get("pokemonId")
        pid = int(pid) if pid is not None else None

        remote = official_artwork_url(form_sprites.get(fid, {})) or (
            official_artwork_url(pokemon_sprites.get(pid, {})) if pid is not None else None
        )
        if not remote:
            print(f"  warn no artwork for form {fid}", flush=True)
            continue
        form_cdn_urls[fid] = f"{CDN_BASE}/{CDN_PREFIX}/artwork/forms/{fid}.png"

    print(f"{len(form_cdn_urls)} forms will have CDN artwork.", flush=True)

    # Download distinct remote URLs once, then copy to per-form files.
    unique_urls: dict[str, set[int]] = {}
    for fid, url in form_cdn_urls.items():
        # url is the CDN URL; we need the source remote URL for downloading.
        # Recompute remote for each form below.
        pass

    # Build remote URL -> form ids mapping.
    remote_to_forms: dict[str, set[int]] = {}
    remote_for_fid: dict[int, str] = {}
    for _, form in forms:
        fid = form.get("formId")
        if fid is None:
            continue
        fid = int(fid)
        if fid not in form_cdn_urls:
            continue
        pid = form.get("pokemonId")
        pid = int(pid) if pid is not None else None
        remote = official_artwork_url(form_sprites.get(fid, {})) or (
            official_artwork_url(pokemon_sprites.get(pid, {})) if pid is not None else None
        )
        if not remote:
            continue
        remote_for_fid[fid] = remote
        remote_to_forms.setdefault(remote, set()).add(fid)

    print(
        f"Downloading {len(remote_to_forms)} distinct artwork sources...",
        flush=True,
    )
    remote_bytes: dict[str, bytes] = {}
    remote_failed: set[str] = set()

    def download_one(remote_url: str) -> tuple[str, bytes | None]:
        return remote_url, download_image(remote_url)

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(download_one, url) for url in remote_to_forms]
        for completed, future in enumerate(as_completed(futures), start=1):
            url, data = future.result()
            if data is None:
                remote_failed.add(url)
            else:
                remote_bytes[url] = data
            if completed % 50 == 0 or completed == len(remote_to_forms):
                print(f"  download {completed}/{len(remote_to_forms)}", flush=True)

    # Optimize and write per-form files.
    print("Optimizing and writing per-form artwork files...", flush=True)
    for remote_url, fids in remote_to_forms.items():
        if remote_url in remote_failed:
            for fid in fids:
                form_cdn_urls.pop(fid, None)
            continue
        data = optimize_or_pass(remote_bytes[remote_url])
        for fid in fids:
            path = artwork_dir / f"{fid}.png"
            path.write_bytes(data)

    return form_cdn_urls


def rewrite_form_artwork_urls(staging: Path, form_cdn_urls: dict[int, str]) -> int:
    updated = 0
    for path in sorted((staging / "details").glob("*.json")):
        detail = json.loads(path.read_text(encoding="utf-8"))
        changed = False
        for form in detail.get("forms") or []:
            fid = form.get("formId")
            if fid is None:
                continue
            fid = int(fid)
            cdn_url = form_cdn_urls.get(fid)
            if cdn_url:
                form["artworkUrl"] = cdn_url
                changed = True
                updated += 1
            elif "artworkUrl" in form:
                # Remove stale remote artwork URL if we couldn't download it.
                form.pop("artworkUrl", None)
                changed = True
        if changed:
            path.write_text(
                json.dumps(detail, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
    return updated


def upload_artwork_files(staging: Path, form_cdn_urls: dict[int, str], workers: int) -> None:
    artwork_dir = staging / "artwork" / "forms"
    paths_and_keys = [
        (artwork_dir / f"{fid}.png", f"{CDN_PREFIX}/artwork/forms/{fid}.png")
        for fid in form_cdn_urls
        if (artwork_dir / f"{fid}.png").is_file()
    ]
    print(f"Uploading {len(paths_and_keys)} artwork files to R2...", flush=True)

    def upload_one(item: tuple[Path, str]) -> None:
        local_path, key = item
        r2_put(local_path, key, "image/png")

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(upload_one, item) for item in paths_and_keys]
        for completed, future in enumerate(as_completed(futures), start=1):
            future.result()
            if completed % 50 == 0 or completed == len(paths_and_keys):
                print(f"  upload {completed}/{len(paths_and_keys)}", flush=True)


def create_archive(staging: Path, archive_path: Path) -> None:
    archive_path.unlink(missing_ok=True)
    if zstd is not None:
        compressor = zstd.ZstdCompressor(level=10, threads=-1)
        with archive_path.open("wb") as raw:
            with compressor.stream_writer(raw, closefd=False) as compressed:
                with tarfile.open(fileobj=compressed, mode="w|") as tar:
                    for path in sorted(staging.rglob("*")):
                        if path == archive_path or not path.is_file():
                            continue
                        tar.add(path, arcname=path.relative_to(staging), recursive=False)
        return

    subprocess.run(
        [
            "tar",
            "--use-compress-program=zstd -10 -T0",
            "-cf",
            str(archive_path),
            "-C",
            str(staging),
            ".",
        ],
        check=True,
    )


def write_manifests(staging: Path, upload_root: Path, cdn_base: str) -> None:
    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    archive_path = staging / "bundle.tar.zst"
    archive_path.unlink(missing_ok=True)
    manifest_path = staging / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["version"] = BUNDLE_VERSION
    manifest["downloadedAt"] = published_at
    # schemaFeatures stays the same; only the artworkUrl values change.
    manifest["sizeBytes"] = directory_size(staging)
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("Creating v8 archive...", flush=True)
    create_archive(staging, archive_path)

    versioned = upload_root / CDN_PREFIX
    if versioned.exists():
        shutil.rmtree(versioned)
    shutil.copytree(staging, versioned)

    archive_sha = sha256_file(versioned / "bundle.tar.zst")
    root_manifest = {
        "bundleVersion": BUNDLE_VERSION,
        "pokemonCount": int(manifest["pokemonCount"]),
        "formCount": int(manifest.get("formCount") or 0),
        "formSpriteCount": int(manifest.get("formSpriteCount") or 0),
        "schemaFeatures": manifest.get("schemaFeatures") or {},
        "cdnPrefix": CDN_PREFIX,
        "complete": bool(manifest["complete"]),
        "exactVersionLocations": bool(manifest.get("exactVersionLocations")),
        "encounterSources": manifest.get("encounterSources") or [],
        "encounterCoverage": manifest.get("encounterCoverage") or {},
        "archiveUrl": f"{cdn_base.rstrip('/')}/{CDN_PREFIX}/bundle.tar.zst",
        "archiveSha256": archive_sha,
        "archiveSizeBytes": (versioned / "bundle.tar.zst").stat().st_size,
        "publishedAt": published_at,
        "l10nVersion": manifest.get("l10nVersion"),
        "configVersion": manifest.get("configVersion"),
    }
    (upload_root / "bundle-manifest.json").write_text(
        json.dumps(root_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Archive SHA256: {archive_sha}", flush=True)
    print(
        f"Archive bytes: {root_manifest['archiveSizeBytes']:,}",
        flush=True,
    )


def upload_bundle_and_manifest(upload_root: Path) -> None:
    bundle_path = upload_root / CDN_PREFIX / "bundle.tar.zst"
    manifest_path = upload_root / CDN_PREFIX / "manifest.json"
    root_manifest_path = upload_root / "bundle-manifest.json"

    print("Uploading bundle.tar.zst...", flush=True)
    r2_put(bundle_path, f"{CDN_PREFIX}/bundle.tar.zst", "application/zstd")
    print("Uploading manifest.json...", flush=True)
    r2_put(manifest_path, f"{CDN_PREFIX}/manifest.json", "application/json")
    print("Uploading root bundle-manifest.json...", flush=True)
    r2_put(root_manifest_path, "bundle-manifest.json", "application/json")


def build(args: argparse.Namespace) -> None:
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    staging = output / "staging"
    cache_dir = output / "cache"
    upload_root = output / "upload"

    if staging.exists():
        shutil.rmtree(staging)
    if upload_root.exists():
        shutil.rmtree(upload_root)

    archive_path, _ = download_bundle(args.manifest_url, output)
    print("Extracting v7 bundle...", flush=True)
    extract_bundle(archive_path, staging)

    base_manifest = json.loads((staging / "manifest.json").read_text(encoding="utf-8"))
    if (
        base_manifest.get("version") != 7
        or base_manifest.get("pokemonCount") != 1025
        or not base_manifest.get("complete")
    ):
        raise ValueError(f"Unexpected v7 seed manifest: {base_manifest}")

    form_cdn_urls = process_forms(staging, cache_dir, args.workers)
    upload_artwork_files(staging, form_cdn_urls, args.workers)

    updated = rewrite_form_artwork_urls(staging, form_cdn_urls)
    print(f"Rewrote {updated} form artwork URLs.", flush=True)

    upload_root.mkdir(parents=True, exist_ok=True)
    write_manifests(staging, upload_root, args.cdn_base)
    upload_bundle_and_manifest(upload_root)
    print(f"Done: {upload_root}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Patch TitoDex v7 into v8 with form artwork on CDN"
    )
    parser.add_argument(
        "--manifest-url",
        default=f"{CDN_BASE}/bundle-manifest.json",
    )
    parser.add_argument("--output", type=Path, default=Path("dist/dex-v8"))
    parser.add_argument("--cdn-base", default=CDN_BASE)
    parser.add_argument("--workers", type=int, default=8)
    args = parser.parse_args()
    if args.workers < 1 or args.workers > 16:
        parser.error("--workers must be within 1..16")
    build(args)


if __name__ == "__main__":
    main()
