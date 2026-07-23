#!/usr/bin/env python3
"""Patch the verified v6 bundle into v7 without rebuilding encounter data.

The v6 archive accidentally used an 80x80 pixel sprite for both the default
thumbnail and artwork.  This patcher treats v6 as immutable input, restores
the already-verified 220x220 official-artwork thumbnails from v5, reuses them
for the default detail image, and enriches existing form JSON with
version-specific sprite URLs.

No species, move, ability, or encounter/location records are regenerated.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import tarfile
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

try:
    import zstandard as zstd
except ImportError:  # pragma: no cover
    zstd = None  # type: ignore[assignment]

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_dex_bundle import (  # noqa: E402
    directory_size,
    filter_form_sprite_versions,
    sha256_file,
)
from pokeapi_assets import (  # noqa: E402
    animated_sprite_url,
    build_sprite_url_map,
    official_artwork_url,
)

BUNDLE_VERSION = 7
CDN_PREFIX = "v5"
SPECIES_COUNT = 1025
POKEAPI_BASE = "https://pokeapi.co/api/v2"
USER_AGENT = "TitoDex-v7-incremental-patcher/1.0"

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


def fetch_json_cached(url: str, cache_path: Path) -> dict[str, Any]:
    if cache_path.is_file():
        return json.loads(cache_path.read_text(encoding="utf-8"))
    payload = json.loads(fetch_bytes(url))
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    return payload


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


def restore_legacy_thumbnails(archive: Path, destination: Path) -> int:
    sprites_dir = destination / "sprites"
    sprites_dir.mkdir(parents=True, exist_ok=True)
    restored = 0
    expected = {f"sprites/{pokemon_id}.png" for pokemon_id in range(1, 1026)}
    for name, source in iter_tar_files(archive):
        if name not in expected:
            source.close()
            continue
        target = destination / name
        with source, target.open("wb") as output:
            shutil.copyfileobj(source, output)
        restored += 1
    if restored != SPECIES_COUNT:
        raise ValueError(
            f"Legacy archive restored {restored}/{SPECIES_COUNT} thumbnails"
        )
    return restored


def reuse_clear_thumbnails_as_artwork(staging: Path) -> None:
    """Avoid a second 100+ MB copy of source artwork in the offline archive."""
    artwork_dir = staging / "artwork"
    if artwork_dir.exists():
        shutil.rmtree(artwork_dir)
    artwork_dir.mkdir(parents=True, exist_ok=True)
    for pokemon_id in range(1, 1026):
        source = staging / "sprites" / f"{pokemon_id}.png"
        if not source.is_file():
            raise FileNotFoundError(source)
        shutil.copy2(source, artwork_dir / source.name)


def detail_paths(staging: Path) -> list[Path]:
    return sorted(
        (staging / "details").glob("*.json"),
        key=lambda path: int(path.stem),
    )


def collect_form_resources(staging: Path) -> tuple[set[int], set[int]]:
    pokemon_ids: set[int] = set()
    form_ids: set[int] = set()
    for path in detail_paths(staging):
        detail = json.loads(path.read_text(encoding="utf-8"))
        for form in detail.get("forms") or []:
            pokemon_id = form.get("pokemonId")
            if pokemon_id is not None:
                pokemon_ids.add(int(pokemon_id))
            form_id = form.get("formId")
            if form_id is not None:
                form_ids.add(int(form_id))
    return pokemon_ids, form_ids


def fetch_form_resources(
    pokemon_ids: set[int],
    form_ids: set[int],
    cache_dir: Path,
    workers: int,
) -> tuple[dict[int, dict[str, Any]], dict[int, dict[str, Any]]]:
    jobs = [
        ("pokemon", resource_id)
        for resource_id in sorted(pokemon_ids)
    ] + [
        ("pokemon-form", resource_id)
        for resource_id in sorted(form_ids)
    ]
    total = len(jobs)
    results: dict[str, dict[int, dict[str, Any]]] = {
        "pokemon": {},
        "pokemon-form": {},
    }

    def one(kind: str, resource_id: int):
        payload = fetch_json_cached(
            f"{POKEAPI_BASE}/{kind}/{resource_id}",
            cache_dir / kind / f"{resource_id}.json",
        )
        return kind, resource_id, payload

    completed = 0
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(one, kind, resource_id) for kind, resource_id in jobs]
        for future in as_completed(futures):
            kind, resource_id, payload = future.result()
            results[kind][resource_id] = payload
            completed += 1
            if completed % 25 == 0 or completed == total:
                percent = completed * 100 / total if total else 100
                print(
                    f"  form metadata {completed}/{total} ({percent:.1f}%)",
                    flush=True,
                )
    return results["pokemon"], results["pokemon-form"]


def enrich_form_sprite_metadata(
    staging: Path,
    pokemon_payloads: dict[int, dict[str, Any]],
    form_payloads: dict[int, dict[str, Any]],
) -> int:
    updated = 0
    for path in detail_paths(staging):
        detail = json.loads(path.read_text(encoding="utf-8"))
        changed = False
        for form in detail.get("forms") or []:
            pokemon_id = int(form["pokemonId"])
            pokemon_sprites = (
                pokemon_payloads.get(pokemon_id, {}).get("sprites") or {}
            )
            form_id = form.get("formId")
            form_sprites = (
                form_payloads.get(int(form_id), {}).get("sprites") or {}
                if form_id is not None
                else {}
            )
            sprite_payload = form_sprites or pokemon_sprites
            version_urls = build_sprite_url_map(sprite_payload)
            if not version_urls and form_sprites:
                version_urls = build_sprite_url_map(pokemon_sprites)
            version_urls = filter_form_sprite_versions(
                version_urls,
                introduced_version_group=form.get("introducedVersionGroup"),
                available_version_groups=list(
                    form.get("availableVersionGroups") or []
                ),
            )
            if version_urls:
                form["spriteUrlsByVersion"] = version_urls
            else:
                form.pop("spriteUrlsByVersion", None)

            animated = animated_sprite_url(sprite_payload) or animated_sprite_url(
                pokemon_sprites
            )
            if animated:
                form["animatedSpriteUrl"] = animated
            else:
                form.pop("animatedSpriteUrl", None)

            remote_artwork = official_artwork_url(form_sprites) or official_artwork_url(
                pokemon_sprites
            )
            local_sprite = str(form.get("localSpritePath") or "")
            if remote_artwork and local_sprite.startswith("sprites/forms/"):
                form["artworkUrl"] = remote_artwork
            changed = True
            updated += 1
        if changed:
            path.write_text(
                json.dumps(detail, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
    return updated


def rewrite_prefixes(node: Any, old_prefix: str, new_prefix: str) -> Any:
    if isinstance(node, dict):
        return {
            key: rewrite_prefixes(value, old_prefix, new_prefix)
            for key, value in node.items()
        }
    if isinstance(node, list):
        return [rewrite_prefixes(value, old_prefix, new_prefix) for value in node]
    if isinstance(node, str):
        return node.replace(f"/{old_prefix}/", f"/{new_prefix}/")
    return node


def rewrite_json_tree(staging: Path, old_prefix: str, new_prefix: str) -> None:
    for path in staging.rglob("*.json"):
        payload = json.loads(path.read_text(encoding="utf-8"))
        rewritten = rewrite_prefixes(payload, old_prefix, new_prefix)
        path.write_text(
            json.dumps(rewritten, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


def create_archive(staging: Path, archive_path: Path) -> None:
    archive_path.unlink(missing_ok=True)
    if zstd is None:
        import subprocess

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
        return

    compressor = zstd.ZstdCompressor(level=10, threads=-1)
    with archive_path.open("wb") as raw:
        with compressor.stream_writer(raw, closefd=False) as compressed:
            with tarfile.open(fileobj=compressed, mode="w|") as tar:
                for path in sorted(staging.rglob("*")):
                    if path == archive_path or not path.is_file():
                        continue
                    tar.add(path, arcname=path.relative_to(staging), recursive=False)


def write_manifests(staging: Path, upload_root: Path, cdn_base: str) -> None:
    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    archive_path = staging / "bundle.tar.zst"
    archive_path.unlink(missing_ok=True)
    manifest_path = staging / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["version"] = BUNDLE_VERSION
    manifest["downloadedAt"] = published_at
    schema = dict(manifest.get("schemaFeatures") or {})
    schema["pokemonForms"] = max(3, int(schema.get("pokemonForms") or 0))
    manifest["schemaFeatures"] = schema
    manifest["sizeBytes"] = directory_size(staging)
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("Creating v7 archive…", flush=True)
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
        "schemaFeatures": manifest["schemaFeatures"],
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


def build(args: argparse.Namespace) -> None:
    output = args.output.resolve()
    staging = output / "staging"
    cache_dir = output / "cache"
    upload_root = output / "upload"
    if staging.exists():
        shutil.rmtree(staging)
    if upload_root.exists():
        shutil.rmtree(upload_root)

    print("Extracting verified v6 encounter/detail seed…", flush=True)
    extract_bundle(args.base_bundle.resolve(), staging)
    base_manifest = json.loads((staging / "manifest.json").read_text())
    if (
        base_manifest.get("version") != 6
        or base_manifest.get("pokemonCount") != SPECIES_COUNT
        or not base_manifest.get("complete")
    ):
        raise ValueError(f"Unexpected v6 seed manifest: {base_manifest}")

    print("Restoring 1025 verified clear v5 thumbnails…", flush=True)
    restore_legacy_thumbnails(args.legacy_media_bundle.resolve(), staging)

    print("Reusing clear thumbnails for default detail artwork…", flush=True)
    reuse_clear_thumbnails_as_artwork(staging)

    pokemon_ids, form_ids = collect_form_resources(staging)
    print(
        f"Fetching cached form sprite metadata: "
        f"{len(pokemon_ids)} Pokémon + {len(form_ids)} forms…",
        flush=True,
    )
    pokemon_payloads, form_payloads = fetch_form_resources(
        pokemon_ids,
        form_ids,
        cache_dir,
        args.workers,
    )
    updated = enrich_form_sprite_metadata(
        staging,
        pokemon_payloads,
        form_payloads,
    )
    print(f"Enriched {updated} form records.", flush=True)

    rewrite_json_tree(staging, old_prefix="v4", new_prefix=CDN_PREFIX)
    upload_root.mkdir(parents=True, exist_ok=True)
    write_manifests(staging, upload_root, args.cdn_base)
    print(f"Done: {upload_root}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Patch TitoDex v6 into v7 without rebuilding encounters"
    )
    parser.add_argument("--base-bundle", type=Path, required=True)
    parser.add_argument("--legacy-media-bundle", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("dist/dex-v7"))
    parser.add_argument("--cdn-base", default="https://dex.tito.cafe")
    parser.add_argument("--workers", type=int, default=12)
    args = parser.parse_args()
    if args.workers < 1 or args.workers > 32:
        parser.error("--workers must be within 1..32")
    build(args)


if __name__ == "__main__":
    main()
