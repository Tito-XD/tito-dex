#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from build_journey_data_packs import ROOT, build_packs
from verify_journey_data_packs import verify_candidate_dir


class JourneyDataPackBuilderTest(unittest.TestCase):
    def test_builds_complete_immutable_catalog(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            catalog = build_packs(ROOT / "data/journey/progression_hints.json", output)
            source = json.loads((ROOT / "data/journey/progression_hints.json").read_text(encoding="utf-8"))
            self.assertEqual(sum(item["entryCount"] for item in catalog["packs"]), len(source["entries"]))
            for descriptor in catalog["packs"]:
                relative = descriptor["contentPath"].removeprefix("/v1/journey-packs/")
                body = (output / relative).read_bytes()
                self.assertEqual(len(body), descriptor["sizeBytes"])
                self.assertEqual(hashlib.sha256(body).hexdigest(), descriptor["sha256"])
                pack = json.loads(body)
                self.assertEqual(pack["id"], descriptor["id"])
                self.assertEqual(pack["gameFamily"], descriptor["gameFamily"])
                self.assertEqual(pack["version"], descriptor["version"])
                self.assertEqual(len(pack["entries"]), descriptor["entryCount"])
                expected_date = max(
                    source_row["accessedAt"]
                    for entry in pack["entries"]
                    for source_row in entry["sources"]
                )
                self.assertEqual(pack["sourceAsOf"], expected_date)
            plan = json.loads((output / "journey-pack-upload-plan.json").read_text(encoding="utf-8"))
            self.assertTrue(plan["catalog"]["uploadLast"])
            self.assertEqual(plan["bucket"], "titodex-journey-content")
            verified = verify_candidate_dir(output)
            self.assertEqual(verified["entryCount"], len(source["entries"]))

    def test_output_is_byte_stable(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            source = ROOT / "data/journey/progression_hints.json"
            build_packs(source, Path(first))
            build_packs(source, Path(second))
            first_files = {path.relative_to(first): path.read_bytes() for path in Path(first).rglob("*") if path.is_file()}
            second_files = {path.relative_to(second): path.read_bytes() for path in Path(second).rglob("*") if path.is_file()}
            self.assertEqual(first_files, second_files)

    def test_verifier_rejects_mutated_immutable_object(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            catalog = build_packs(ROOT / "data/journey/progression_hints.json", output)
            first = catalog["packs"][0]
            relative = first["contentPath"].removeprefix("/v1/journey-packs/")
            (output / relative).write_bytes(b"{}\n")
            with self.assertRaisesRegex(ValueError, "size mismatch"):
                verify_candidate_dir(output)

    def test_verifier_binds_candidate_to_reviewed_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "candidate"
            build_packs(ROOT / "data/journey/progression_hints.json", output)
            source = json.loads(
                (ROOT / "data/journey/progression_hints.json").read_text(
                    encoding="utf-8"
                )
            )
            source["entries"][0]["overviewZh"] = "未经审核的改写"
            altered = Path(temporary) / "altered.json"
            altered.write_text(
                json.dumps(source, ensure_ascii=False),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "canonical reviewed source"):
                verify_candidate_dir(output, canonical_source=altered)


if __name__ == "__main__":
    unittest.main()
