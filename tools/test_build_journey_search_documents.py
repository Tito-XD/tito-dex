import json
import tempfile
import unittest
from pathlib import Path

from tools.build_journey_search_documents import build_documents


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data/journey/progression_hints.json"


class JourneySearchDocumentsTest(unittest.TestCase):
    def test_builds_one_audited_document_per_game_and_location(self):
        source = json.loads(SOURCE.read_text(encoding="utf-8"))
        expected = sum(
            len(entry["games"]) * len(entry["locations"])
            for entry in source["entries"]
        )
        allowed_ids = {entry["id"] for entry in source["entries"]}

        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "search"
            plan = build_documents(SOURCE, output)

            self.assertEqual(len(plan["entries"]), expected)
            self.assertEqual(plan["r2Bucket"], "titodex-journey-content")
            self.assertEqual(plan["aiSearchIncludePrefix"], "journey-search/")
            self.assertEqual(
                [field["name"] for field in plan["customMetadataFields"]],
                ["hint_id", "audited", "game", "generation", "location_id"],
            )
            self.assertEqual(len(plan["customMetadataFields"]), 5)
            self.assertEqual(
                json.loads((output / "search-upload-plan.json").read_text()),
                plan,
            )
            object_keys = set()
            for item in plan["entries"]:
                metadata = item["customMetadata"]
                self.assertEqual(
                    set(metadata),
                    {"hint_id", "audited", "game", "generation", "location_id"},
                )
                self.assertIn(metadata["hint_id"], allowed_ids)
                self.assertEqual(metadata["audited"], "true")
                self.assertIn(metadata["generation"], {"4", "5", "6", "7", "8", "9"})
                self.assertTrue(metadata["location_id"])
                self.assertNotIn(item["objectKey"], object_keys)
                object_keys.add(item["objectKey"])
                document = (output / item["sourcePath"]).read_text()
                self.assertIn(metadata["hint_id"], document)
                self.assertIn(metadata["game"], document)

    def test_rejects_unknown_schema(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "bad.json"
            source.write_text('{"schemaVersion": 2, "entries": []}')
            with self.assertRaises(ValueError):
                build_documents(source, root / "out")


if __name__ == "__main__":
    unittest.main()
