# Repository Secrets (GitHub Actions)

TitoDex CI workflows that upload to Cloudflare R2 require these repository secrets:

| Secret | Purpose |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | R2 Object Write (and Workers deploy if used). Create in Cloudflare Dashboard → My Profile → API Tokens with **R2 Edit** (or custom token scoped to bucket `titodex-dex`). |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID (Dashboard → Workers & Pages → right sidebar). Used by Wrangler for R2 uploads. |

## Workflows that use these secrets

- `.github/workflows/upload-dex-bundle.yml` — full dex bundle upload
- `.github/workflows/sync-l10n-catalog.yml` — weekly incremental l10n / maps / config sync

### GitHub repo settings (required for l10n sync commits)

**Settings → Actions → General → Workflow permissions** → select **Read and write permissions**.

The sync workflow sets `permissions: contents: write` and pushes catalog updates when `location_areas.json` changes.

Without write permission, R2 upload can succeed but git push will fail with `403`.

### Wrangler R2 upload

Use **`wrangler r2 object put --remote`** (Wrangler 4 defaults to local storage without this flag).

## Local upload (alternative)

```bash
export CLOUDFLARE_API_TOKEN=...
export CLOUDFLARE_ACCOUNT_ID=...
./tools/upload_dex_bundle.sh dist/dex-v5/upload
```

Or run `python3 tools/stage_l10n_upload.py` then upload `dist/l10n-upload/` manually with Wrangler.
