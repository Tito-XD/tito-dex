# TitoDex 图鉴 — Cloudflare 配置说明

> **受众：** Cloudflare 侧 Agent / 运维（**内部文档**）。只负责 **R2 + CDN + 离线图鉴包**，不涉及 App UI。
>
> **请勿**在 App 文案、GitHub Release 说明、公开 README 中粘贴 CDN 直链，避免被滥用刷流量。
>
> **App 对齐：** 离线目录格式与 `flutter/lib/features/dex/dex_cache_store.dart` 一致。

---

## 目标

为 TitoDex（Flutter 掌机 App）提供：

1. **预构建离线图鉴包** — 全国图鉴 #1–**1025**（当前 App v0.4.6 默认 bundle v5）
2. **CDN 加速** — 精灵图、属性图标、单条详情 JSON
3. **一次下载完整包** — 掌机不必逐条请求 PokeAPI

App 侧环境变量（由 CDN 部署交付）：

```bash
# Current production (v0.4.6 APK)
TITODEX_DEX_CDN_BASE=https://dex.tito.cafe
TITODEX_DEX_BUNDLE_URL=https://dex.tito.cafe/v3/bundle.tar.zst
TITODEX_DEX_BUNDLE_VERSION=5
```

自定义域名配置详解：[`cloudflare/dex-cdn/DOMAIN.md`](../cloudflare/dex-cdn/DOMAIN.md)

---

## CDN 路径版本

| R2 / CDN 前缀 | bundleVersion | 物种数 | 说明 |
| --- | --- | --- | --- |
| **`/v2/`** | **4** | 493 | 遗留 — 旧客户端 |
| **`/v3/`** | **5** | **1025** | **当前生产** — v0.4.x App 默认 |

v5 与 v4 可并存：旧客户端继续读 `/v2/`；新客户端读 `/v3/` 与 `bundle-manifest.json` 中的 `archiveUrl`。

---

## Worker 自动部署（Workers Builds）

**不用本地 wrangler deploy。** 在 Cloudflare Dashboard 连接 GitHub，推送 **`deploy/dex-cdn`** 分支即自动部署。

| 设置 | 值 |
| --- | --- |
| 仓库 | `Tito-XD/tito-dex` |
| 生产分支 | **`deploy/dex-cdn`** |
| Root directory | `cloudflare/dex-cdn` |
| Build command | *(留空)* |
| Deploy command | `npx wrangler deploy` |

详细步骤：[`cloudflare/dex-cdn/DEPLOY.md`](../cloudflare/dex-cdn/DEPLOY.md)

---

| 项目 | 说明 |
| --- | --- |
| 宝可梦 | 全国图鉴 #1–**1025**（bundle v5）；#1–493（bundle v4 遗留） |
| 元数据 | 中英文名、属性、详情、多版本招式、进化链（来源 PokeAPI） |
| 精灵图 | `official-artwork.front_default`，无则 `front_default` |
| 属性图标 | PokeAPI `type` → `sprites.generation-iii.colosseum.name_icon` |
| 中文名 | `pokemon-species` → `names` 里 `zh-Hans` |

---

## R2 Bucket 结构

**Bucket 名建议：** `titodex-dex`

```txt
titodex-dex/
├── bundle-manifest.json          # latest 指针（短 TTL；archiveUrl 指向活跃 bundle）
├── v2/                           # bundle v4 — 493 物种（当前生产）
│   ├── manifest.json
│   ├── summaries.json
│   ├── types.json
│   ├── moves.json
│   ├── bundle.tar.zst
│   ├── details/1.json … 493.json
│   ├── sprites/1.png … 493.png
│   └── type_icons/*.png
└── v3/                           # bundle v5 — 1025 物种（v0.4.6+）
    ├── manifest.json
    ├── summaries.json
    ├── types.json
    ├── moves.json
    ├── abilities.json            # 特性索引（v5 新增）
    ├── bundle.tar.zst            # 含 l10n/ maps/ config/ game_icons/
    ├── l10n/zh/*.json            # 中文对照表（可单独热更新）
    ├── maps/hgss_map_list.json   # HGSS 地图 id → 中英文名
    ├── config/app_config.json    # Sleep 工具链接等应用配置
    ├── game_icons/*.png          # 游戏版本选择图标
    ├── details/1.json … 1025.json
    ├── sprites/1.png … 1025.png
    └── type_icons/*.png

> **不进 CDN：** 手绘底部导航图标（nav icons）随 APK `assets/` 内置，用户自行绘制替换。

CDN 大图（按需，不进 bundle.tar.zst）：

    v2/artwork/ … v3/artwork/
```

### `bundle-manifest.json`（CDN 根目录 / R2 根）

