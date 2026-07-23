#!/usr/bin/env python3
"""Bundle v6 test entrypoint (keeps the historical v5 module importable)."""

from __future__ import annotations

import unittest

from test_dex_bundle_v5 import DexBundleV5ValidationTests as _V5Suite


class DexBundleV6ValidationTests(_V5Suite):
    """Run the complete bundle schema suite against the active v6 constants."""

del _V5Suite


if __name__ == "__main__":
    unittest.main()
