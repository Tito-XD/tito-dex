#!/usr/bin/env python3
"""Apply the v19 item enrichment to the local v18 bundle (never publishes)."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import shutil
import subprocess
import tarfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BASE_STAGING = ROOT / "dist" / "dex-v18" / "staging"
BASE_ROOT_MANIFEST = ROOT / "dist" / "dex-v18" / "upload" / "bundle-manifest.json"
DEFAULT_ENRICHMENT = ROOT / "data" / "l10n" / "zh" / "items_v19_enrichment.json"
DEFAULT_POKEAPI_ENRICHMENT = (
    ROOT / "data" / "l10n" / "zh" / "items_v19_pokeapi_enrichment.json"
)
DEFAULT_TM_ENRICHMENT = ROOT / "data" / "l10n" / "zh" / "tm_v19_enrichment.json"
DEFAULT_NAME_OVERRIDES = (
    ROOT / "data" / "l10n" / "zh" / "item_name_overrides_v19.json"
)
DEFAULT_ITEM_MEDIA_OVERRIDES = (
    ROOT / "data" / "l10n" / "zh" / "item_media_overrides_v19.json"
)
DEFAULT_ITEM_MEDIA_EXACT_OVERRIDES = (
    ROOT / "data" / "l10n" / "zh" / "item_media_exact_overrides_v19.json"
)
DEFAULT_DESCRIPTION_OVERRIDES = (
    ROOT / "data" / "l10n" / "zh" / "item_description_overrides_v19.json"
)
DEFAULT_SPRITES = ROOT / "data" / "assets" / "item-sprites"
DEFAULT_MEDIA_CATALOG = ROOT / "data" / "l10n" / "zh" / "media_catalog_52poke.json"
DEFAULT_FORM_MEDIA_AUDIT = ROOT / "data" / "dex" / "form_media_audit.json"
DEFAULT_ITEM_MEDIA_AUDIT = (
    ROOT / "data" / "dex" / "item_media_audit_v19.json"
)
DEFAULT_OUTPUT = ROOT / "dist" / "dex-v19"
BUNDLE_VERSION = 19
CDN_PREFIX = "v5"
CDN_BASE = "https://dex.tito.cafe"
ARCHIVE_NAME = f"bundle-v{BUNDLE_VERSION}.tar.zst"
POKEAPI_SPRITES_COMMIT = "8777f5066431f39fbe07614e0250a61b2029671c"
MEDIA_FALLBACK_NAMES = {
    312: "负电拍拍",
    973: "缠红鹤",
    990: "铁辙迹",
    1022: "铁磐岩",
    1023: "铁头壳",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def directory_size(path: Path) -> int:
    return sum(file.stat().st_size for file in path.rglob("*") if file.is_file())


def create_zst_tar(source_dir: Path, archive_path: Path) -> None:
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as tar:
        for file in sorted(source_dir.rglob("*")):
            if not file.is_file() or file.resolve() == archive_path.resolve():
                continue
            tar.add(file, arcname=file.relative_to(source_dir).as_posix())
    try:
        subprocess.run(
            ["zstd", "-q", "-f", "-o", str(archive_path), "-"],
            input=buffer.getvalue(),
            check=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        import zstandard

        archive_path.write_bytes(
            zstandard.ZstdCompressor(level=19).compress(buffer.getvalue())
        )


def apply_enrichment(
    staging: Path, enrichment: dict[str, Any], sprites_dir: Path
) -> dict[str, int]:
    items_path = staging / "items.json"
    items: dict[str, dict[str, Any]] = json.loads(
        items_path.read_text(encoding="utf-8")
    )
    by_slug = {item["slug"]: item for item in items.values()}
    text_added = 0
    names_added = 0
    for slug, patch in (enrichment.get("itemsBySlug") or {}).items():
        item = by_slug.get(slug)
        if item is None:
            continue
        if patch.get("nameZh") and patch["nameZh"] != item.get("nameZh"):
            item["nameZh"] = patch["nameZh"]
            names_added += 1
        if patch.get("descriptionZh") and not (
            item.get("descriptionZh") or item.get("effectZh")
        ):
            item["descriptionZh"] = patch["descriptionZh"]
            item["effectZh"] = patch.get("effectZh") or patch["descriptionZh"]
            text_added += 1
        for key in (
            "descriptionSource",
            "spriteMappingStatus",
            "spriteSharedWith",
            "spriteSource",
            "spriteSourceFile",
            "spriteSourceUrl",
            "spriteLicense",
            "spriteWidth",
            "spriteHeight",
        ):
            if patch.get(key) is not None:
                item[key] = patch[key]
        source_file = patch.get("spriteFile52poke")
        if source_file:
            item.setdefault("spriteSource", "52poke")
            item.setdefault("spriteSourceFile", source_file)
            item.setdefault("spriteLicense", "CC BY-NC-SA 4.0")
            dimensions = patch.get("spriteDimensions") or []
            if len(dimensions) == 2:
                item.setdefault("spriteWidth", dimensions[0])
                item.setdefault("spriteHeight", dimensions[1])

    sprite_dest = staging / "item-sprites"
    sprite_dest.mkdir(parents=True, exist_ok=True)
    copied = 0
    for source in sorted(sprites_dir.glob("*.png")):
        item = by_slug.get(source.stem)
        if item is None:
            continue
        target = sprite_dest / source.name
        if not target.exists() or target.read_bytes() != source.read_bytes():
            shutil.copyfile(source, target)
            copied += 1
        item["spriteUrl"] = f"{CDN_BASE}/{CDN_PREFIX}/item-sprites/{source.name}"

    items_path.write_text(
        json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    descriptions = sum(
        bool(item.get("descriptionZh") or item.get("effectZh"))
        for item in items.values()
    )
    sprites = sum(
        (sprite_dest / f"{item['slug']}.png").is_file() for item in items.values()
    )
    return {
        "items": len(items),
        "namesAdded": names_added,
        "descriptionsAdded": text_added,
        "descriptionCoverage": descriptions,
        "spritesCopiedOrReplaced": copied,
        "spriteCoverage": sprites,
    }


def update_attribution(staging: Path) -> None:
    path = staging / "ITEMS_ATTRIBUTION.txt"
    text = path.read_text(encoding="utf-8")
    addition = (
        "\nNewer high-resolution bag icons and additional Simplified-Chinese item "
        "descriptions are sourced from 神奇宝贝百科 (52Poké Wiki) under the "
        "same CC BY-NC-SA 4.0 license. Original-resolution files are bundled; "
        "the app does not hotlink wiki images.\n"
    )
    if "Newer high-resolution bag icons" not in text:
        path.write_text(text.rstrip() + "\n" + addition, encoding="utf-8")


def fill_media_tails(staging: Path) -> int:
    catalog_path = staging / "media_catalog_52poke.json"
    catalog: dict[str, dict[str, Any]] = json.loads(
        catalog_path.read_text(encoding="utf-8")
    )
    summaries_path = staging / "summaries.json"
    summaries: list[dict[str, Any]] = json.loads(
        summaries_path.read_text(encoding="utf-8")
    )
    for summary in summaries:
        species_id = int(summary["id"])
        corrected = MEDIA_FALLBACK_NAMES.get(species_id)
        if corrected:
            summary["nameZh"] = corrected
        if species_id not in MEDIA_FALLBACK_NAMES:
            continue
        entry = catalog.setdefault(
            str(species_id),
            {
                "id": species_id,
                "nameZh": corrected,
                "cries": [
                    {
                        "title": f"{species_id:04d}_cry.ogg",
                        "url": "https://raw.githubusercontent.com/PokeAPI/cries/"
                        f"main/cries/pokemon/latest/{species_id}.ogg",
                    }
                ],
                "forms": [
                    {
                        "file": "https://raw.githubusercontent.com/PokeAPI/"
                        f"sprites/{POKEAPI_SPRITES_COMMIT}/sprites/pokemon/"
                        "other/home/"
                        f"{species_id}.png",
                        "kind": "PokeAPI HOME",
                    }
                ],
                "source": "PokeAPI fallback",
            },
        )
        entry["nameZh"] = corrected
        detail_path = staging / "details" / f"{species_id}.json"
        form_key = None
        if detail_path.is_file():
            detail = json.loads(detail_path.read_text(encoding="utf-8"))
            if isinstance(detail.get("summary"), dict):
                detail["summary"]["nameZh"] = corrected
            default_form = next(
                (
                    form
                    for form in detail.get("forms") or []
                    if form.get("isDefault")
                ),
                None,
            )
            form_key = (default_form or {}).get("key")
            detail_path.write_text(
                json.dumps(detail, ensure_ascii=False, separators=(",", ":")),
                encoding="utf-8",
            )
        if form_key is None:
            form_key = next(
                (
                    key
                    for art in entry.get("forms") or []
                    for key in art.get("formKeys") or []
                ),
                None,
            )
        cries = entry.setdefault("cries", [])
        if not cries:
            cries.append(
                {
                    "title": f"{species_id:04d}_cry.ogg",
                    "url": "https://raw.githubusercontent.com/PokeAPI/cries/"
                    f"main/cries/pokemon/latest/{species_id}.ogg",
                    "formKeys": [form_key] if form_key else [],
                    "formKey": form_key,
                    "formCode": "",
                    "mappingStatus": "exact" if form_key else "unresolved",
                    "isFormSpecific": False,
                    "fallbackForAllForms": True,
                    "source": "PokeAPI",
                }
            )
        if not entry.get("forms") and form_key:
            url = (
                "https://raw.githubusercontent.com/PokeAPI/"
                f"sprites/{POKEAPI_SPRITES_COMMIT}/sprites/pokemon/"
                f"other/home/{species_id}.png"
            )
            entry["forms"] = [
                {
                    "file": url,
                    "kind": "PokeAPI HOME",
                    "formKeys": [form_key],
                    "formKey": form_key,
                    "formCode": "",
                    "mappingStatus": "exact",
                    "url": url,
                    "source": "PokeAPI",
                    "license": "CC-BY 4.0",
                    "mediaType": "static",
                    "isShiny": False,
                    "urlVerified": True,
                }
            ]
        entry["source"] = "52poke imageinfo + PokeAPI cry fallback"
    summaries_path.write_text(
        json.dumps(summaries, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    catalog_path.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return len(catalog)


def build(args: argparse.Namespace) -> dict[str, int]:
    staging = args.output / "staging"
    upload = args.output / "upload"
    for path in (staging, upload):
        if path.exists():
            shutil.rmtree(path)
    shutil.copytree(args.base_staging, staging)
    shutil.copyfile(args.media_catalog, staging / "media_catalog_52poke.json")
    shutil.copyfile(args.form_media_audit, staging / "form_media_audit.json")
    if not args.item_media_audit.is_file():
        raise FileNotFoundError(
            f"Missing item media audit: {args.item_media_audit}"
        )
    shutil.copyfile(
        args.item_media_audit, staging / "item_media_audit_v19.json"
    )
    # A historical staging tree may contain its already-compressed archive.
    # Never nest that archive inside the next one (it roughly doubles v19).
    for old_archive in staging.glob("bundle*.tar.zst"):
        old_archive.unlink()

    enrichment = json.loads(args.enrichment.read_text(encoding="utf-8"))
    combined = enrichment.setdefault("itemsBySlug", {})
    if args.pokeapi_enrichment.is_file():
        pokeapi_enrichment = json.loads(
            args.pokeapi_enrichment.read_text(encoding="utf-8")
        )
        for slug, patch in (
            pokeapi_enrichment.get("itemsBySlug") or {}
        ).items():
            combined.setdefault(slug, {}).update(patch)
    if args.tm_enrichment.is_file():
        tm_enrichment = json.loads(args.tm_enrichment.read_text(encoding="utf-8"))
        for slug, patch in (tm_enrichment.get("itemsBySlug") or {}).items():
            combined.setdefault(slug, {}).update(patch)
    if args.name_overrides.is_file():
        name_overrides = json.loads(args.name_overrides.read_text(encoding="utf-8"))
        for slug, patch in (name_overrides.get("itemsBySlug") or {}).items():
            combined.setdefault(slug, {}).update(patch)
    if args.description_overrides.is_file():
        description_overrides = json.loads(
            args.description_overrides.read_text(encoding="utf-8")
        )
        for slug, patch in (
            description_overrides.get("itemsBySlug") or {}
        ).items():
            combined.setdefault(slug, {}).update(patch)
    if args.item_media_overrides.is_file():
        media_overrides = json.loads(
            args.item_media_overrides.read_text(encoding="utf-8")
        )
        for slug, patch in (media_overrides.get("itemsBySlug") or {}).items():
            combined.setdefault(slug, {}).update(patch)
    if args.item_media_exact_overrides.is_file():
        exact_media_overrides = json.loads(
            args.item_media_exact_overrides.read_text(encoding="utf-8")
        )
        for slug, patch in (
            exact_media_overrides.get("itemsBySlug") or {}
        ).items():
            combined.setdefault(slug, {}).update(patch)
    stats = apply_enrichment(staging, enrichment, args.sprites_dir)
    stats["mediaCatalogEntries"] = fill_media_tails(staging)
    update_attribution(staging)

    published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    manifest_path = staging / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.update(
        {
            "version": BUNDLE_VERSION,
            "downloadedAt": published_at,
            "itemCatalogSource": "PokeAPI + 52poke (CC BY-NC-SA 4.0)",
            "itemDescriptionCoverage": stats["descriptionCoverage"],
            "itemSpriteCount": stats["spriteCoverage"],
            "itemHighResolutionSprites": True,
            "mediaCatalogEntries": stats["mediaCatalogEntries"],
            "formMediaAudit": "form_media_audit.json",
            "itemMediaAudit": "item_media_audit_v19.json",
        }
    )
    form_media_summary = json.loads(
        args.form_media_audit.read_text(encoding="utf-8")
    )["summary"]
    manifest["alternateFormMediaCoverage"] = form_media_summary[
        "alternateCoverage"
    ]
    manifest["sizeBytes"] = directory_size(staging)
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    archive = staging / ARCHIVE_NAME
    create_zst_tar(staging, archive)
    versioned = upload / CDN_PREFIX
    shutil.copytree(staging, versioned)

    root_manifest = json.loads(args.base_root_manifest.read_text(encoding="utf-8"))
    root_manifest.update(
        {
            "bundleVersion": BUNDLE_VERSION,
            "archiveUrl": f"{CDN_BASE}/{CDN_PREFIX}/{ARCHIVE_NAME}",
            "archiveSha256": sha256_file(versioned / ARCHIVE_NAME),
            "archiveSizeBytes": (versioned / ARCHIVE_NAME).stat().st_size,
            "publishedAt": published_at,
            "itemDescriptionCoverage": stats["descriptionCoverage"],
            "itemSpriteCount": stats["spriteCoverage"],
            "itemHighResolutionSprites": True,
            "mediaCatalogEntries": stats["mediaCatalogEntries"],
            "itemMediaAudit": "item_media_audit_v19.json",
            "alternateFormMediaCoverage": form_media_summary[
                "alternateCoverage"
            ],
        }
    )
    upload.mkdir(parents=True, exist_ok=True)
    (upload / "bundle-manifest.json").write_text(
        json.dumps(root_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(stats, ensure_ascii=False, indent=2), flush=True)
    print(f"built local v19 candidate -> {args.output}", flush=True)
    return stats


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-staging", type=Path, default=BASE_STAGING)
    parser.add_argument("--base-root-manifest", type=Path, default=BASE_ROOT_MANIFEST)
    parser.add_argument("--enrichment", type=Path, default=DEFAULT_ENRICHMENT)
    parser.add_argument(
        "--pokeapi-enrichment", type=Path, default=DEFAULT_POKEAPI_ENRICHMENT
    )
    parser.add_argument(
        "--tm-enrichment", type=Path, default=DEFAULT_TM_ENRICHMENT
    )
    parser.add_argument(
        "--name-overrides", type=Path, default=DEFAULT_NAME_OVERRIDES
    )
    parser.add_argument(
        "--item-media-overrides",
        type=Path,
        default=DEFAULT_ITEM_MEDIA_OVERRIDES,
    )
    parser.add_argument(
        "--item-media-exact-overrides",
        type=Path,
        default=DEFAULT_ITEM_MEDIA_EXACT_OVERRIDES,
    )
    parser.add_argument(
        "--description-overrides",
        type=Path,
        default=DEFAULT_DESCRIPTION_OVERRIDES,
    )
    parser.add_argument("--sprites-dir", type=Path, default=DEFAULT_SPRITES)
    parser.add_argument(
        "--media-catalog", type=Path, default=DEFAULT_MEDIA_CATALOG
    )
    parser.add_argument(
        "--form-media-audit", type=Path, default=DEFAULT_FORM_MEDIA_AUDIT
    )
    parser.add_argument(
        "--item-media-audit", type=Path, default=DEFAULT_ITEM_MEDIA_AUDIT
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    build(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
