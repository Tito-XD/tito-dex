# Reviewed save fixtures

Public fixtures must be explicitly approved and stripped of unintended personal
data before they are committed. Add the app copy under `flutter/assets/fixtures/`
and register expected metadata in `save_fixture_manifest.json`; the parameterized
Flutter test will then validate every fixture through the production parser.

Retail saves and recognized emulator containers such as DeSmuME `.dsv` are
accepted. Zip archives should be unpacked before import. Do not infer support
from file size alone: each newly claimed game/version needs a reviewed fixture.
