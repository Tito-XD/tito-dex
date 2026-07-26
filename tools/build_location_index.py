#!/usr/bin/env python3
"""Reverse location index: game version → area → who appears there.

The bundle has always answered "where does this Pokémon appear?" through each
detail's ``obtainLocationsByVersion``.  The location dex / current-route mode
need the opposite question — "what appears *here*?" — and inverting 1025
detail files on-device would burn cold-start time the precomputed-catalog work
(v0.5.0) fought to save.  So the inversion happens once, at build time.

Output shape (``location_index.json`` at the bundle root, decoded on demand —
it is deliberately NOT part of ``dex_catalog.json``, which the app decodes on
every cold start):

    {
      "version": 1,
      "byVersion": {
        "soulsilver": {
          "kanto-route-34-area": {
            "labelZh": "34号道路",
            "entries": [
              {"speciesId": 63, "methods": ["walk"], "maxChance": 10, ...}
            ]
          }
        }
      }
    }

Entries keep the P0-2 form-aware fields (formKey / formAmbiguous / special
flags / teraType) and the encounter conditions, omitting empty values the same
way ``ObtainLocationEntry.toJson`` does.  Sources are the detail-level list
plus every form's own list; exact duplicates collapse.
"""

from __future__ import annotations

from typing import Any

INDEX_VERSION = 1

_FLAG_KEYS = (
    "isAlpha",
    "isTitan",
    "isTotem",
    "isRaid",
    "isFixedEncounter",
    "formAmbiguous",
)
_VALUE_KEYS = (
    "teraType",
    "minLevel",
    "maxLevel",
    "maxChance",
    "rateKind",
    "rateValue",
)
_LIST_KEYS = ("methods", "conditions")


class LocationIndexBuilder:
    def __init__(self) -> None:
        # versionKey -> areaSlug -> {"labelZh": str, "entries": [dict]}
        self._by_version: dict[str, dict[str, dict[str, Any]]] = {}
        self._seen: set[tuple] = set()
        self.entry_count = 0

    def add_detail(self, species_id: int, detail: dict[str, Any]) -> int:
        """Feed one ``details/<id>.json`` payload. Returns entries added."""
        added = 0
        added += self._add_version_map(
            species_id, None, detail.get("obtainLocationsByVersion")
        )
        for form in detail.get("forms") or []:
            added += self._add_version_map(
                species_id,
                form.get("key"),
                form.get("obtainLocationsByVersion"),
            )
        return added

    def _add_version_map(
        self,
        species_id: int,
        fallback_form_key: Any,
        by_version: Any,
    ) -> int:
        if not isinstance(by_version, dict):
            return 0
        added = 0
        for version_key, entries in by_version.items():
            if not isinstance(entries, list):
                continue
            for raw in entries:
                if not isinstance(raw, dict):
                    continue
                if self._add_entry(
                    version_key, species_id, fallback_form_key, raw
                ):
                    added += 1
        return added

    def _add_entry(
        self,
        version_key: str,
        species_id: int,
        fallback_form_key: Any,
        raw: dict[str, Any],
    ) -> bool:
        area_slug = raw.get("areaSlug")
        if not area_slug:
            return False
        entry_species = raw.get("speciesId") or species_id
        form_key = raw.get("formKey") or fallback_form_key
        methods = tuple(raw.get("methods") or ())
        conditions = tuple(raw.get("conditions") or ())
        dedup = (
            version_key,
            area_slug,
            entry_species,
            form_key,
            methods,
            conditions,
            raw.get("minLevel"),
            raw.get("maxLevel"),
        )
        if dedup in self._seen:
            return False
        self._seen.add(dedup)

        entry: dict[str, Any] = {"speciesId": entry_species}
        pokemon_id = raw.get("pokemonId")
        if pokemon_id and pokemon_id != entry_species:
            entry["pokemonId"] = pokemon_id
        if form_key:
            entry["formKey"] = form_key
        for key in _VALUE_KEYS:
            value = raw.get(key)
            if value is not None and value != 0 and value != "":
                entry[key] = value
        for key in _LIST_KEYS:
            value = raw.get(key)
            if value:
                entry[key] = list(value)
        for key in _FLAG_KEYS:
            if raw.get(key):
                entry[key] = True

        area = self._by_version.setdefault(version_key, {}).setdefault(
            area_slug, {"labelZh": raw.get("areaLabelZh") or "", "entries": []}
        )
        if not area["labelZh"] and raw.get("areaLabelZh"):
            area["labelZh"] = raw["areaLabelZh"]
        area["entries"].append(entry)
        self.entry_count += 1
        return True

    @property
    def version_count(self) -> int:
        return len(self._by_version)

    def build(self) -> dict[str, Any]:
        """Deterministic output: versions, areas and entries all sorted."""
        by_version: dict[str, Any] = {}
        for version_key in sorted(self._by_version):
            areas: dict[str, Any] = {}
            for area_slug in sorted(self._by_version[version_key]):
                area = self._by_version[version_key][area_slug]
                areas[area_slug] = {
                    "labelZh": area["labelZh"],
                    "entries": sorted(
                        area["entries"],
                        key=lambda e: (e["speciesId"], e.get("formKey") or ""),
                    ),
                }
            by_version[version_key] = areas
        return {"version": INDEX_VERSION, "byVersion": by_version}
