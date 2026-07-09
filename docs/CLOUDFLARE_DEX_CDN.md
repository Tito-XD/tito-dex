# TitoDex 图鉴 — Cloudflare 配置说明

> **受众：** Cloudflare 侧 Agent / 运维。只负责 **R2 + CDN + 离线图鉴包**，不涉及 App UI。
>
> **App 对齐：** 离线目录格式与 `flutter/lib/features/dex/dex_cache_store.dart` 一致（schema **v2**）。

---

## 目标

为 TitoDex（Flutter 掌机 App）提供：

1. **预构建离线图鉴包** — 全国图鉴 #1–493（魂银范围）
2. **CDN 加速** — 精灵图、属性图标、单条详情 JSON
3. **一次下载完整包** — 掌机不必逐条请求 PokeAPI

App 侧将来读取三个环境变量（由你交付给 App 开发者）：

```bash
TITODEX_DEX_CDN_BASE=https://dex.tito.cafe
TITODEX_DEX_BUNDLE_URL=https://dex.tito.cafe/v2/bundle.tar.zst
TITODEX_DEX_BUNDLE_VERSION=4
```

自定义域名配置详解：[`cloudflare/dex-cdn/DOMAIN.md`](../cloudflare/dex-cdn/DOMAIN.md)

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
| 宝可梦 | 全国图鉴 #1–493 |
| 元数据 | 中英文名、属性、详情、HGSS 招式、进化链（来源 PokeAPI） |
| 精灵图 | `official-artwork.front_default`，无则 `front_default` |
| 属性图标 | PokeAPI `type` → `sprites.generation-iii.colosseum.name_icon`（按 type id，非名称路径） |
| 中文名 | `pokemon-species` → `names` 里 `zh-Hans` |

---

## R2 Bucket 结构

**Bucket 名建议：** `titodex-dex`

```txt
titodex-dex/
├── bundle-manifest.json          # latest 指针（短 TTL）
└── v2/
    ├── manifest.json             # 与 App 本地 dex_offline/manifest.json 一致
    ├── summaries.json
    ├── types.json
    ├── moves.json
    ├── bundle.tar.zst            # 完整离线包（推荐 App 一次下载）
    ├── details/
    │   └── 1.json … 493.json
    ├── sprites/
    │   └── 1.png … 493.png       # PNG 缩略图，宽 ≤220px
    └── type_icons/
        └── fire.png …            # 18 种属性

CDN 另提供大图（不进离线 bundle.tar.zst，按需加载）：

    upload/v2/artwork/
        └── 1.png … 493.png       # PNG 原尺寸 official-artwork
```

### `bundle-manifest.json`（CDN 根目录 / R2 根）

```json
{
  "bundleVersion": 2,
  "pokemonCount": 493,
  "archiveUrl": "https://dex.<你的域名>/v2/bundle.tar.zst",
  "archiveSha256": "<sha256>",
  "archiveSizeBytes": 0,
  "publishedAt": "2026-07-09T00:00:00Z"
}
```

### `manifest.json`（App 离线目录根文件）

```json
{
  "version": 2,
  "complete": true,
  "preferOffline": true,
  "downloadedAt": "2026-07-09T00:00:00Z",
  "pokemonCount": 493,
  "moveCount": 0,
  "sizeBytes": 0
}
```

### `summaries.json` 单条格式

```json
{
  "id": 155,
  "nameEn": "Cyndaquil",
  "nameZh": "火球鼠",
  "types": ["fire"],
  "spriteUrl": "https://dex.<域名>/v2/sprites/155.png",
  "artworkUrl": "https://dex.<域名>/v2/artwork/155.png",
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
├── details/{id}.json
├── sprites/{id}.png
└── type_icons/{type}.png
```

> 仓库内 `tools/build_dex_bundle.py` 生成的 tar 根目录即为上述结构（无 `v2/` 前缀）。

---

## CDN 配置

### 自定义域名

`dex.<你的域名>` → R2 bucket `titodex-dex`（Public access **或** Worker 代理，见 `cloudflare/dex-cdn/`）

### 直链规则

| URL | 内容 |
| --- | --- |
| `https://dex.<域名>/v2/sprites/{id}.png` | 精灵图 |
| `https://dex.<域名>/v2/type_icons/{type}.png` | 属性图标 |
| `https://dex.<域名>/v2/details/{id}.json` | 详情 JSON |
| `https://dex.<域名>/v2/summaries.json` | 摘要列表 |
| `https://dex.<域名>/v2/bundle.tar.zst` | 完整离线包 |
| `https://dex.<域名>/bundle-manifest.json` | 版本索引 |
| `https://dex.<域名>/bundle/latest` | Worker 302 → `archiveUrl`（可选） |

