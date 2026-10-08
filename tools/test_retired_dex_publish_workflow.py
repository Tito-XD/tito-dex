#!/usr/bin/env python3
"""Prevent the retired v19 production publisher from becoming dispatchable again."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RetiredDexPublishWorkflowTests(unittest.TestCase):
    def test_v19_workflow_is_not_an_active_actions_entrypoint(self):
        self.assertFalse((ROOT / ".github/workflows/upload-dex-bundle.yml").exists())

    def test_no_workflow_invokes_the_v19_builder(self):
        for path in (ROOT / ".github/workflows").glob("*"):
            if path.suffix in {".yml", ".yaml"}:
                with self.subTest(workflow=path.name):
                    self.assertNotIn("patch_dex_bundle_v19_items.py", path.read_text())


if __name__ == "__main__":
    unittest.main()
