import argparse
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from patch_dex_bundle_v14_compact_media import (
    ARCHIVE_NAME,
    LIVE_ARCHIVE,
    V14_ARCHIVE,
    build,
    create_zst_tar,
    extract_archive,
    verify_and_remove_duplicate_artwork,
)


class CompactMediaTest(unittest.TestCase):
    def _write_pair(self, root: Path, relative: str, content: bytes = b"png") -> None:
        for directory in ("artwork", "sprites"):
            path = root / directory / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)

    def test_removes_only_fully_verified_duplicate_artwork(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write_pair(root, "1.png", b"species")
            self._write_pair(root, "forms/10001.png", b"form")

            stats = verify_and_remove_duplicate_artwork(root)

            self.assertEqual(stats.files, 2)
            self.assertEqual(stats.bytes_removed, len(b"species") + len(b"form"))
            self.assertFalse((root / "artwork").exists())
            self.assertEqual((root / "sprites/1.png").read_bytes(), b"species")
            self.assertEqual(
                (root / "sprites/forms/10001.png").read_bytes(), b"form"
            )

    def test_refuses_mismatched_artwork(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write_pair(root, "1.png", b"same-size")
            (root / "sprites/1.png").write_bytes(b"different")

            with self.assertRaisesRegex(ValueError, "failed validation"):
                verify_and_remove_duplicate_artwork(root)

            self.assertTrue((root / "artwork/1.png").is_file())

    def test_builds_v14_archive_without_artwork(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            base = root / "base"
            base.mkdir()
            self._write_pair(base, "1.png", b"species")
            (base / "manifest.json").write_text(
                json.dumps({"version": 13, "complete": True}), encoding="utf-8"
            )
            base_archive = root / "base-v13.tar.zst"
            create_zst_tar(base, base_archive)
            root_manifest = root / "bundle-manifest-v13.json"
            root_manifest.write_text(
                json.dumps(
                    {
                        "bundleVersion": 13,
                        "cdnPrefix": "v5",
                        "complete": True,
                        "pokemonCount": 1025,
                        "archiveUrl": LIVE_ARCHIVE,
                    }
                ),
                encoding="utf-8",
            )

            output = root / "output"
            build(
                argparse.Namespace(
                    output=output,
                    base_archive=base_archive,
                    base_root_manifest=root_manifest,
                    force_download=False,
                )
            )

            built_manifest = json.loads(
                (output / "upload/bundle-manifest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(built_manifest["bundleVersion"], 14)
            self.assertTrue(built_manifest["compactMedia"])
            self.assertEqual(built_manifest["archiveUrl"], V14_ARCHIVE)
            extracted = root / "extracted"
            extract_archive(output / "upload/v5" / ARCHIVE_NAME, extracted)
            self.assertFalse((extracted / "artwork").exists())
            self.assertEqual((extracted / "sprites/1.png").read_bytes(), b"species")
            archive_manifest = json.loads(
                (extracted / "manifest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(archive_manifest["version"], 14)
            self.assertEqual(archive_manifest["artworkFileCount"], 0)


if __name__ == "__main__":
    unittest.main()
