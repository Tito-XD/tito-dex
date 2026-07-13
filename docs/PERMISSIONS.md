# Repository Secrets (GitHub Actions)

TitoDex CI workflows that upload to Cloudflare R2 require these repository secrets:

| Secret | Purpose |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | R2 Object Write (and Workers deploy if used). Create in Cloudflare Dashboard → My Profile → API Tokens with **R2 Edit** (or custom token scoped to bucket `titodex-dex`). |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account ID (Dashboard → Workers & Pages → right sidebar). Used by Wrangler for R2 uploads. |

## Workflows that use these secrets

- `.github/workflows/upload-dex-bundle.yml` — full dex bundle upload
- `.github/workflows/sync-l10n-catalog.yml` — weekly incremental l10n / maps / config sync

Without these secrets, workflows can still run fetch/generate steps but R2 upload will fail.

## Local upload (alternative)

```bash
export CLOUDFLARE_API_TOKEN=...
export CLOUDFLARE_ACCOUNT_ID=...
./tools/upload_dex_bundle.sh dist/dex-v5/upload
```

Or run `python3 tools/stage_l10n_upload.py` then upload `dist/l10n-upload/` manually with Wrangler.
