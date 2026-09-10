"""Guard against claiming form/shiny coverage from wrong or unavailable media."""
import json
import tempfile
import unittest
from pathlib import Path

from tools.audit_hd_companion_sources import (
    ROOT, SOURCES, attach_verification, baseline, export_audit, match_inventory,
    parse_page,
)


def target(number, key, name, alternate=False):
    return dict(speciesId=number, formKey=key, nameEn=name, nameZh=name, alternate=alternate)


def asset(raw, number, shiny=False):
    return dict(sourceSlug=raw, sourceSpeciesId=number, shiny=shiny,
                source="swsh-hd", sourcePage=SOURCES["swsh-hd"],
                url=f"https://www.pkparaiso.com/imagenes/espada_escudo/sprites/animados-gigante/{raw}{'-s' if shiny else ''}.gif")


class HdSourceAuditTests(unittest.TestCase):
    def audit(self, assets, targets, aliases=None):
        return match_inventory(dict(assets=assets, pages=[]), aliases or {}, targets)

    def test_index_uses_original_gif_not_thumbnail_or_offsite_link(self):
        html = '''<a href="imagenes/espada_escudo/sprites/animados-gigante/pikachu-s.gif">
          <img src="imagenes/espada_escudo/sprites/animados/pikachu-s.gif">#025 pikachu-s</a>
          <a href="https://example.com/animados-gigante/pikachu.gif">#025 pikachu</a>
          <a href="espada_escudo/sprites_pokemon.php?cid=2&amp;order=#sprites">next</a>'''
        items, pages = parse_page("swsh-hd", SOURCES["swsh-hd"], html)
        self.assertEqual(len(items), 1)
        self.assertTrue(items[0]["shiny"])
        self.assertEqual(items[0]["sourceSpeciesId"], 25)
        self.assertIn("animados-gigante/pikachu-s.gif", items[0]["url"])
        self.assertEqual(pages, {SOURCES["swsh-hd"] + "?cid=2&order="})

    def test_default_never_fills_missing_form_or_shiny(self):
        result = self.audit([asset("pikachu", 25)], [target(25,"pikachu","Pikachu"), target(25,"pikachu-rock-star","Pikachu",True)])
        self.assertEqual(result["summary"]["speciesDefaults"]["normal"], 1)
        self.assertEqual(result["summary"]["speciesDefaults"]["shiny"], 0)
        self.assertEqual(result["summary"]["alternateForms"]["normal"], 0)

    def test_unmodeled_female_does_not_replace_default(self):
        result = self.audit([asset("pikachu-f", 25)], [target(25,"pikachu","Pikachu")])
        self.assertEqual(result["mappedAssets"], [])
        self.assertEqual(result["unresolvedAssets"][0]["reason"], "extra_female_visual_not_separate_local_form")

    def test_numeric_forms_need_explicit_binding(self):
        result = self.audit([asset("calyrex-1",898)], [target(898,"calyrex-ice","Calyrex",True)])
        self.assertEqual(result["mappedAssets"], [])
        result = self.audit([asset("calyrex-1",898)], [target(898,"calyrex-ice","Calyrex",True)], {"calyrex-1":"calyrex-ice"})
        self.assertEqual(result["mappedAssets"][0]["formKey"], "calyrex-ice")

    def test_id_conflict_requires_exact_reviewed_override(self):
        targets = [target(450,"hippowdon","Hippowdon")]
        bad = self.audit([asset("hippowdown",999)], targets, {"hippowdown":"hippowdon"})
        self.assertEqual(bad["mappedAssets"], [])
        aliases = {"hippowdown":dict(formKey="hippowdon",sourceSpeciesId=999,note="reviewed")}
        good = self.audit([asset("hippowdown",999)], targets, aliases)
        self.assertTrue(good["mappedAssets"][0]["sourceIdCorrected"])
        changed = self.audit([asset("hippowdown",998)], targets, aliases)
        self.assertEqual(changed["mappedAssets"], [])

    def test_shared_visual_retains_both_identities_and_provenance(self):
        targets = [target(849,"toxtricity-amped-gmax","Toxtricity",True),target(849,"toxtricity-low-key-gmax","Toxtricity",True)]
        aliases = {"toxtricity-gigantamax":dict(formKeys=[t["formKey"] for t in targets],note="same appearance")}
        result = self.audit([asset("toxtricity-gigantamax",849)], targets, aliases)
        self.assertEqual(result["summary"]["alternateForms"]["normal"],2)
        self.assertEqual(len({r["url"] for r in result["mappedAssets"]}),1)
        self.assertTrue(all(r["sharedVisual"] for r in result["mappedAssets"]))

    def test_indexed_or_failed_urls_never_count_as_verified(self):
        assets = [asset("pikachu",25),asset("pikachu",25,True)]
        inventory = dict(assets=assets,pages=[])
        result = self.audit(assets,[target(25,"pikachu","Pikachu")])
        attach_verification(result,inventory,{assets[0]["url"]:dict(gifHeaderValid=True),assets[1]["url"]:dict(gifHeaderValid=False,error="timeout")})
        self.assertEqual(result["summary"]["speciesDefaults"]["both"],1)
        self.assertEqual(result["verifiedSummary"]["speciesDefaults"]["both"],0)
        self.assertEqual(result["verification"]["failedUrls"],[assets[1]["url"]])
        with tempfile.TemporaryDirectory() as temp:
            export_audit(result,Path(temp))
            self.assertIn("indexed_unverified",(Path(temp)/"hd-companion-coverage.csv").read_text(encoding="utf-8-sig"))

    def test_real_baseline_and_aliases_have_valid_unique_identities(self):
        targets, _ = baseline()
        self.assertEqual(len(targets), len({t["formKey"] for t in targets}))
        forms = {t["formKey"] for t in targets}
        aliases = json.loads((ROOT/"data/dex/hd_companion_source_aliases.json").read_text(encoding="utf-8"))
        for raw, value in aliases.items():
            keys = value.get("formKeys", [value.get("formKey")]) if isinstance(value,dict) else [value]
            for key in keys:
                self.assertIn(key, forms, msg=raw)


if __name__ == "__main__":
    unittest.main()