```json
{
  "bundleVersion": 5,
  "pokemonCount": 1025,
  "archiveUrl": "https://dex.tito.cafe/v3/bundle.tar.zst",
  "archiveSha256": "<sha256>",
  "archiveSizeBytes": 0,
  "publishedAt": "2026-07-11T00:00:00Z",
  "l10nVersion": "2026-07-13T04:52:57+00:00",
  "configVersion": 1
}
```

### `manifest.json`（App 离线目录根文件）

```json
{
  "version": 5,
  "complete": true,
  "preferOffline": true,
  "downloadedAt": "2026-07-11T00:00:00Z",
  "pokemonCount": 1025,
  "moveCount": 0,
  "abilityCount": 0,
  "l10nVersion": "2026-07-13T04:52:57+00:00",
  "configVersion": 1,
  "sizeBytes": 0
}
```

### Bundle v5 schema 变更（相对 v4）

| 字段 | 位置 | 说明 |
| --- | --- | --- |
| `pokedexNumbers` | `summaries.json` 每条 | PokeAPI pokedex name → regional number，供 `DexScope` 地区过滤 |
| `abilities` | `details/{id}.json` | 特性名/描述/是否隐藏 |
| `obtainLocations` | `details/{id}.json` | 按游戏版本的遭遇地点列表 |
| `moveSets` | `details/{id}.json` | 多 version-group（HGSS / SV / SwSh）招式表 |
| `abilities.json` | bundle 根 | 特性百科索引 + `pokemonIds` 反向列表 |

### `summaries.json` 单条格式（v5）

```json
{
  "id": 155,
  "nameEn": "Cyndaquil",
  "nameZh": "火球鼠",
  "types": ["fire"],
  "pokedexNumbers": {
    "national": 155,
    "original-johto": 155
  },
  "spriteUrl": "https://dex.tito.cafe/v3/sprites/155.png",
  "artworkUrl": "https://dex.tito.cafe/v3/artwork/155.png",
  "localSpritePath": "sprites/155.png"
}
```

### 解压 `bundle.tar.zst` 后目录

须与 App 本地路径 **1:1** 对应（解压到 `dex_offline/`）：

```txt
dex_offline/
├── manifest.json
├── summaries.json
├── types.json
├── moves.json
├── abilities.json       # v5+
├── l10n/zh/             # 中文对照（优先于 APK assets）
│   ├── location_area_labels.json
│   ├── hgss_map_labels.json
│   └── …
├── maps/
│   └── hgss_map_list.json
├── config/
│   └── app_config.json  # Sleep 工具链接等
├── game_icons/*.png     # 游戏版本图标
├── details/{id}.json
├── sprites/{id}.png
└── type_icons/{type}.png
```

**加载顺序：** `dex_offline/`（bundle 安装后）→ APK `assets/` 回退。App 不在运行时抓取 52poke / PokeAPI 更新对照表。

> 仓库内 `tools/build_dex_bundle.py` 生成的 tar 根目录即为上述结构（无 `v3/` 前缀）。

---

## CDN 直链规则

| URL | 内容 |
| --- | --- |
| `https://dex.<域名>/v3/sprites/{id}.png` | 精灵缩略图（v5） |
| `https://dex.<域名>/v3/artwork/{id}.png` | 精灵大图（v5） |
| `https://dex.<域名>/v3/type_icons/{type}.png` | 属性图标 |
| `https://dex.<域名>/v3/details/{id}.json` | 详情 JSON |
| `https://dex.<域名>/v3/summaries.json` | 摘要列表 |
| `https://dex.<域名>/v3/bundle.tar.zst` | 完整离线包 v5 |
| `https://dex.<域名>/v2/...` | 同上结构 — bundle v4（493） |
| `https://dex.<域名>/bundle-manifest.json` | 版本索引 |
| `https://dex.<域名>/bundle/latest` | Worker 302 → `archiveUrl` |

### Cache Rules

| 路径 | TTL | Cache-Control |
| --- | --- | --- |
| `/v2/sprites/*`, `/v3/sprites/*` | 1 年 | `public, max-age=31536000, immutable` |
| `/v2/artwork/*`, `/v3/artwork/*` | 1 年 | 同上 |
| `/v2/type_icons/*`, `/v3/type_icons/*` | 1 年 | 同上 |
| `/v2/details/*`, `/v3/details/*` | 1 年 | 同上 |
| `/v2/bundle.tar.zst`, `/v3/bundle.tar.zst` | 1 年 | 同上 |
| `/bundle-manifest.json` | 5 分钟 | `public, max-age=300` |

