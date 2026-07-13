# Repository Secrets (GitHub Actions)

TitoDex CI workflows upload to Cloudflare R2 via **Wrangler 4** (`wrangler r2 object put --remote`).

| Secret | Purpose |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Account API token with **Workers R2 Storage → Edit** (see below) |
| `CLOUDFLARE_ACCOUNT_ID` | Account ID shown in Workers dashboard (must match the token’s account) |

## Cloudflare API token — required permissions

Wrangler calls the **Account R2 API** (`/accounts/{id}/r2/buckets/.../objects/...`).

**Not sufficient alone:** only *Workers R2 Storage Bucket Item Write* on a bucket (common misconfiguration — local `--remote` will 403 with `Authentication error`).

### Recommended: Custom token

Cloudflare Dashboard → **My Profile** → **API Tokens** → **Create Token** → **Create Custom Token**

| Field | Value |
| --- | --- |
| **Permissions** | Account → **Workers R2 Storage** → **Edit** |
| **Account resources** | Include → your account |
| **R2 resources** *(if shown)* | Include → bucket **`titodex-dex`** only |

Optional (read-only sanity check): add **Workers R2 Storage → Read** on the same bucket.

**Do not need for GH Actions l10n sync:** Workers Scripts Edit (Worker deploy uses Dashboard Git, not this token).

### Verify token locally (before saving to GitHub)

```bash
export CLOUDFLARE_API_TOKEN="..."
export CLOUDFLARE_ACCOUNT_ID="..."
cd cloudflare/dex-cdn
npx wrangler r2 bucket list
# Should list titodex-dex — not 403
echo test | npx wrangler r2 object put titodex-dex/_healthcheck.txt --file=- --remote
npx wrangler r2 object delete titodex-dex/_healthcheck.txt --remote
```

`r2 bucket list` always hits the remote API (no `--remote` flag). Only `r2 object put/delete` need `--remote` in Wrangler 4 to avoid local mode.

If `bucket list` returns **403 Authentication error**, the token lacks **Workers R2 Storage Edit** (or wrong account ID).

### Pre-built template (alternative)

Use template **「Edit Cloudflare Workers」** only if it includes **R2 Edit**; otherwise prefer the custom token above.

---

## GitHub repository secrets

**Settings → Secrets and variables → Actions → Repository secrets**

| Name | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Token string from above |
| `CLOUDFLARE_ACCOUNT_ID` | Account ID (32 hex chars) |

Use **Repository secrets**, not Environment secrets (workflows do not set `environment:`).

### GitHub workflow write permission (for git commit step)

**Settings → Actions → General → Workflow permissions** → **Read and write permissions**.

Only needed when 52poke actually updates `location_areas.json`. R2 upload does not depend on this.

---

## Workflows

| Workflow | What it uploads |
| --- | --- |
| `sync-l10n-catalog.yml` | `v3/l10n/zh/*`, maps, config, `bundle-manifest.json` |
| `upload-dex-bundle.yml` | Full dex bundle under `v2/` or `v3/` |

Both require **`--remote`** on every `wrangler r2 object put` (Wrangler 4 defaults to local without it).

## Local upload (alternative)

```bash
export CLOUDFLARE_API_TOKEN=...
export CLOUDFLARE_ACCOUNT_ID=...
./tools/upload_dex_bundle.sh dist/dex-v5/upload v3
```

Or: `python3 tools/stage_l10n_upload.py` then upload `dist/l10n-upload/` with Wrangler.
