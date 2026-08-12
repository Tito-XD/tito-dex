# Repository Secrets (GitHub Actions)

TitoDex CI workflows upload to Cloudflare R2 via **Wrangler 4** (`wrangler r2 object put --remote`).

| Secret | Purpose |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Account API token with **Workers R2 Storage → Edit** (see below) |
| `CLOUDFLARE_ACCOUNT_ID` | Account ID shown in Workers dashboard (must match the token’s account) |
| `R2_ACCESS_KEY_ID` | Optional S3-compatible R2 key used for faster bulk bundle uploads |
| `R2_SECRET_ACCESS_KEY` | Optional S3-compatible R2 secret paired with the access key |
| `ANDROID_SIGNER_SHA256` | Recommended SHA-256 certificate digest used by the release publisher to pin both APKs to the historical Android signer |

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
| `ANDROID_SIGNER_SHA256` | Android release certificate SHA-256 digest as printed by `apksigner verify --print-certs` (recommended for publishing) |

Use **Repository secrets**, not Environment secrets (workflows do not set `environment:`).

### GitHub workflow write permission (for git commit step)

**Settings → Actions → General → Workflow permissions** → **Read and write permissions**.

Only needed when 52poke actually updates `location_areas.json`. R2 upload does not depend on this.

---

## Workflows

| Workflow | 触发方式 | 上传内容 |
| --- | --- | --- |
| `sync-l10n-catalog.yml` | Worker cron（周日）、`repository_dispatch`、手动 | `v5/l10n/zh/*`, maps, config |
| `build-pokeapi-assets.yml` | `repository_dispatch`、手动 | PokeAPI sprites / artwork / animated → R2 |
| `upload-dex-bundle.yml` | 手动、历史复现 | 已完成的 v19 专用流程：以线上 v18 为只读基线；生产已为 v19，**不得再次用于发布** |

已完成使命的一次性发布 workflow 已从工作树移除，避免被误当成当前发布入口；
对应提交、构建脚本与演进过程仍可从 Git 历史和 `tools/` 追溯。下一版本必须新建
带精确生产前置版本的 workflow。

All R2 upload workflows require **`--remote`** on every `wrangler r2 object put` (Wrangler 4 defaults to local without it).

---

## Worker secrets (Cloudflare Dashboard)

These live on the **Worker**, not in GitHub Secrets:

| Secret | Purpose |
| --- | --- |
| `GITHUB_DISPATCH_TOKEN` | Fine-grained PAT: repo `Tito-XD/tito-dex`, **Actions: Read and write** |
| `ADMIN_SECRET` | Bearer token for `https://dex.tito.cafe/admin/*` |
| `TELEGRAM_BOT_TOKEN` | BotFather token for CDN probe / cron failure alerts |
| `TELEGRAM_CHAT_ID` | Telegram chat id to receive alerts |
| `ALERT_WEBHOOK_URL` | Optional Discord/Slack webhook (alternative to Telegram) |

GitHub repository secrets (`CLOUDFLARE_*`) are unchanged — Actions still write R2 directly.

## Local upload (alternative)

```bash
export CLOUDFLARE_API_TOKEN=...
export CLOUDFLARE_ACCOUNT_ID=...
./tools/upload_dex_bundle.sh <verified-candidate-upload-dir> v5
```

该命令只适用于已经通过当前版本审计、且拥有精确生产版本前置检查的未来候选；不要把
历史 `dist/dex-v7` 示例当作当前可发布数据。

Or: download the current production root manifest first, then run
`python3 tools/stage_l10n_upload.py --remote-manifest <manifest> --expected-bundle-version 19`.
The exact expected version is deliberate: change it only together with a verified production
bundle release, never to make a stale-manifest failure pass.
