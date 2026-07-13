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

### 6. KV（可选，manifest 热缓存）

Dashboard → **Workers KV** → Create namespace → 名称建议 `titodex-dex-kv`

Worker → **Settings** → **Bindings** → KV namespace → `MANIFEST_KV`

或在 `wrangler.toml` 取消注释 `[[kv_namespaces]]` 并填入 `id`。

未绑定 KV 时 Worker 仍正常工作，只是 `bundle-manifest.json` 不走边缘 KV 缓存。

### 7. Cron 与 Secrets（调度 + 管理面）

`wrangler.toml` 已配置两条 cron：

| Cron | 时间 (UTC) | 动作 |
| --- | --- | --- |
| `0 4 * * 0` | 每周日 04:00 | `repository_dispatch` → **Sync l10n Catalog** |
| `0 */6 * * *` | 每 6 小时 | 深度 R2 探活，失败时可选 webhook 告警 |

Worker → **Settings** → **Variables** → **Secrets**：

| Secret | 用途 |
| --- | --- |
| `GITHUB_DISPATCH_TOKEN` | GitHub PAT，`repo` 范围 + **Actions: Read and write**，用于 cron / admin 触发 workflow |
| `ADMIN_SECRET` | `/admin/*` 路由的 Bearer token |
| `ALERT_WEBHOOK_URL` | *(可选)* Discord / Slack incoming webhook，探活失败时通知 |

**GitHub PAT 创建：** Settings → Developer settings → Fine-grained token → Repository `Tito-XD/tito-dex` → Permissions: **Actions: Read and write**, **Contents: Read**.

l10n 定时已从 GitHub `schedule:` 迁移到 Worker cron；手动触发仍可用 Actions **Run workflow** 或 Worker admin API。

---

## 图鉴包构建与上传

与 Worker 部署 **分开**进行：

```bash
pip install -r tools/dex_bundle_requirements.txt

# 当前生产 v5（1025 物种 → R2 /v3/，含 l10n/maps/config）
python3 tools/build_dex_bundle.py --cdn-base https://dex.tito.cafe --output dist/dex-v5 --max-id 1025

# 遗留 v4（493 物种 → R2 /v2/）
python3 tools/build_dex_bundle.py --cdn-base https://dex.tito.cafe --output dist/dex-v4 --max-id 493

python3 tools/upload_dex_via_worker.py dist/dex-v5/upload   # 需临时 bootstrap 路由，或 wrangler / CI
```

上传目录结构：

| 本地路径 | R2 前缀 | 说明 |
| --- | --- | --- |
| `upload/v2/` | `v2/` | bundle **v4**，493 物种（遗留） |
| `upload/v3/` | `v3/` | bundle **v5**，1025 物种 + l10n/config（**v0.4.x 生产**） |
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

## Worker 职责（v2026-07-13）

| 能力 | 路由 / 触发 | 说明 |
| --- | --- | --- |
| **CDN 网关** | `GET /*` | R2 只读代理 + CORS + Cache-Control |
| **版本跳转** | `GET /bundle/latest` | 302 → manifest 中的 `archiveUrl` |
| **存活探针** | `GET /cdn-health` | 轻量 `{ ok: true }` |
| **深度探活** | `GET /cdn-health?probe=1` | 抽查 9 个关键 R2 key + manifest 摘要 |
| **Sprite 回退** | `GET /v3/sprites/by-version/...` | 缺失时依次尝试其他 version group → 默认 sprite → artwork；响应头 `X-TitoDex-Sprite-Fallback` |
| **条件请求** | 任意 GET | 支持 `If-None-Match` → 304 |
| **Manifest KV 缓存** | `bundle-manifest.json` | 5 分钟 KV 热缓存（需绑定 `MANIFEST_KV`） |
| **Cron 调度** | 见上表 | 触发 GitHub Actions，不跑 Python 构建 |
| **管理面** | 见下表 | 需 `Authorization: Bearer $ADMIN_SECRET` |

### Admin API

```bash
export ADMIN_SECRET="..."
export CDN=https://dex.tito.cafe

# 深度状态（等同 probe=1 + 上次 cron 记录）
curl -s -H "Authorization: Bearer $ADMIN_SECRET" "$CDN/admin/status" | jq .

# 手动触发 l10n 同步
curl -s -X POST -H "Authorization: Bearer $ADMIN_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"workflow":"sync-l10n","inputs":{"force_full":false}}' \
  "$CDN/admin/trigger-sync" | jq .

# 手动触发 PokeAPI 资源构建
curl -s -X POST -H "Authorization: Bearer $ADMIN_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"workflow":"pokeapi-assets","inputs":{"min_id":1,"max_id":1025,"upload":true}}' \
  "$CDN/admin/trigger-sync" | jq .

# 仅更新 bundle-manifest.json 指针（合并 patch，自动 bump publishedAt）
curl -s -X PUT -H "Authorization: Bearer $ADMIN_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"l10nVersion":"2026-07-13T12:00:00+00:00"}' \
  "$CDN/admin/manifest" | jq .
```

`workflow` 可选值：`sync-l10n`、`pokeapi-assets`。

---

## 相关文件

| 文件 | 作用 |
| --- | --- |
| `wrangler.toml` | Worker 名、R2 binding、路由、cron |
| `package.json` | Wrangler 版本、`npm run deploy` |
| `src/worker.js` | 入口：fetch + scheduled |
| `src/lib/*.js` | CDN 代理、探活、回退、admin、cron |
| `../../docs/CLOUDFLARE_DEX_CDN.md` | R2 目录结构、图鉴包构建 |
