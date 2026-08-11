import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AttributionMetadataTests(unittest.TestCase):
    def test_retired_license_claims_do_not_return(self) -> None:
        roots = [
            ROOT / "CREDITS.md",
            ROOT / "docs" / "AI_CONTEXT.md",
            ROOT / "flutter" / "lib" / "l10n" / "app_zh.dart",
            ROOT / "tools",
            ROOT / "data" / "l10n" / "zh",
            ROOT / "data" / "dex",
            ROOT / "flutter" / "assets" / "data",
        ]
        retired_claims = (
            "CC BY-NC-SA " + "4.0",
            "CC-BY " + "4.0",
        )
        checked: list[Path] = []
        for root in roots:
            paths = [root] if root.is_file() else root.rglob("*")
            for path in paths:
                if not path.is_file() or path.suffix not in {
                    ".dart",
                    ".json",
                    ".md",
                    ".py",
                }:
                    continue
                checked.append(path)
                text = path.read_text(encoding="utf-8")
                for claim in retired_claims:
                    self.assertNotIn(claim, text, path)
        self.assertGreater(len(checked), 20)

    def test_game_icon_manifest_covers_every_png(self) -> None:
        icon_dir = ROOT / "flutter" / "assets" / "game_icons"
        manifest = json.loads((icon_dir / "SOURCES.json").read_text(encoding="utf-8"))
        documented = set(manifest["flavorAssets"]) | set(manifest["mergedAssets"])
        bundled = {path.name for path in icon_dir.glob("*.png")}
        self.assertEqual(documented, bundled)

        steamgrid = [
            source
            for source in manifest["flavorAssets"].values()
            if source["provider"] == "SteamGridDB community host"
        ]
        self.assertTrue(steamgrid)
        self.assertTrue(all(source.get("sourceKey") for source in steamgrid))
        self.assertTrue(all(source.get("contributor") for source in steamgrid))

        pokeapi = [
            source
            for source in manifest["flavorAssets"].values()
            if source["provider"] == "PokeAPI/sprites"
        ]
        self.assertTrue(pokeapi)
        self.assertTrue(all("/master/" not in source["sourceUrl"] for source in pokeapi))

    def test_52poke_media_is_not_blanket_licensed_as_wiki_text(self) -> None:
        media_files = [
            ROOT / "data" / "dex" / "form_media_audit.json",
            ROOT / "data" / "dex" / "item_media_audit_v19.json",
            ROOT / "data" / "l10n" / "zh" / "item_media_exact_overrides_v19.json",
            ROOT / "data" / "l10n" / "zh" / "item_media_overrides_v19.json",
            ROOT / "data" / "l10n" / "zh" / "media_catalog_52poke.json",
            ROOT / "data" / "l10n" / "zh" / "tm_v19_enrichment.json",
        ]
        for path in media_files:
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("CC BY-NC-SA", text, path)
            self.assertIn("underlying media rights vary", text, path)

    def test_vendored_license_files_exist(self) -> None:
        nunito = ROOT / "flutter" / "assets" / "licenses" / "nunito-OFL.txt"
        pokesprite = ROOT / "flutter" / "assets" / "licenses" / "pokesprite-MIT.txt"
        neroli = (
            ROOT
            / "flutter"
            / "assets"
            / "licenses"
            / "nerolis-lab-Apache-2.0.txt"
        )
        neroli_notice = (
            ROOT / "flutter" / "assets" / "licenses" / "nerolis-lab-NOTICE.txt"
        )
        self.assertIn(
            "SIL OPEN FONT LICENSE Version 1.1",
            nunito.read_text(encoding="utf-8"),
        )
        self.assertIn(
            "The MIT License (MIT)",
            pokesprite.read_text(encoding="utf-8"),
        )
        self.assertIn(
            "Apache License",
            neroli.read_text(encoding="utf-8"),
        )
        self.assertIn(
            "Copyright The Neroli's Lab Authors",
            neroli_notice.read_text(encoding="utf-8"),
        )


if __name__ == "__main__":
    unittest.main()
