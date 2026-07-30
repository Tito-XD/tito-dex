#!/usr/bin/env python3
"""Patch the live TitoDex v11 bundle into v12: species search axes.

v11 shipped without the reference fields PokeAPI already returns in the species
payload, so the dex could not filter by body style, colour, relative size,
generation, or legendary/mythical status, and search could not see the Pokedex
genus at all.  v12:
  1. takes the *published* v11 bundle.tar.zst as the read-only base — sprites,
     artwork, encounters, moves, abilities and items stay byte-identical,
  2. adds genusZh / generation / shapeSlug / colorSlug / tags / heightDm to every
     summary (in summaries.json, dex_catalog.json and the copy embedded in each
     details/<id>.json — search reads summaries, never detail files),
  3. adds growthRateSlug / habitatSlug / hasGenderDifferences / heldItems /
     baseExperience to each detail,
  4. adds the structured `triggers` array to evolution nodes so trade evolutions
     are decidable without parsing the `triggerZh` display string,
  5. gives every non-cosmetic form its own `evolutionChain`, so 洗翠卡蒂狗 shows
     洗翠风速狗 instead of an empty card (tools/form_evolution_chains.py),
  6. bumps the manifest to 12 and lays out an upload tree.

Labels are deliberately absent: only slugs ship.  CDN objects are immutable per
prefix, so a Chinese label baked in here could not be corrected without a
republish; they live in flutter/lib/features/dex/dex_search_terms.dart instead.

Uploading is intentionally NOT part of this script.  Build the tree, verify it,
then release with the canonical two-phase uploader:

    python3 tools/patch_dex_bundle_v12_species_axes.py
    python3 tools/verify_dex_upload_tree.py dist/dex-v12/upload
    python3 tools/upload_dex_bundle_r2.py dist/dex-v12/upload \\
        --cdn-prefix v5 --phase objects
    python3 tools/upload_dex_bundle_r2.py dist/dex-v12/upload \\
        --cdn-prefix v5 --phase manifest

The root bundle-manifest.json must go last: clients only switch to v12 once
every /v5/ object above it exists.
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
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

# Imported, not copied: species_tags carries the curated pseudo-legendary list
# and evolution_trigger_payload the field mapping.  A second copy here would be
# the same two-sources-of-truth problem the zh labels were moved out to avoid.
from build_dex_bundle import (  # noqa: E402
    evolution_trigger_payload,
    parse_held_items,
    species_generation,
    species_tags,
)
from build_location_index import LocationIndexBuilder  # noqa: E402
from form_evolution_chains import apply_form_evolution_chains  # noqa: E402

BASE_VERSION = 11
BUNDLE_VERSION = 12
CDN_PREFIX = "v5"
CDN_BASE = "https://dex.tito.cafe"
LIVE_ARCHIVE = f"{CDN_BASE}/{CDN_PREFIX}/bundle.tar.zst"
LIVE_ROOT_MANIFEST = f"{CDN_BASE}/bundle-manifest.json"
POKEAPI = "https://pokeapi.co/api/v2"
USER_AGENT = "TitoDex/1.0 (+bundle build)"


def directory_size(path: Path) -> int:
    return sum(f.stat().st_size for f in path.rglob("*") if f.is_file())


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def create_zst_tar(source_dir: Path, archive_path: Path) -> None:
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as tar:
        for file in sorted(source_dir.rglob("*")):
            if not file.is_file() or file.name == "bundle.tar.zst":
                continue
            tar.add(file, arcname=file.relative_to(source_dir).as_posix())
    process = subprocess.run(
        ["zstd", "-19", "--stdout"],
        input=buffer.getvalue(),
        capture_output=True,
        check=True,
    )
    archive_path.write_bytes(process.stdout)


def download(url: str, dest: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=180) as response:
        with open(dest, "wb") as handle:
            shutil.copyfileobj(response, handle)


def extract_archive(archive: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    zstd = subprocess.run(
        ["zstd", "-dc", str(archive)], check=True, stdout=subprocess.PIPE
    )
    subprocess.run(["tar", "-x", "-C", str(dest)], check=True, input=zstd.stdout)


class PokeApiCache:
    """Disk-cached PokeAPI reads so a re-run costs no network."""

    def __init__(self, cache_dir: Path, delay_s: float) -> None:
        self.cache_dir = cache_dir
        self.delay_s = delay_s
        self.hits = 0
        self.misses = 0
        cache_dir.mkdir(parents=True, exist_ok=True)

    def get(self, path: str) -> dict[str, Any]:
        key = path.strip("/").replace("/", "_") + ".json"
        cached = self.cache_dir / key
        if cached.exists():
            self.hits += 1
            return json.loads(cached.read_text(encoding="utf-8"))
        url = path if path.startswith("http") else f"{POKEAPI}/{path.strip('/')}/"
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.loads(response.read().decode("utf-8"))
        cached.write_text(
            json.dumps(payload, ensure_ascii=False), encoding="utf-8"
        )
        self.misses += 1
        if self.delay_s:
            time.sleep(self.delay_s)
        return payload


def summary_additions(
    species: dict[str, Any],
    pokemon: dict[str, Any],
    detail: dict[str, Any],
) -> dict[str, Any]:
    """The searchable fields, which must live on the summary, not the detail."""
    additions: dict[str, Any] = {}
    # genusZh is already in the bundle — it just sat where search cannot reach.
    genus = detail.get("genusZh")
    if genus:
        additions["genusZh"] = genus
    generation = species_generation(species)
    if generation is not None:
        additions["generation"] = generation
    shape = (species.get("shape") or {}).get("name")
    if shape:
        additions["shapeSlug"] = shape
    color = (species.get("color") or {}).get("name")
    if color:
        additions["colorSlug"] = color
    tags = species_tags(species, int(detail["summary"]["id"]))
    if tags:
        additions["tags"] = tags
    height = pokemon.get("height") or detail.get("heightDm")
    if height:
        additions["heightDm"] = height
    return additions


def detail_additions(
    species: dict[str, Any], pokemon: dict[str, Any]
) -> dict[str, Any]:
    additions: dict[str, Any] = {}
    growth_rate = (species.get("growth_rate") or {}).get("name")
    if growth_rate:
        additions["growthRateSlug"] = growth_rate
    # Habitat only exists for Gen I-III species; null everywhere else.
    habitat = (species.get("habitat") or {}).get("name")
    if habitat:
        additions["habitatSlug"] = habitat
    if species.get("has_gender_differences"):
        additions["hasGenderDifferences"] = True
    held_items = parse_held_items(pokemon.get("held_items", []))
    if held_items:
        additions["heldItems"] = held_items
    base_experience = pokemon.get("base_experience")
    if base_experience is not None:
        additions["baseExperience"] = base_experience
    return additions


def triggers_by_species(chain_node: dict[str, Any]) -> dict[int, list[dict]]:
    """Flatten a PokeAPI evolution chain into species id → structured triggers."""
    result: dict[int, list[dict]] = {}

    def walk(node: dict[str, Any]) -> None:
        species_url = node["species"]["url"].rstrip("/")
        species_id = int(species_url.rsplit("/", 1)[-1])
        payloads = [
            payload
            for payload in (
                evolution_trigger_payload(detail)
                for detail in node.get("evolution_details") or []
            )
            if payload
        ]
        if payloads:
            result[species_id] = payloads
        for child in node.get("evolves_to", []):
            walk(child)

    walk(chain_node)
    return result


def apply_triggers(node: dict[str, Any], lookup: dict[int, list[dict]]) -> int:
    """Attach `triggers` in place; returns how many nodes were annotated."""
    count = 0
    payloads = lookup.get(int(node.get("id", -1)))
    if payloads:
        node["triggers"] = payloads
        count += 1
    for child in node.get("children", []) or []:
        count += apply_triggers(child, lookup)
    return count


def build(args: argparse.Namespace) -> None:
    output = args.output.resolve()
    staging = output / "staging"
    upload_root = output / "upload"
    for path in (staging, upload_root):
        if path.exists():
            shutil.rmtree(path)
    output.mkdir(parents=True, exist_ok=True)

    # 1. Authoritative base: the published v11 archive.
    if args.base_archive:
        base_archive = args.base_archive.resolve()
        print(f"Using local base archive {base_archive} ...", flush=True)
    else:
        base_archive = output / f"base-v{BASE_VERSION}.tar.zst"
        print(f"Downloading live base archive → {base_archive} ...", flush=True)
        download(LIVE_ARCHIVE, base_archive)
    print(f"Extracting base archive → {staging} ...", flush=True)
    extract_archive(base_archive, staging)
    (staging / "bundle.tar.zst").unlink(missing_ok=True)

    base_manifest = json.loads(
        (staging / "manifest.json").read_text(encoding="utf-8")
    )
    if base_manifest.get("version") != BASE_VERSION or not base_manifest.get(
        "complete"
    ):
        raise ValueError(
            f"Unexpected base manifest (want v{BASE_VERSION} complete): "
            f"version={base_manifest.get('version')} "
            f"complete={base_manifest.get('complete')}"
        )

    cache = PokeApiCache(args.cache, args.delay)
    details_dir = staging / "details"
    detail_paths = sorted(
        details_dir.glob("*.json"), key=lambda p: int(p.stem)
    )
    if args.limit:
        detail_paths = detail_paths[: args.limit]
    print(f"Augmenting {len(detail_paths)} species ...", flush=True)

    additions_by_id: dict[int, dict[str, Any]] = {}
    chain_cache: dict[str, dict[int, list[dict]]] = {}
    location_index = LocationIndexBuilder()
    stats = {
        "shape": 0, "color": 0, "generation": 0, "tags": 0, "genus": 0,
        "habitat": 0, "growth": 0, "held": 0, "genderDiff": 0, "triggers": 0,
    }

    for index, path in enumerate(detail_paths, start=1):
        species_id = int(path.stem)
        detail = json.loads(path.read_text(encoding="utf-8"))
        species = cache.get(f"pokemon-species/{species_id}")
        pokemon = cache.get(f"pokemon/{species_id}")

        adds = summary_additions(species, pokemon, detail)
        additions_by_id[species_id] = adds
        detail["summary"].update(adds)
        detail.update(detail_additions(species, pokemon))

        stats["shape"] += "shapeSlug" in adds
        stats["color"] += "colorSlug" in adds
        stats["generation"] += "generation" in adds
        stats["tags"] += "tags" in adds
        stats["genus"] += "genusZh" in adds
        stats["habitat"] += "habitatSlug" in detail
        stats["growth"] += "growthRateSlug" in detail
        stats["held"] += "heldItems" in detail
        stats["genderDiff"] += "hasGenderDifferences" in detail

        # Encounter data is read-only here; the inversion sees the same bytes
        # the base bundle shipped.
        location_index.add_detail(species_id, detail)

        chain_url = (species.get("evolution_chain") or {}).get("url")
        if chain_url and detail.get("evolutionChain"):
            if chain_url not in chain_cache:
                chain_cache[chain_url] = triggers_by_species(
                    cache.get(chain_url)["chain"]
                )
            stats["triggers"] += apply_triggers(
                detail["evolutionChain"], chain_cache[chain_url]
            )

        path.write_text(
            json.dumps(detail, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
        if index % 100 == 0 or index == len(detail_paths):
            print(
                f"  {index}/{len(detail_paths)} "
                f"(cache {cache.hits} hit / {cache.misses} miss)",
                flush=True,
            )

    # 1b. Per-form evolution chains.  Runs after the loop because a form's
    # chain is assembled from the *target* species' form entries — 洗翠卡蒂狗
    # needs 风速狗's Hisuian sprite, which lives in details/59.json.
    form_chains, form_chain_problems = apply_form_evolution_chains(
        details_dir,
        compact=True,
        species_ids=[int(path.stem) for path in detail_paths]
        if args.limit
        else None,
    )
    for problem in form_chain_problems:
        print(f"  warn: {problem}", file=sys.stderr)
    if form_chain_problems:
        raise ValueError(
            f"{len(form_chain_problems)} form evolution chains could not be "
            "resolved; fix tools/form_evolution_chains.py before publishing"
        )
    print(f"Wrote {form_chains} per-form evolution chains.", flush=True)

    # 2. The two other places the same summaries are stored.
    for filename, mutate in (
        ("summaries.json", None),
        ("dex_catalog.json", "summaries"),
    ):
        target = staging / filename
        payload = json.loads(target.read_text(encoding="utf-8"))
        entries = payload if mutate is None else payload[mutate]
        patched = 0
        for entry in entries:
            adds = additions_by_id.get(int(entry["id"]))
            if adds:
                entry.update(adds)
                patched += 1
        target.write_text(
            json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
        print(f"Patched {patched} summaries in {filename}.", flush=True)

    # 2b. Reverse location index — game version → area → entries — at the
    # bundle root beside egg_groups.json / items.json.  Deliberately NOT part
    # of dex_catalog.json: that file is decoded on every cold start, this one
    # only when a location page asks for it.
    (staging / "location_index.json").write_text(
        json.dumps(
            location_index.build(), ensure_ascii=False, separators=(",", ":")
        ),
        encoding="utf-8",
    )
    print(
        f"Wrote location_index.json: {location_index.entry_count} entries "
        f"across {location_index.version_count} versions.",
        flush=True,
    )

    # 3. Manifest bump (single bump for axes + index).
    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    base_manifest.update(
        {
            "version": BUNDLE_VERSION,
            "downloadedAt": published_at,
            "speciesWithShape": stats["shape"],
            "speciesWithColor": stats["color"],
            "speciesWithTags": stats["tags"],
            "evolutionNodesWithTriggers": stats["triggers"],
            "locationIndexVersions": location_index.version_count,
            "locationIndexEntries": location_index.entry_count,
        }
    )
    base_manifest["sizeBytes"] = directory_size(staging)
    (staging / "manifest.json").write_text(
        json.dumps(base_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    versioned = upload_root / CDN_PREFIX
    upload_root.mkdir(parents=True, exist_ok=True)
    if args.skip_archive:
        # Smoke-test path: repacking the full tree at zstd -19 dominates the
        # runtime and proves nothing about the JSON transform.
        print("--skip-archive: not repacking; upload tree is INCOMPLETE.", flush=True)
        shutil.copytree(staging, versioned)
        archive_sha = "(skipped)"
    else:
        print("Creating v12 archive ...", flush=True)
        create_zst_tar(staging, staging / "bundle.tar.zst")
        shutil.copytree(staging, versioned)
        archive_sha = sha256_file(versioned / "bundle.tar.zst")
    if args.base_root_manifest:
        root_manifest = json.loads(
            args.base_root_manifest.read_text(encoding="utf-8")
        )
    else:
        print("Downloading live root manifest to preserve its fields ...", flush=True)
        root_manifest_path = output / "root-manifest-base.json"
        download(LIVE_ROOT_MANIFEST, root_manifest_path)
        root_manifest = json.loads(
            root_manifest_path.read_text(encoding="utf-8")
        )
    root_manifest.update(
        {
            "bundleVersion": BUNDLE_VERSION,
            "archiveSha256": archive_sha,
            "archiveSizeBytes": (versioned / "bundle.tar.zst").stat().st_size
            if not args.skip_archive
            else 0,
            "publishedAt": published_at,
        }
    )
    (upload_root / "bundle-manifest.json").write_text(
        json.dumps(root_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("\n--- v12 summary ---", flush=True)
    for label, key in (
        ("body style", "shape"),
        ("colour", "color"),
        ("generation", "generation"),
        ("genus", "genus"),
        ("tags", "tags"),
        ("growth rate", "growth"),
        ("habitat (Gen I-III only)", "habitat"),
        ("held items", "held"),
        ("gender differences", "genderDiff"),
        ("evolution nodes w/ triggers", "triggers"),
    ):
        print(f"  {label:<28} {stats[key]}", flush=True)
    print(
        f"  location index               "
        f"{location_index.entry_count} entries / "
        f"{location_index.version_count} versions",
        flush=True,
    )
    print(f"  archive sha256               {archive_sha}", flush=True)
    print(
        f"  archive bytes                "
        f"{root_manifest['archiveSizeBytes']:,}",
        flush=True,
    )
    print(
        "\nBuilt locally; R2 untouched. Release with:\n"
        f"  python3 tools/verify_dex_upload_tree.py {upload_root}\n"
        f"  python3 tools/upload_dex_bundle_r2.py {upload_root} "
        f"--cdn-prefix {CDN_PREFIX} --phase objects\n"
        f"  python3 tools/upload_dex_bundle_r2.py {upload_root} "
        f"--cdn-prefix {CDN_PREFIX} --phase manifest",
        flush=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Patch TitoDex v11 → v12 (species search axes)"
    )
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "dex-v12")
    parser.add_argument(
        "--cache",
        type=Path,
        default=ROOT / "dist" / "dex-v12-pokeapi-cache",
        help="Disk cache for PokeAPI reads so re-runs cost no network",
    )
    parser.add_argument(
        "--base-archive",
        type=Path,
        help="Local v11 bundle.tar.zst instead of downloading the live one",
    )
    parser.add_argument(
        "--base-root-manifest",
        type=Path,
        help="Local root bundle-manifest.json instead of downloading it",
    )
    parser.add_argument("--delay", type=float, default=0.2)
    parser.add_argument(
        "--limit", type=int, help="Only process the first N species (smoke test)"
    )
    parser.add_argument(
        "--skip-archive",
        action="store_true",
        help="Skip the zstd repack (smoke test only — leaves the tree unusable)",
    )
    args = parser.parse_args()
    build(args)


if __name__ == "__main__":
    main()
