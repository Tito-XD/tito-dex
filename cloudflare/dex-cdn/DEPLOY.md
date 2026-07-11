# TitoDex Dex CDN — Workers 自动部署

用 **Cloudflare Workers Builds** 连接 GitHub，推送指定分支后自动 `wrangler deploy`。

## 部署分支（重要）

| 项 | 值 |
| --- | --- |
| **生产部署分支** | `deploy/dex-cdn` |
| **Worker 根目录** | `cloudflare/dex-cdn` |
| **Worker 名称** | `tito-dex`（与 Dashboard 项目名一致） |

只把 **Worker / CDN 相关改动** 合进 `deploy/dex-cdn`，避免 Flutter App 每次 push 都触发 Worker 重部署。

日常流程：

```bash
# 在 feature 分支改完 cloudflare/dex-cdn/ 或 tools/build_dex_bundle.py 后：
git checkout deploy/dex-cdn
git merge main   # 或 cherry-pick 具体 commit
git push origin deploy/dex-cdn   # → Cloudflare 自动 deploy
```

---

## Cloudflare Dashboard 一次性配置

### 1. 开通 R2

Dashboard → **R2** → 启用并创建 bucket：`titodex-dex`

（图鉴静态文件用 `tools/build_dex_bundle.py` + `tools/upload_dex_bundle.sh` 上传，与 Worker 部署分开。）

### 2. 创建 Worker 并连接 Git

1. [Workers & Pages](https://dash.cloudflare.com/?to=/:account/workers-and-pages) → **Create**
2. 选 **Connect to Git** → 授权 **Tito-XD/tito-dex**
3. 配置如下：

| 设置项 | 填写 |
| --- | --- |
| **Project name** | `tito-dex` |
| **Production branch** | `deploy/dex-cdn` |
| **Root directory** | `cloudflare/dex-cdn` |
| **Build command** | *(留空)* 或 `npm run build`（package.json 已含 no-op build） |
| **Deploy command** | `npx wrangler deploy` |

4. **Save and Deploy**

### 3. 绑定 R2

部署成功后 → Worker → **Settings** → **Bindings**：

- 确认已有 R2 binding：`DEX_BUCKET` → `titodex-dex`
- 若缺失，添加 R2 bucket binding，名称必须为 **`DEX_BUCKET`**（与 `wrangler.toml` 一致）

### 4. 自定义域名 `dex.tito.cafe`

专用图鉴 CDN 子域名。**推荐**，App 与离线包 URL 均使用该域名。

详细步骤：**[DOMAIN.md](./DOMAIN.md)**

简要：

1. Worker → **Settings** → **Domains & Routes** → Add custom domain → `dex.tito.cafe`
2. 确认 `tito.cafe` zone 在本 CF 账号（DNS 通常自动创建）
3. 在 **tito.cafe** zone 配置 Cache Rules（见 DOMAIN.md）

`wrangler.toml` 已含 `dex.tito.cafe/*` 路由；push `deploy/dex-cdn` 后会同步。

### 5. Cache Rules（Dashboard）

在域名 zone 下添加 Cache Rules（见 [`docs/CLOUDFLARE_DEX_CDN.md`](../../docs/CLOUDFLARE_DEX_CDN.md)）：

- `/v2/sprites/*`、`/v2/artwork/*`、`/v2/type_icons/*`、`/v2/details/*` → 1 年 immutable
- `/bundle-manifest.json` → 5 分钟

Worker 已注入 CORS；若直接用 R2 公开域名，需在 R2 设置 CORS。

---

## 图鉴包构建与上传

与 Worker 部署 **分开**进行：

```bash
pip install -r tools/dex_bundle_requirements.txt

# 当前生产 v4（493 物种 → R2 /v2/）
python3 tools/build_dex_bundle.py --cdn-base https://dex.tito.cafe --output dist/dex-v4 --max-id 493

# v0.3.0 bundle v5（1025 物种 → R2 /v3/）
python3 tools/build_dex_bundle.py --cdn-base https://dex.tito.cafe --output dist/dex-v5 --max-id 1025

python3 tools/upload_dex_via_worker.py dist/dex-v5/upload   # 需临时 bootstrap 路由，或 wrangler / CI
```

上传目录结构：

| 本地路径 | R2 前缀 | 说明 |
| --- | --- | --- |
| `upload/v2/` | `v2/` | bundle **v4**，493 物种（v0.2.28 生产） |
| `upload/v3/` | `v3/` | bundle **v5**，1025 物种（v0.3.0） |
| `upload/bundle-manifest.json` | 根 | 指向当前 `archiveUrl` |

Bundle v5 相对 v4 新增：`abilities.json`，summary 内 `pokedexNumbers`，detail 内 `abilities` / `obtainLocations` / 多版本 `moveSets`。

详见 [`docs/CLOUDFLARE_DEX_CDN.md`](../../docs/CLOUDFLARE_DEX_CDN.md)。

---

## 本地验证（可选）

```bash
cd cloudflare/dex-cdn
npm ci
npx wrangler deploy --dry-run
```

---

## 预览构建

推送到 **非** `deploy/dex-cdn` 的分支时，Workers Builds 默认跑 preview（`wrangler versions upload`），不会覆盖生产。

---

## 交给 App 的三个值

Worker + R2 资源就绪后：

```bash
TITODEX_DEX_CDN_BASE=https://dex.tito.cafe
# v0.2.28 生产：
TITODEX_DEX_BUNDLE_URL=https://dex.tito.cafe/v2/bundle.tar.zst
TITODEX_DEX_BUNDLE_VERSION=4
# v0.3.0 计划：
# TITODEX_DEX_BUNDLE_URL=https://dex.tito.cafe/v3/bundle.tar.zst
# TITODEX_DEX_BUNDLE_VERSION=5
```

当前生产 bundle SHA256 见 GitHub Release [v0.2.24/v0.2.25/v0.2.28](https://github.com/Tito-XD/tito-dex/releases) 或 live `bundle-manifest.json`。

---

## 相关文件

| 文件 | 作用 |
| --- | --- |
| `wrangler.toml` | Worker 名、R2 binding、路由 |
| `package.json` | Wrangler 版本、`npm run deploy` |
| `src/worker.js` | R2 代理 + CORS + `/bundle/latest` |
| `../../docs/CLOUDFLARE_DEX_CDN.md` | R2 目录结构、图鉴包构建 |