### Cache Rules

| 路径 | TTL | Cache-Control |
| --- | --- | --- |
| `/v2/sprites/*` | 1 年 | `public, max-age=31536000, immutable` |
| `/v2/type_icons/*` | 1 年 | 同上 |
| `/v2/details/*` | 1 年 | 同上 |
| `/v2/bundle.tar.zst` | 1 年 | 同上（带版本号路径） |
| `/bundle-manifest.json` | 5 分钟 | `public, max-age=300` |

### CORS

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, HEAD
```

Android App 使用 `http` 包 GET，需允许跨域。若用本仓库 Worker，CORS 已在 Worker 内注入。

---

## 数据生成（本地 / CI）

### 依赖

```bash
pip install -r tools/dex_bundle_requirements.txt
```

### 构建完整 v2 包

```bash
python tools/build_dex_bundle.py \
  --cdn-base https://dex.example.com \
  --output dist/dex-v2
```

产物：

- `dist/dex-v2/staging/` — 与 `dex_offline/` 同结构的明文目录
- `dist/dex-v2/upload/v2/` — 待上传 R2 的 `v2/` 前缀内容
- `dist/dex-v2/upload/bundle-manifest.json` — 根 manifest

### 冒烟构建（仅前 3 只）

```bash
python tools/build_dex_bundle.py --cdn-base https://dex.example.com --max-id 3
```

### 上传 R2

```bash
export CLOUDFLARE_ACCOUNT_ID=...
export WRANGLER_R2_BUCKET=titodex-dex
./tools/upload_dex_bundle.sh dist/dex-v2/upload
```

或使用 Wrangler：

```bash
cd cloudflare/dex-cdn
wrangler r2 object put titodex-dex/v2/bundle.tar.zst --file=../../dist/dex-v2/upload/v2/bundle.tar.zst
```

上传后 **Purge CDN cache**（至少 purge `/bundle-manifest.json`）。

### 原始数据来源

| 用途 | URL |
| --- | --- |
| 元数据 | `https://pokeapi.co/api/v2` |
| 精灵图 | `sprites.other.official-artwork.front_default` ?? `front_default` |
| 属性图标 | `GET /type/{name}` → `sprites.generation-iii.colosseum.name_icon` |

构建脚本默认 **350ms** 请求间隔，避免 PokeAPI 限流。

### 体积目标

完整包 **< 30 MB**（JPEG quality 78，精灵宽 ≤220px）。

---

## Worker（可选）

见 `cloudflare/dex-cdn/src/worker.js`：

- `GET /bundle/latest` → 302 到 `bundle-manifest.json` 里的 `archiveUrl`
- 其余路径 → R2 对象 + CORS + 长缓存头

部署：

```bash
cd cloudflare/dex-cdn
wrangler deploy
```

---

## 交付清单

| 项 | 验收 |
| --- | --- |
| R2 bucket `titodex-dex` | 已创建，v2 资源已上传 |
| 自定义域名 `dex.<域名>` | 已绑定 |
| `bundle-manifest.json` | 公网可 GET |
| `bundle.tar.zst` | 可下载，SHA256 与 manifest 一致 |
| 解压后 | `manifest.complete=true`，`pokemonCount=493` |
| 抽测 CDN | #1 #25 #155 #447 #493 精灵图可直链 |
| CORS | 已开 |
| Cache Rules | 已配 |

### 交给 App 侧的三个值

```bash
TITODEX_DEX_CDN_BASE=https://dex.<你的域名>
TITODEX_DEX_BUNDLE_URL=https://dex.<你的域名>/v2/bundle.tar.zst
TITODEX_DEX_BUNDLE_VERSION=4
```

---

## 相关仓库文件

| 路径 | 说明 |
| --- | --- |
| `tools/build_dex_bundle.py` | 一次性构建脚本（与 App 格式对齐） |
| `tools/upload_dex_bundle.sh` | Wrangler 批量上传 |
| `cloudflare/dex-cdn/` | Worker + wrangler.toml |
| `flutter/lib/features/dex/dex_cache_store.dart` | App 本地离线目录布局 |
| `flutter/lib/features/dex/dex_models.dart` | JSON schema（`DexCacheManifest.currentVersion = 2`） |
