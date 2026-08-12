import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.build_journey_extension_release import stage_release


class JourneyExtensionReleaseTest(unittest.TestCase):
    def test_stages_digest_named_apk_and_relative_catalog(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "source.apk"
            apk.write_bytes(b"signed-apk-fixture")
            output = root / "upload"

            catalog = stage_release(
                apk,
                output,
                version_name="1.0.0",
                version_code=1,
                min_host_version="0.8.12",
            )

            digest = hashlib.sha256(apk.read_bytes()).hexdigest()
            entry = catalog["entries"][0]
            self.assertEqual(entry["sha256"], digest)
            self.assertEqual(entry["packageId"], "com.tito.titodex.extension.journeyassistant")
            self.assertFalse(entry["downloadPath"].startswith("/"))
            staged = output / entry["downloadPath"]
            self.assertEqual(staged.read_bytes(), apk.read_bytes())
            self.assertEqual(
                json.loads((output / "extension-catalog.json").read_text()),
                catalog,
            )

    def test_rejects_missing_or_empty_apk(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaises(ValueError):
                stage_release(
                    root / "missing.apk",
                    root / "out",
                    version_name="1.0.0",
                    version_code=1,
                    min_host_version="0.8.12",
                )
            empty = root / "empty.apk"
            empty.write_bytes(b"")
            with self.assertRaises(ValueError):
                stage_release(
                    empty,
                    root / "out",
                    version_name="1.0.0",
                    version_code=1,
                    min_host_version="0.8.12",
                )

    def test_rejects_version_path_injection(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "source.apk"
            apk.write_bytes(b"signed-apk-fixture")
            with self.assertRaises(ValueError):
                stage_release(
                    apk,
                    root / "out",
                    version_name="../outside",
                    version_code=1,
                    min_host_version="0.8.12",
                )


if __name__ == "__main__":
    unittest.main()
