# TitoDex Dex CDN — Cloudflare Worker

Proxy R2 bucket `titodex-dex` with CORS + cache headers.

Full setup guide: [`docs/CLOUDFLARE_DEX_CDN.md`](../../docs/CLOUDFLARE_DEX_CDN.md)

## Prerequisites

- Cloudflare account with R2 enabled
- Bucket `titodex-dex` created and populated (`tools/build_dex_bundle.py` + `tools/upload_dex_bundle.sh`)
- Wrangler CLI: `npm i -g wrangler`

## Configure

1. Copy and edit `wrangler.toml` — set `account_id` and custom route domain.
2. Authenticate: `wrangler login`

## Deploy

```bash
cd cloudflare/dex-cdn
wrangler deploy
```

## Bindings

| Binding | Type | Purpose |
| --- | --- | --- |
| `DEX_BUCKET` | R2 | `titodex-dex` objects |

## Routes

| Path | Behavior |
| --- | --- |
| `/bundle/latest` | 302 → `archiveUrl` from root `bundle-manifest.json` |
| `/*` | R2 GET with CORS |

## Alternative: R2 public bucket

If you enable R2 public access + custom domain without Worker, configure CORS and Cache Rules in the Cloudflare dashboard per `docs/CLOUDFLARE_DEX_CDN.md`.
