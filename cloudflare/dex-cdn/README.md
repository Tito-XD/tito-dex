# TitoDex Dex CDN — Cloudflare Worker

Proxy R2 bucket `titodex-dex` at **`https://dex.tito.cafe`** with CORS + cache headers.

**Worker name:** `tito-dex` · **Bundle version:** 4 (PNG) · **Health:** `/cdn-health`

## Auto-deploy (recommended)

Connect this repo in **Cloudflare Workers Builds**:

| Setting | Value |
| --- | --- |
| Production branch | **`deploy/dex-cdn`** |
| Root directory | `cloudflare/dex-cdn` |
| Deploy command | `npx wrangler deploy` |

Step-by-step: **[DEPLOY.md](./DEPLOY.md)**

## Manual deploy

```bash
cd cloudflare/dex-cdn
npm ci
npx wrangler deploy
```

## Docs

- [DEPLOY.md](./DEPLOY.md) — Dashboard / Git integration
- [CLOUDFLARE_DEX_CDN.md](../../docs/CLOUDFLARE_DEX_CDN.md) — R2 layout + bundle build
