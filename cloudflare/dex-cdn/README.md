# TitoDex Dex CDN — Cloudflare Worker

Proxy R2 bucket `titodex-dex` at **`https://dex.tito.cafe`** with CORS + cache headers.

**Worker name:** `tito-dex` · **Live bundle:** v20 on `/v5/` · **Health:** `/cdn-health`

## Existing Git auto-deploy configuration

Connect this repo in **Cloudflare Workers Builds**:

| Setting | Value |
| --- | --- |
| Production branch | **`deploy/dex-cdn`** |
| Root directory | `cloudflare/dex-cdn` |
| Deploy command | `npx wrangler deploy` |

The main-history cleanup did not migrate this legacy deployment branch. Do not merge its old history into main or bypass attribution hooks. Until an explicit branch migration, deploy verified current main via the CLI below. See **[DEPLOY.md](./DEPLOY.md)**.

## Manual deploy

```bash
cd cloudflare/dex-cdn
npm ci
npx wrangler deploy --dry-run
# After deployment authorization and target/configuration checks:
npx wrangler deploy
```

## Docs

- [DEPLOY.md](./DEPLOY.md) — Dashboard / Git integration
- [CLOUDFLARE_DEX_CDN.md](../../docs/CLOUDFLARE_DEX_CDN.md) — R2 layout + bundle build
