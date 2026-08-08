import unittest

from build_item_version_matrix import parse_item_page, parse_price, split_template


class ItemVersionMatrixTest(unittest.TestCase):
    def test_nested_templates_do_not_split_description(self) -> None:
        parts = split_template(
            "{{包包信息框|7|SMUSUM|伤药|回复|"
            "-{zh-hans:回复{{tt|20|二十}}ＨＰ;zh-hant:回復２０ＨＰ;}-|200|100}}"
        )
        self.assertEqual(parts[-2:], ["200", "100"])

    def test_availability_and_version_prices_are_separate(self) -> None:
        parsed = parse_item_page(
            "{{道具信息框/game|RGBY=y|GSC=y|SV=y}}\n"
            "{{包包信息框|1|RGBY|伤药|道具|说明|300|150}}\n"
            "{{包包信息框|9|SV|伤药|回复|说明|200|50}}"
        )
        self.assertEqual(
            parsed["versionGroups"],
            ["crystal", "gold-silver", "red-blue", "scarlet-violet", "yellow"],
        )
        self.assertEqual(parsed["prices"]["red-blue"], {"buy": 300, "sell": 150})
        self.assertEqual(parsed["prices"]["scarlet-violet"], {"buy": 200, "sell": 50})

    def test_non_money_currency_is_preserved(self) -> None:
        parsed = parse_item_page(
            "{{包包信息框|8|SWSH|道具|宝物|说明|20ＢＰ|10ＢＰ}}"
        )
        self.assertEqual(parsed["prices"]["sword-shield"]["buy"], "20ＢＰ")

    def test_annotated_prices_do_not_leak_wiki_markup(self) -> None:
        self.assertEqual(parse_price("200／{{tt|25000|道具狂}}"), 200)
        self.assertEqual(
            parse_price("{{tt|3500|地下通道}}"), "3500（地下通道）"
        )
        self.assertEqual(parse_price("7000{{sup/7|MUM}}"), "7000（MUM）")

    def test_exact_version_exclusive_items_are_preserved(self) -> None:
        parsed = parse_item_page(
            "{{道具信息框/game|HG=y|SS=n|B=y|W2=y|S=y|V=n}}"
        )
        self.assertEqual(parsed["versions"], ["black", "heartgold", "scarlet", "white-2"])
        self.assertIn("heartgold-soulsilver", parsed["versionGroups"])
        self.assertIn("scarlet-violet", parsed["versionGroups"])


if __name__ == "__main__":
    unittest.main()
