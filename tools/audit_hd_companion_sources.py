#!/usr/bin/env python3
"""Read public HD GIF indexes and compare with TitoDex identities.

Research only: never changes the app catalog or downloads complete GIFs.
Index pages are cached locally; media verification reads only the GIF header.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import time
import unicodedata
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORIGIN = "https://www.pkparaiso.com/"
SOURCES = {
    "swsh-hd": ORIGIN + "espada_escudo/sprites_pokemon.php",
    "usum-hd": ORIGIN + "ultra-sol-ultra-luna/sprites_pokemon_sin_bordes.php",
}


class IndexParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.active = None

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            href = dict(attrs).get("href", "")
            self.active = {"href": href, "label": ""}
            self.links.append(self.active)

    def handle_data(self, data):
        if self.active is not None:
            self.active["label"] += data

    def handle_endtag(self, tag):
        if tag == "a":
            self.active = None


def fetch_page(url, cache):
    path = cache / (hashlib.sha256(url.encode()).hexdigest() + ".html")
    if path.exists():
        return path.read_text(encoding="utf-8")
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "TitoDex-media-audit/1.0"})
            with urllib.request.urlopen(request, timeout=30) as response:
                data = response.read().decode("utf-8", "replace")
            path.write_text(data, encoding="utf-8")
            return data
        except Exception:
            if attempt == 2:
                raise
            time.sleep(0.5 * (attempt + 1))


def parse_page(source, url, text):
    parser = IndexParser()
    parser.feed(text)
    items, pages = [], set()
    for link in parser.links:
        href = urllib.parse.urljoin(ORIGIN, link["href"])
        parts = urllib.parse.urlsplit(href)
        if parts.hostname != "www.pkparaiso.com":
            continue
        if "cid=" in parts.query and parts.path == urllib.parse.urlsplit(SOURCES[source]).path:
            pages.add(urllib.parse.urlunsplit(parts._replace(fragment="")))
        if not parts.path.endswith(".gif") or "gigante/" not in parts.path:
            continue
        stem = Path(parts.path).stem
        shiny = stem.endswith("-s")
        match = re.search(r"#(\d+)\s", link["label"])
        items.append({
            "source": source, "url": href, "sourcePage": url,
            "sourceSlug": stem[:-2] if shiny else stem,
            "shiny": shiny,
            "sourceSpeciesId": int(match[1]) if match else None,
        })
    return items, pages


def crawl(cache):
    cache.mkdir(parents=True, exist_ok=True)
    inventory, page_status, jobs = {}, [], []
    for source, url in SOURCES.items():
        content = fetch_page(url, cache)
        items, pages = parse_page(source, url, content)
        inventory.update({x["url"]: x for x in items})
        page_status.append({"url": url, "source": source, "items": len(items)})
        jobs.extend((source, page) for page in sorted(pages))
    def read(job):
        source, url = job
        try:
            items, _ = parse_page(source, url, fetch_page(url, cache))
            return items, {"url": url, "source": source, "items": len(items)}
        except Exception as error:
            return [], {"url": url, "source": source, "error": str(error)}
    with ThreadPoolExecutor(max_workers=3) as pool:
        for index, (items, status) in enumerate(pool.map(read, jobs), 1):
            inventory.update({x["url"]: x for x in items})
            page_status.append(status)
            print(json.dumps({"pagesDone": index, "pagesTotal": len(jobs), "items": len(inventory), "error": status.get("error")}), flush=True)
    return {"generatedAt": datetime.now(timezone.utc).isoformat(), "pages": page_status, "assets": sorted(inventory.values(), key=lambda x: x["url"])}


def slug(text):
    text = text.replace("♀", "-f").replace("♂", "-m").replace("’", "").replace("'", "")
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")


def baseline():
    species_path = ROOT / "data/l10n/zh/species.json"
    forms_path = ROOT / "data/dex/form_media_audit.json"
    species = json.loads(species_path.read_text(encoding="utf-8"))
    forms = json.loads(forms_path.read_text(encoding="utf-8"))["forms"]
    default_forms = {f["speciesId"]: f for f in forms if f["formType"]["isDefault"]}
    targets = []
    for key, value in sorted(species.items(), key=lambda pair: int(pair[0])):
        number = int(key)
        form = default_forms.get(number)
        targets.append({"speciesId": number, "formKey": form["formKey"] if form else slug(value["nameEn"]), "nameZh": value["nameZh"], "nameEn": value["nameEn"], "alternate": False})
    targets.extend({"speciesId": f["speciesId"], "formKey": f["formKey"], "nameZh": f["nameZh"], "nameEn": species[str(f["speciesId"])]["nameEn"], "alternate": True} for f in forms if not f["formType"]["isDefault"])
    return targets, {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [species_path, forms_path]}


def coverage_summary(rows, normal_field="normal", shiny_field="shiny"):
    summary = {}
    for group, alt in [("speciesDefaults", False), ("alternateForms", True)]:
        selected = [row for row in rows if row["alternate"] == alt]
        summary[group] = {"total": len(selected), "normal": sum(bool(r[normal_field]) for r in selected), "shiny": sum(bool(r[shiny_field]) for r in selected), "both": sum(bool(r[normal_field] and r[shiny_field]) for r in selected)}
    return summary


def match_inventory(inventory, overrides, targets=None):
    hashes = {}
    if targets is None:
        targets, hashes = baseline()
    exact = {t["formKey"]: t for t in targets}
    bases = {slug(t["nameEn"]): t for t in targets if not t["alternate"]}
    aliases = dict(overrides)
    resolved, unresolved = [], []
    for item in inventory["assets"]:
        raw = item["sourceSlug"]
        # These are exact spelling equivalences, not inheritance of forms.
        normal = raw.replace("-gigantamax", "-gmax")
        alias = aliases.get(raw)
        key = alias.get("formKey") if isinstance(alias, dict) else alias or normal
        keys = alias.get("formKeys", [key]) if isinstance(alias, dict) else [key]
        candidates = [exact.get(k) for k in keys]
        method = "explicit_alias" if raw in aliases else "exact_key"
        if not alias and candidates == [None] and raw in bases:
            candidates = [bases[raw]]
            method = "default_species_name"
        corrected_id = isinstance(alias, dict) and alias.get("sourceSpeciesId") == item["sourceSpeciesId"] and "sourceSpeciesId" in alias
        found = bool(candidates) and all(candidates)
        valid = found and len({t["speciesId"] for t in candidates}) == 1 and all(item["sourceSpeciesId"] is None or item["sourceSpeciesId"] == t["speciesId"] or corrected_id for t in candidates)
        if valid:
            for target in candidates:
                resolved.append(dict(item, formKey=target["formKey"], speciesId=target["speciesId"], alternate=target["alternate"], mapping=method, sharedVisual=len(candidates)>1, sourceIdCorrected=bool(corrected_id), mappingNote=alias.get("note") if isinstance(alias, dict) else None))
        else:
            reason = "source_id_mismatch" if found else "unmapped_identity"
            if not found and raw.endswith("-f"):
                reason = "extra_female_visual_not_separate_local_form"
            elif not found and "-nosparks" in raw:
                reason = "extra_effect_variant_unmapped"
            unresolved.append(dict(item, reason=reason))
    rows = []
    for target in targets:
        matches = [a for a in resolved if a["formKey"] == target["formKey"]]
        rows.append(dict(target, normal=[a["url"] for a in matches if not a["shiny"]], shiny=[a["url"] for a in matches if a["shiny"]]))
    return {"generatedAt": datetime.now(timezone.utc).isoformat(), "scope": "pkparaiso swsh-hd + usum-hd index coverage; URLs not fully decoded", "inputSha256": hashes, "summary": coverage_summary(rows), "targets": rows, "mappedAssets": resolved, "unresolvedAssets": unresolved, "pages": inventory["pages"]}


def read_headers(work_dir):
    checkpoint = work_dir / "headers.jsonl"
    saved = {}
    if checkpoint.exists():
        for line in checkpoint.read_text(encoding="utf-8").splitlines():
            item = json.loads(line)
            saved[item["url"]] = item
    return saved


def attach_verification(audit, inventory, headers):
    """An indexed URL is not counted as available until its GIF header succeeds."""
    urls = {a["url"] for a in inventory["assets"]}
    checked = {url: headers[url] for url in urls if url in headers}
    valid = {url for url, value in checked.items() if value.get("gifHeaderValid")}
    for row in audit["targets"]:
        row["verifiedNormal"] = [url for url in row["normal"] if url in valid]
        row["verifiedShiny"] = [url for url in row["shiny"] if url in valid]
    audit["verifiedSummary"] = coverage_summary(audit["targets"], "verifiedNormal", "verifiedShiny")
    audit["verification"] = {
        "method": "HTTP GET Range bytes=0-12; read at most 13 response-body bytes; GIF signature and logical screen size only",
        "indexedUrls": len(urls), "checkedUrls": len(checked),
        "validGifHeaders": len(valid), "unverifiedUrls": sorted(urls - set(checked)),
        "failedUrls": sorted(set(checked) - valid),
        "doesNotVerify": ["complete GIF decoding", "animation frame count", "loop timing", "transparency", "every image's visual identity or shiny colors", "per-frame occupied bounds", "device performance"],
    }
    audit["assets"] = [dict(a, verification=checked.get(a["url"])) for a in inventory["assets"]]
    return audit


def export_audit(audit, directory):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "hd-companion-coverage.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    fields = ["speciesId", "formKey", "nameZh", "alternate", "normalStatus", "shinyStatus", "normalUrls", "shinyUrls"]
    with (directory / "hd-companion-coverage.csv").open("w", encoding="utf-8-sig", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        def status(row, indexed, verified):
            return "verified_header" if row[verified] else "indexed_unverified" if row[indexed] else "no_mapped_index_entry"
        for row in audit["targets"]:
            writer.writerow({**{key: row[key] for key in fields[:4]}, "normalStatus": status(row, "normal", "verifiedNormal"), "shinyStatus": status(row, "shiny", "verifiedShiny"), "normalUrls": " | ".join(row["normal"]), "shinyUrls": " | ".join(row["shiny"])})


def verify_headers(inventory, work_dir, retry_failed=False):
    """Read at most 13 response-body bytes per GIF; never retain animation data."""
    checkpoint = work_dir / "headers.jsonl"
    saved = read_headers(work_dir)
    jobs = [a["url"] for a in inventory["assets"] if a["url"] not in saved or (retry_failed and not saved[a["url"]].get("gifHeaderValid"))]
    def inspect(url):
        result = {"url": url, "checkedAt": datetime.now(timezone.utc).isoformat()}
        try:
            request = urllib.request.Request(url, headers={"Range": "bytes=0-12", "User-Agent": "TitoDex-media-audit/1.0"})
            with urllib.request.urlopen(request, timeout=15) as response:
                header = response.read(13)
                result.update(status=response.status, contentType=response.headers.get("Content-Type"), contentRange=response.headers.get("Content-Range"), contentLength=response.headers.get("Content-Length"))
            result["gifHeaderValid"] = len(header) == 13 and header[:6] in (b"GIF87a", b"GIF89a")
            if result["gifHeaderValid"]:
                result.update(width=int.from_bytes(header[6:8], "little"), height=int.from_bytes(header[8:10], "little"))
        except Exception as error:
            result.update(gifHeaderValid=False, error=str(error))
        return result
    with checkpoint.open("a", encoding="utf-8") as output, ThreadPoolExecutor(max_workers=3) as pool:
        futures = [pool.submit(inspect, url) for url in jobs]
        for index, future in enumerate(as_completed(futures), 1):
            result = future.result()
            output.write(json.dumps(result) + "\n")
            output.flush()
            saved[result["url"]] = result
            if index % 50 == 0 or index == len(jobs):
                print(json.dumps({"headersDone": len(saved), "total": len(inventory["assets"]), "failed": sum(not x.get("gifHeaderValid") for x in saved.values())}), flush=True)
    return saved


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--crawl", action="store_true")
    parser.add_argument("--work-dir", type=Path, default=ROOT / "flutter/build/hd-companion-audit")
    parser.add_argument("--aliases", type=Path)
    parser.add_argument("--verify-headers", action="store_true")
    parser.add_argument("--retry-failed", action="store_true")
    parser.add_argument("--export-dir", type=Path)
    args = parser.parse_args()
    args.work_dir.mkdir(parents=True, exist_ok=True)
    inventory_path = args.work_dir / "source-inventory.json"
    if args.crawl:
        inventory = crawl(args.work_dir / "pages")
        inventory_path.write_text(json.dumps(inventory, ensure_ascii=False, indent=2), encoding="utf-8")
    else:
        inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
    if args.verify_headers:
        verify_headers(inventory, args.work_dir, args.retry_failed)
    aliases_path = args.aliases or ROOT / "data/dex/hd_companion_source_aliases.json"
    aliases = json.loads(aliases_path.read_text(encoding="utf-8"))
    audit = match_inventory(inventory, aliases)
    audit["inputSha256"][str(aliases_path.relative_to(ROOT)) if aliases_path.is_absolute() and aliases_path.is_relative_to(ROOT) else str(aliases_path)] = hashlib.sha256(aliases_path.read_bytes()).hexdigest()
    attach_verification(audit, inventory, read_headers(args.work_dir))
    (args.work_dir / "coverage.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.export_dir:
        export_audit(audit, args.export_dir)
    print(json.dumps({"summary": audit["summary"], "assets": len(inventory["assets"]), "unresolvedAssets": len(audit["unresolvedAssets"])}), flush=True)


if __name__ == "__main__":
    main()
