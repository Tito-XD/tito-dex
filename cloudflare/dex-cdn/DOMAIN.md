# dex.tito.cafe — 自定义域名配置

TitoDex 离线图鉴 CDN 专用子域名。

## 要不要用自定义域名？

| 方案 | 说明 |
| --- | --- |
| **`dex.tito.cafe`（推荐）** | 稳定、好记；图鉴包里的 `spriteUrl` 可写死；掌机 App 配置简单 |
| `*.workers.dev` | 免 DNS，但 URL 长、不适合写进离线 bundle |
| R2 公开域名 | 需单独配 CORS，无 `/bundle/latest` Worker 逻辑 |

**结论：生产环境用 `dex.tito.cafe`。**

---

## 前提

- 域名 **`tito.cafe`** 已在 **同一 Cloudflare 账号** 下（DNS / Zone 已接入）
- R2 已开通，bucket **`titodex-dex`** 已创建
- Worker **`titodex-dex-cdn`** 已通过 Workers Builds 部署（分支 `deploy/dex-cdn`）

---

## 方式 A：Dashboard 添加（最简单）

Worker 首次部署完成后：

1. [Workers & Pages](https://dash.cloudflare.com/?to=/:account/workers-and-pages) → 打开 **`titodex-dex-cdn`**
2. **Settings** → **Domains & Routes** → **Add** → **Custom domain**
3. 输入：`dex.tito.cafe` → **Add domain**

若 `tito.cafe` 在本账号，Cloudflare 通常会 **自动添加 DNS**（类型多为 Worker 路由记录，无需手填 CNAME）。

4. 等状态变为 **Active**（通常 1–5 分钟）

验证：

```bash
curl -I https://dex.tito.cafe/bundle-manifest.json
```

---

## 方式 B：仓库 `wrangler.toml`（已配置，随 Git 部署）

`cloudflare/dex-cdn/wrangler.toml` 已包含：

```toml
[[routes]]
pattern = "dex.tito.cafe/*"
zone_name = "tito.cafe"
```

推送到 **`deploy/dex-cdn`** 后，Workers Builds 会自动带上该路由。

若 Dashboard 里已手动加过同名域名，不要重复冲突；二选一即可（推荐 **A 先行**，之后靠 Git 保持一致）。

---

## 若 DNS 未自动创建（手动）

Cloudflare Dashboard → **tito.cafe** → **DNS** → **Add record**：

| 类型 | 名称 | 内容 | 代理 |
| --- | --- | --- | --- |
| 通常 **不用手加** | `dex` | （由 Custom domain 向导创建） | 已代理 🟠 |

只有在 Custom domain 页面提示缺少记录时，按向导给出的类型/目标填写。

**不要** 把 `dex` 指到 R2 公开 bucket URL；流量应走 **Worker**（才能 CORS + `/bundle/latest`）。

---

## Cache Rules（tito.cafe Zone）

**Rules** → **Cache Rules** → 新建（顺序在 Page Rules 之后即可）：

| 匹配 | Cache-Control |
| --- | --- |
| URI Path starts with `/v2/sprites/` | `public, max-age=31536000, immutable` |
| URI Path starts with `/v2/type_icons/` | 同上 |
| URI Path starts with `/v2/details/` | 同上 |
| URI Path equals `/v2/bundle.tar.zst` | 同上 |
| Host equals `dex.tito.cafe` AND URI Path equals `/bundle-manifest.json` | `public, max-age=300` |

Worker 已返回 CORS 头；Cache Rules 只影响 CDN 边缘缓存。

---

## 构建图鉴包时使用该域名

```bash
python3 tools/build_dex_bundle.py \
  --cdn-base https://dex.tito.cafe \
  --output dist/dex-v2
```

`summaries.json` 里的 `spriteUrl` 会写成 `https://dex.tito.cafe/v2/sprites/{id}.jpg`。

---

## 交给 App 的三个值（定稿）

```bash
TITODEX_DEX_CDN_BASE=https://dex.tito.cafe
TITODEX_DEX_BUNDLE_URL=https://dex.tito.cafe/v2/bundle.tar.zst
TITODEX_DEX_BUNDLE_VERSION=2
```

---

## 抽测清单

部署 + 上传 R2 后：

```bash
curl -I https://dex.tito.cafe/bundle-manifest.json
curl -I https://dex.tito.cafe/v2/sprites/25.jpg
curl -I https://dex.tito.cafe/v2/sprites/155.jpg
curl -I https://dex.tito.cafe/bundle/latest    # 应 302 到 bundle.tar.zst
```

浏览器或 App 需能收到：

```
Access-Control-Allow-Origin: *
```

---

## 常见问题

**Q: 一定要子域名吗，能用 `tito.cafe/dex` 吗？**  
可以，但 Worker 路由和 Cache Rules 要改成路径前缀，离线包 URL 也要改。子域名 **`dex.tito.cafe`** 更干净，已按此配置。

**Q: SSL 证书？**  
Cloudflare 对 `*.tito.cafe` / 子域自动签发，Custom domain Active 后即可 HTTPS。

**Q: 和主站冲突吗？**  
不会。只有 `dex.tito.cafe` 指向 Worker；`tito.cafe` / `www` 不受影响。
