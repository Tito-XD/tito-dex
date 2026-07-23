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

- `/v2/`、`/v3/`、`/v4/`、`/v5/` 的详情、图片、索引和 archive → 1 年 immutable
- `/v5/l10n/*`、`/v5/maps/*`、`/v5/config/*` → 短缓存，允许受控增量同步
- `/bundle-manifest.json` → 5 分钟

Worker 已注入 CORS；若直接用 R2 公开域名，需在 R2 设置 CORS。

### 6. KV（manifest 热缓存与 cron 状态）

生产已使用独立 `MANIFEST_KV` namespace，并在 `wrangler.toml` 绑定。不得复用同账号中
无关的 `FODI_CACHE`。新环境可在 Dashboard → **Workers KV** 创建独立 namespace。

Worker → **Settings** → **Bindings** → KV namespace → `MANIFEST_KV`

绑定名必须为 `MANIFEST_KV`；它保存根 manifest 热缓存、上次深度探活和上次 dispatch 状态。

### 7. Cron 与 Secrets（调度 + 管理面）

`wrangler.toml` 已配置两条 cron：

| Cron | 时间 (UTC) | 动作 |
| --- | --- | --- |
| `0 4 * * SUN` | 每周日 04:00 | `repository_dispatch` → **Sync l10n Catalog** |
| `0 */6 * * *` | 每 6 小时 | 深度 R2 探活，失败时可选 webhook 告警 |

Worker → **Settings** → **Variables** → **Secrets**：

| Secret | 用途 |
| --- | --- |
| `GITHUB_DISPATCH_TOKEN` | GitHub PAT，`repo` 范围 + **Actions: Read and write**，用于 cron / admin 触发 workflow |
| `ADMIN_SECRET` | `/admin/*` 路由的 Bearer token |
| `TELEGRAM_BOT_TOKEN` | *(可选)* Telegram Bot token（@BotFather 创建） |
| `TELEGRAM_CHAT_ID` | *(可选)* 接收告警的 chat id（私聊或群组） |
| `ALERT_WEBHOOK_URL` | *(可选)* Discord / Slack webhook（不用 Telegram 时可配） |

**GitHub PAT 创建：** Settings → Developer settings → Fine-grained token → Repository `Tito-XD/tito-dex` → Permissions: **Actions: Read and write**, **Contents: Read**.

l10n 定时已从 GitHub `schedule:` 迁移到 Worker cron；手动触发仍可用 Actions **Run workflow** 或 Worker admin API。

#### Telegram 告警配置（推荐）

1. 在 Telegram 搜索 **@BotFather** → `/newbot` → 按提示取名 → 复制 **bot token**（形如 `123456789:ABCdef...`）
2. 在 Telegram 搜索你刚创建的 bot → 点 **Start**，随便发一条消息（例如 `hi`）
3. 浏览器打开（把 `<TOKEN>` 换成 bot token）：
   `https://api.telegram.org/bot<TOKEN>/getUpdates`
4. 在返回 JSON 里找 `"chat":{"id":123456789}` → 这个数字就是 **chat id**
   - 私聊：id 通常是正数
   - 群组：id 通常是负数（先把 bot 拉进群并 @ 它发一条消息，再查 getUpdates）
5. Cloudflare Worker Secrets 填入：
   - `TELEGRAM_BOT_TOKEN` = 步骤 1 的 token
   - `TELEGRAM_CHAT_ID` = 步骤 4 的 id

验证（本地或任意终端）：

```bash
curl -s -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -H "Content-Type: application/json" \
  -d '{"chat_id":"<CHAT_ID>","text":"TitoDex CDN alert test OK"}'
```

Telegram 收到消息即配置成功。探活失败或 cron 报错时 Worker 会自动发同类通知。

---

## 图鉴包构建与上传

与 Worker 部署 **分开**进行：

```bash
pip install -r tools/dex_bundle_requirements.txt

# 当前生产 v7（1025 物种 → R2 /v5/）
python3 tools/patch_dex_bundle_v7.py --base-bundle dist/dex-seeds/v6.tar.zst --legacy-media-bundle dist/dex-seeds/v5.tar.zst --output dist/dex-v7

# 必须先上传并验证 /v5/，再最后更新根 manifest
python3 tools/upload_dex_bundle_r2.py dist/dex-v7/upload --cdn-prefix v5 --phase objects
python3 tools/upload_dex_bundle_r2.py dist/dex-v7/upload --cdn-prefix v5 --phase manifest
```

上传目录结构：

| 本地路径 | R2 前缀 | 说明 |
| --- | --- | --- |
| `upload/v2/` | `v2/` | bundle **v4**，493 物种（遗留） |
| `upload/v3/` | `v3/` | bundle **v5**，1025 物种（回滚 / 旧客户端，不修改） |
| `upload/v4/` | `v4/` | bundle **v6**，完整形态与精确版本地点（回滚） |
| `upload/v5/` | `v5/` | bundle **v7**，清晰默认图与形态历代 sprite |
| `upload/bundle-manifest.json` | 根 | 最后写入，指向已完整验证的 v5 archive |

Bundle v7 复用 v6 的全部数据，只增量修复默认图片和形态历代 sprite 元数据。`/v4/` 不覆盖、不删除。

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
TITODEX_DEX_BUNDLE_URL=https://dex.tito.cafe/v5/bundle.tar.zst
TITODEX_DEX_BUNDLE_VERSION=7
```

当前生产 bundle SHA256 见 GitHub Release [v0.2.24/v0.2.25/v0.2.28](https://github.com/Tito-XD/tito-dex/releases) 或 live `bundle-manifest.json`。

---

## Worker 职责（v2026-07-23-v5）

| 能力 | 路由 / 触发 | 说明 |
| --- | --- | --- |
| **CDN 网关** | `GET /*` | R2 只读代理 + CORS + Cache-Control |
| **版本跳转** | `GET /bundle/latest` | 302 → manifest 中的 `archiveUrl` |
| **存活探针** | `GET /cdn-health` | 轻量 `{ ok: true }` |
| **深度探活** | `GET /cdn-health?probe=1` | 从根 manifest 动态取活跃前缀，抽查关键 R2 key + manifest 摘要 |
| **Sprite 回退** | `GET /vN/sprites/by-version/...` | 缺失时依次尝试其他 version group → 默认 sprite → artwork；合法默认图回退也算健康 |
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
