# Historical one-shot workflows

These workflows produced the already-published Dex bundle v12 and v13 cuts.
They are kept as release records, but no longer appear in GitHub Actions:

- `upload-dex-bundle-v12.yml` expects the live root manifest to still be v11.
- `upload-dex-bundle-v13.yml` expects the live root manifest to still be v12.

The production root manifest is newer than both preconditions. Reproduction
uses the versioned scripts under `tools/`; a future bundle release should add a
new workflow with an explicit current-version precondition.