### CORS

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, HEAD
```

---

## 数据生成（本地 / CI）

### 依赖

```bash
pip install -r tools/dex_bundle_requirements.txt
```

### 构建 bundle v5（1025 只）

```bash
python3 tools/build_dex_bundle.py \
  --cdn-base https://dex.tito.cafe \
  --output dist/dex-v5 \
  --max-id 1025
```

产物：

- `dist/dex-v5/staging/` — 与 `dex_offline/` 同结构的明文目录
- `dist/dex-v5/upload/v3/` — 待上传 R2 的 **v3** 前缀内容
- `dist/dex-v5/upload/bundle-manifest.json` — 根 manifest

### 冒烟构建（仅前 3 只）

```bash
python3 tools/build_dex_bundle.py --cdn-base https://dex.tito.cafe --max-id 3
```

### 遗留 v4 构建（493）

```bash
python3 tools/build_dex_bundle.py \
  --cdn-base https://dex.tito.cafe \
  --output dist/dex-v4 \
  --max-id 493
```

（构建脚本默认 `BUNDLE_VERSION=5` / `v3`；如需纯 v4 产物请使用 main 上 v0.2.28 对应 commit 或手动改常量。）

### 上传 R2

```bash
export CLOUDFLARE_ACCOUNT_ID=...
export WRANGLER_R2_BUCKET=titodex-dex
./tools/upload_dex_bundle.sh dist/dex-v5/upload
```

上传后 **Purge CDN cache**（至少 purge `/bundle-manifest.json`）。

---

## 交付清单

| 项 | 验收 |
| --- | --- |
| R2 bucket `titodex-dex` | v2 + v3 资源已上传 |
| 自定义域名 `dex.tito.cafe` | 已绑定 |
| `bundle-manifest.json` | 公网可 GET，`archiveUrl` 正确 |
| v3 `bundle.tar.zst` | 可下载，SHA256 与 manifest 一致 |
| 解压后 | `manifest.complete=true`，`pokemonCount=1025` |
| 抽测 CDN | #1 #25 #155 #493 #1000 #1025 精灵图可直链 |
| CORS + Cache Rules | 已配 |

---

Or run `python3 tools/stage_l10n_upload.py` then upload `dist/l10n-upload/` manually with Wrangler.

---

## 自动化：每周 l10n 同步（52poke → R2）

GitHub Actions workflow [`.github/workflows/sync-l10n-catalog.yml`](../.github/workflows/sync-l10n-catalog.yml) 每周日 04:00 UTC 运行（也可 `workflow_dispatch` 手动触发）。

### 流程

1. `tools/fetch_52poke_location_zh.py` — 从 `location_areas_unresolved.json` 读取 slug，尝试从 52poke wiki 抓取中文名（礼貌限速，User-Agent: `TitoDex-maintainer`），合并到 `data/l10n/zh/location_areas.json`
2. `tools/generate_zh_catalog_assets.py` — 生成紧凑 APK / CDN 用 `flutter/assets/l10n/zh/*.json`
3. `tools/stage_l10n_upload.py` — 复制 l10n + maps + config 到 `dist/l10n-upload/v3/`
4. Wrangler 上传到 R2：
   - `v3/l10n/zh/*`
   - `v3/maps/hgss_map_list.json`（如有变更）
   - `v3/config/app_config.json`
   - 根目录 `bundle-manifest.json`（更新 `l10nVersion` + `publishedAt`）

### workflow_dispatch 输入

| 输入 | 说明 |
| --- | --- |
| `force_full` | `true` 时重新解析所有仍缺中文的 slug（不限 unresolved 列表） |

### 所需 GitHub Secrets

| Secret | 说明 |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | R2 Object Write |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare 账户 ID |

详见 [`docs/PERMISSIONS.md`](PERMISSIONS.md)。

### 52poke 抓取限制

52poke wiki 可能启用 Cloudflare 人机验证，导致 CI 无法自动抓取。脚本会记录失败并将 slug 保留在 `location_areas_unresolved.json`；可在本地网络环境手动运行：

```bash
pip install requests beautifulsoup4
python3 tools/fetch_52poke_location_zh.py --limit 20
python3 tools/generate_zh_catalog_assets.py
python3 tools/stage_l10n_upload.py
```

---

## 相关仓库文件

| 路径 | 说明 |
| --- | --- |
| `tools/build_dex_bundle.py` | 构建脚本（`--max-id 1025`） |
| `tools/upload_dex_bundle.sh` | Wrangler 批量上传 |
| `cloudflare/dex-cdn/` | Worker + wrangler.toml |
| `flutter/lib/features/dex/dex_cache_store.dart` | App 本地离线目录布局 |
| `flutter/lib/features/dex/dex_models.dart` | JSON schema |
| `flutter/lib/features/dex/dex_scope.dart` | `DexScope` / 1025 browse |
