#!/usr/bin/env python3
"""Generate the exact per-version sprite existence matrix.

The PokeAPI Pokemon payload exposes many version-group URL slots even when the
corresponding file is absent.  This generator reads the official
``PokeAPI/sprites`` Git tree instead, pins the result to one commit, and emits:

* ``data/dex/sprite_version_existence.json`` for bundle/build tools.
* ``flutter/lib/features/dex/sprite_version_existence.g.dart`` for the app.

Only an integer-named file at the exact front/back/animated path counts.  No
same-generation or default-artwork fallback is recorded as a per-game sprite.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import time
from pathlib import Path
from typing import Any, Iterable

import requests


ROOT = Path(__file__).resolve().parents[1]
GITHUB_API = "https://api.github.com"
SOURCE_REPOSITORY = "PokeAPI/sprites"

# Version groups that have an actual front-sprite directory in PokeAPI/sprites.
# Unsupported API slots (Sun/Moon, LGPE, SwSh, LA, etc.) are intentionally not
# present: treating those slots as real is what caused the viewer to show the
# same default image for multiple generations.
VERSION_GROUP_PATHS: dict[str, str] = {
    "red-blue": "generation-i/red-blue",
    "yellow": "generation-i/yellow",
    "gold-silver": "generation-ii/gold",
    "crystal": "generation-ii/crystal",
    "ruby-sapphire": "generation-iii/ruby-sapphire",
    "emerald": "generation-iii/emerald",
    "firered-leafgreen": "generation-iii/firered-leafgreen",
    "diamond-pearl": "generation-iv/diamond-pearl",
    "platinum": "generation-iv/platinum",
    "heartgold-soulsilver": "generation-iv/heartgold-soulsilver",
    "black-white": "generation-v/black-white",
    "x-y": "generation-vi/x-y",
    "omega-ruby-alpha-sapphire": "generation-vi/omegaruby-alphasapphire",
    "ultra-sun-ultra-moon": "generation-vii/ultra-sun-ultra-moon",
    "brilliant-diamond-shining-pearl": (
        "generation-viii/brilliant-diamond-shining-pearl"
    ),
    "scarlet-violet": "generation-ix/scarlet-violet",
}

_FRONT_RE = re.compile(r"^(\d+)\.png$")
_BACK_RE = re.compile(r"^back/(\d+)\.png$")
_ANIMATED_FRONT_RE = re.compile(r"^animated/(\d+)\.gif$")
_ANIMATED_BACK_RE = re.compile(r"^animated/back/(\d+)\.gif$")
_SHINY_FRONT_RE = re.compile(r"^shiny/(\d+)\.png$")
_SHINY_BACK_RE = re.compile(r"^back/shiny/(\d+)\.png$")
_ANIMATED_SHINY_FRONT_RE = re.compile(r"^animated/shiny/(\d+)\.gif$")
_ANIMATED_SHINY_BACK_RE = re.compile(
    r"^animated/back/shiny/(\d+)\.gif$"
)
_NAMED_ASSET_RE = re.compile(r"^(?:back/|shiny/|animated/)*(\d+-[^/]+)\.(?:png|gif)$")


def _github_json(path: str, *, token: str | None = None) -> Any:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "TitoDex-sprite-matrix/1.0",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    last_error: requests.RequestException | None = None
    for attempt in range(1, 6):
        try:
            response = requests.get(
                f"{GITHUB_API}{path}", headers=headers, timeout=(20, 120)
            )
            response.raise_for_status()
            return response.json()
        except requests.RequestException as exc:
            last_error = exc
            if attempt == 5:
                break
            time.sleep(attempt * 1.5)
    raise RuntimeError(f"GitHub API failed after 5 attempts: {path}") from last_error


def compress_ranges(values: Iterable[int]) -> list[list[int]]:
    """Compress sorted integer ids to inclusive ``[start, end]`` ranges."""
    ids = sorted(set(values))
    if not ids:
        return []
    ranges: list[list[int]] = []
    start = previous = ids[0]
    for value in ids[1:]:
        if value == previous + 1:
            previous = value
            continue
        ranges.append([start, previous])
        start = previous = value
    ranges.append([start, previous])
    return ranges


def extract_ids(
    tree_entries: Iterable[dict[str, Any]],
    *,
    folder_within_generation: str,
) -> dict[str, list[int]]:
    """Extract exact asset ids for one game folder from a generation tree."""
    result: dict[str, list[int]] = {
        "front": [],
        "back": [],
        "animatedFront": [],
        "animatedBack": [],
        "shinyFront": [],
        "shinyBack": [],
        "animatedShinyFront": [],
        "animatedShinyBack": [],
    }
    named: dict[str, list[str]] = {key: [] for key in result}
    prefix = f"{folder_within_generation}/"
    matchers = (
        ("front", _FRONT_RE),
        ("back", _BACK_RE),
        ("animatedFront", _ANIMATED_FRONT_RE),
        ("animatedBack", _ANIMATED_BACK_RE),
        ("shinyFront", _SHINY_FRONT_RE),
        ("shinyBack", _SHINY_BACK_RE),
        ("animatedShinyFront", _ANIMATED_SHINY_FRONT_RE),
        ("animatedShinyBack", _ANIMATED_SHINY_BACK_RE),
    )
    for entry in tree_entries:
        if entry.get("type") != "blob":
            continue
        path = str(entry.get("path") or "")
        if not path.startswith(prefix):
            continue
        relative = path[len(prefix) :]
        for key, matcher in matchers:
            match = matcher.fullmatch(relative)
            if match:
                resource_id = int(match.group(1))
                if resource_id > 0:
                    result[key].append(resource_id)
                break
        else:
            if not _NAMED_ASSET_RE.fullmatch(relative):
                continue
            for key, matcher in matchers:
                numeric_pattern = matcher.pattern.replace(r"(\d+)", r"\d+-[^/]+")
                if re.fullmatch(numeric_pattern, relative):
                    named[key].append(relative)
                    break
    result.update({f"named{key[0].upper()}{key[1:]}": value for key, value in named.items()})
    return result


def _tree_child_sha(entries: Iterable[dict[str, Any]], name: str) -> str:
    for entry in entries:
        if entry.get("type") == "tree" and entry.get("path") == name:
            return str(entry["sha"])
    raise RuntimeError(f"Missing Git tree child: {name}")


def _ids_for_pattern(
    entries: Iterable[dict[str, Any]], pattern: re.Pattern[str]
) -> list[int]:
    result: list[int] = []
    for entry in entries:
        if entry.get("type") != "blob":
            continue
        match = pattern.fullmatch(str(entry.get("path") or ""))
        if match:
            resource_id = int(match.group(1))
            if resource_id > 0:
                result.append(resource_id)
    return result


def _media_payload(
    entries: Iterable[dict[str, Any]],
    pattern: re.Pattern[str],
    path: str,
    *,
    source_prefix: str,
) -> dict[str, Any]:
    named_pattern = re.compile(pattern.pattern.replace(r"(\d+)", r"\d+-[^/]+"))
    return {
        "pathTemplate": path,
        "ranges": compress_ranges(_ids_for_pattern(entries, pattern)),
        "namedPaths": sorted(
            f"{source_prefix}/{entry['path']}"
            for entry in entries
            if entry.get("type") == "blob"
            and named_pattern.fullmatch(str(entry.get("path") or ""))
        ),
    }


def build_matrix(*, ref: str = "master", token: str | None = None) -> dict[str, Any]:
    commit = _github_json(
        f"/repos/{SOURCE_REPOSITORY}/commits/{ref}", token=token
    )
    source_commit = commit["sha"]
    versions = _github_json(
        f"/repos/{SOURCE_REPOSITORY}/contents/sprites/pokemon/versions"
        f"?ref={source_commit}",
        token=token,
    )
    generation_shas = {
        item["name"]: item["sha"]
        for item in versions
        if item.get("type") == "dir"
    }

    generation_trees: dict[str, list[dict[str, Any]]] = {}
    for generation in sorted({path.split("/", 1)[0] for path in VERSION_GROUP_PATHS.values()}):
        sha = generation_shas.get(generation)
        if not sha:
            raise RuntimeError(f"Missing source generation directory: {generation}")
        tree = _github_json(
            f"/repos/{SOURCE_REPOSITORY}/git/trees/{sha}?recursive=1",
            token=token,
        )
        if tree.get("truncated"):
            raise RuntimeError(f"GitHub tree was truncated for {generation}")
        generation_trees[generation] = list(tree.get("tree") or [])

    groups: dict[str, Any] = {}
    for version_group, source_path in VERSION_GROUP_PATHS.items():
        generation, folder = source_path.split("/", 1)
        extracted = extract_ids(
            generation_trees[generation],
            folder_within_generation=folder,
        )
        front_ranges = compress_ranges(extracted["front"])
        if not front_ranges:
            raise RuntimeError(
                f"No exact front sprites found for {version_group} at {source_path}"
            )
        groups[version_group] = {
            "sourcePath": source_path,
            "frontRanges": front_ranges,
            "backRanges": compress_ranges(extracted["back"]),
            "animatedFrontRanges": compress_ranges(extracted["animatedFront"]),
            "animatedBackRanges": compress_ranges(extracted["animatedBack"]),
            "shinyFrontRanges": compress_ranges(extracted["shinyFront"]),
            "shinyBackRanges": compress_ranges(extracted["shinyBack"]),
            "animatedShinyFrontRanges": compress_ranges(
                extracted["animatedShinyFront"]
            ),
            "animatedShinyBackRanges": compress_ranges(
                extracted["animatedShinyBack"]
            ),
            **{
                key: [
                    f"sprites/pokemon/versions/{source_path}/{relative}"
                    for relative in extracted[key]
                ]
                for key in (
                    "namedFront",
                    "namedBack",
                    "namedAnimatedFront",
                    "namedAnimatedBack",
                    "namedShinyFront",
                    "namedShinyBack",
                    "namedAnimatedShinyFront",
                    "namedAnimatedShinyBack",
                )
            },
        }

    sprites = _github_json(
        f"/repos/{SOURCE_REPOSITORY}/contents/sprites?ref={source_commit}",
        token=token,
    )
    items_sha = next(
        item["sha"]
        for item in sprites
        if item.get("type") == "dir" and item.get("name") == "items"
    )
    items_tree_payload = _github_json(
        f"/repos/{SOURCE_REPOSITORY}/git/trees/{items_sha}?recursive=1",
        token=token,
    )
    if items_tree_payload.get("truncated"):
        raise RuntimeError("GitHub tree was truncated for sprites/items")
    item_files = sorted(
        str(entry["path"])
        for entry in items_tree_payload.get("tree") or []
        if entry.get("type") == "blob"
        and str(entry.get("path") or "").endswith(".png")
    )
    pokemon_sha = next(
        item["sha"]
        for item in sprites
        if item.get("type") == "dir" and item.get("name") == "pokemon"
    )
    pokemon_tree = _github_json(
        f"/repos/{SOURCE_REPOSITORY}/git/trees/{pokemon_sha}", token=token
    )["tree"]
    shiny_tree = _github_json(
        f"/repos/{SOURCE_REPOSITORY}/git/trees/"
        f"{_tree_child_sha(pokemon_tree, 'shiny')}?recursive=1",
        token=token,
    )["tree"]
    other_tree = _github_json(
        f"/repos/{SOURCE_REPOSITORY}/git/trees/"
        f"{_tree_child_sha(pokemon_tree, 'other')}",
        token=token,
    )["tree"]

    media_trees: dict[str, list[dict[str, Any]]] = {}
    for folder in ("home", "official-artwork", "showdown"):
        payload = _github_json(
            f"/repos/{SOURCE_REPOSITORY}/git/trees/"
            f"{_tree_child_sha(other_tree, folder)}?recursive=1",
            token=token,
        )
        if payload.get("truncated"):
            raise RuntimeError(f"GitHub tree was truncated for other/{folder}")
        media_trees[folder] = list(payload.get("tree") or [])

    direct_png = re.compile(r"^(\d+)\.png$")
    shiny_png = re.compile(r"^shiny/(\d+)\.png$")
    direct_gif = re.compile(r"^(\d+)\.gif$")
    shiny_gif = re.compile(r"^shiny/(\d+)\.gif$")
    media_assets = {
        "default": _media_payload(
            pokemon_tree,
            direct_png,
            "sprites/pokemon/{id}.png",
            source_prefix="sprites/pokemon",
        ),
        "defaultShiny": _media_payload(
            shiny_tree,
            direct_png,
            "sprites/pokemon/shiny/{id}.png",
            source_prefix="sprites/pokemon/shiny",
        ),
        "home": _media_payload(
            media_trees["home"],
            direct_png,
            "sprites/pokemon/other/home/{id}.png",
            source_prefix="sprites/pokemon/other/home",
        ),
        "homeShiny": _media_payload(
            media_trees["home"],
            shiny_png,
            "sprites/pokemon/other/home/shiny/{id}.png",
            source_prefix="sprites/pokemon/other/home",
        ),
        "officialArtwork": _media_payload(
            media_trees["official-artwork"],
            direct_png,
            "sprites/pokemon/other/official-artwork/{id}.png",
            source_prefix="sprites/pokemon/other/official-artwork",
        ),
        "officialArtworkShiny": _media_payload(
            media_trees["official-artwork"],
            shiny_png,
            "sprites/pokemon/other/official-artwork/shiny/{id}.png",
            source_prefix="sprites/pokemon/other/official-artwork",
        ),
        "showdownAnimated": _media_payload(
            media_trees["showdown"],
            direct_gif,
            "sprites/pokemon/other/showdown/{id}.gif",
            source_prefix="sprites/pokemon/other/showdown",
        ),
        "showdownAnimatedShiny": _media_payload(
            media_trees["showdown"],
            shiny_gif,
            "sprites/pokemon/other/showdown/shiny/{id}.gif",
            source_prefix="sprites/pokemon/other/showdown",
        ),
    }

    return {
        "schemaVersion": 2,
        "sourceRepository": SOURCE_REPOSITORY,
        "sourceCommit": source_commit,
        "itemAssets": {
            "pathPrefix": "sprites/items",
            "files": item_files,
        },
        "mediaAssets": media_assets,
        "versionGroups": groups,
    }


def _dart_ranges(name: str, matrix: dict[str, Any], json_key: str) -> str:
    lines = [f"const Map<String, List<int>> {name} = {{"]
    for version_group, payload in matrix["versionGroups"].items():
        ranges = payload[json_key]
        if not ranges:
            continue
        flat = ", ".join(str(value) for pair in ranges for value in pair)
        lines.append(f"  '{version_group}': [{flat}],")
    lines.append("};")
    return "\n".join(lines)


def render_dart(matrix: dict[str, Any]) -> str:
    sections = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND.",
        "// Run: python tools/generate_sprite_version_existence.py",
        "// Source: PokeAPI/sprites exact Git tree paths.",
        "",
        f"const String kSpriteExistenceSourceCommit = '{matrix['sourceCommit']}';",
        "",
        _dart_ranges("kSpriteFrontIdRanges", matrix, "frontRanges"),
        "",
        _dart_ranges("kSpriteBackIdRanges", matrix, "backRanges"),
        "",
        _dart_ranges(
            "kSpriteAnimatedFrontIdRanges", matrix, "animatedFrontRanges"
        ),
        "",
        _dart_ranges(
            "kSpriteAnimatedBackIdRanges", matrix, "animatedBackRanges"
        ),
        "",
    ]
    return "\n".join(sections)


def write_outputs(matrix: dict[str, Any], *, repo_root: Path) -> None:
    json_path = repo_root / "data" / "dex" / "sprite_version_existence.json"
    dart_path = (
        repo_root
        / "flutter"
        / "lib"
        / "features"
        / "dex"
        / "sprite_version_existence.g.dart"
    )
    json_path.parent.mkdir(parents=True, exist_ok=True)
    dart_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(
        json.dumps(matrix, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    dart_path.write_text(render_dart(matrix), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", default="master", help="PokeAPI/sprites branch")
    parser.add_argument("--repo-root", type=Path, default=ROOT)
    args = parser.parse_args()
    matrix = build_matrix(ref=args.ref, token=os.environ.get("GITHUB_TOKEN"))
    write_outputs(matrix, repo_root=args.repo_root.resolve())
    print(
        f"Generated {len(matrix['versionGroups'])} version groups from "
        f"PokeAPI/sprites@{matrix['sourceCommit']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
