# TitoDex 网页与 CDN 入口

`titodex-web-entry` 承接现有域名的入口路由：

- `/`、`/app`、`/1025`、`/151`、`/pokedex/*` 及网页资源：请求固定的 `https://titodex.pages.dev`，保留路径和查询参数。
- `/vN`、`/vN/*`、`/bundle-manifest.json`、`/bundle/*`、`/cdn-health`、`/admin/*`：通过 `CDN` service binding 调用原 `tito-dex` Worker。
- CDN 响应直接返回，保留状态码、缓存、ETag、下载和管理接口语义；错误不能回退到网页 HTML。
- Pages 内部重定向保留访问入口的域名；外部链接不修改。Pages 请求不转发浏览器 Cookie 或 Authorization。
- 原 Pages 项目继续独立发布；本入口无需随页面更新重建。网页的 canonical、sitemap 内容仍由 Pages 源项目管理。

原 CDN Worker 的 R2、KV、密钥、定时任务与业务代码保持不变。根路径现在展示网页，客户端继续使用明确的 `/bundle-manifest.json`。

## 验证与发布

```sh
node --test cloudflare/dex-web-entry/test/worker.test.js
npx wrangler@4.107.1 deploy --dry-run --config cloudflare/dex-web-entry/wrangler.jsonc
npx wrangler@4.107.1 deploy --config cloudflare/dex-web-entry/wrangler.jsonc
```

入口配置负责 host-wide route；`../dex-cdn/wrangler.toml` 不再声明该路由。CDN 自动部署分支也必须采用这一配置，避免旧配置重新抢占网页入口。

2026-09-27 首次切换前，先部署无正式 route 的临时配置，验证网页与 CDN 基线，再将原路由的 script 从 `tito-dex` 改为 `titodex-web-entry`。正式验证后关闭临时 workers.dev 入口。

## 回滚

将该域名既有 route 的 script 恢复为 `tito-dex`，即可恢复原 CDN 入口；无需回滚或修改 R2 数据、Pages 部署、DNS 或密钥。回滚后首页也会恢复为旧的数据清单响应。
