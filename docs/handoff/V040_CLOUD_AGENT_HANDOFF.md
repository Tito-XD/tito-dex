# v0.4.0 Cloud Agent 交接手册

> **用途：** 在新 Cloud VM / 新 Agent 对话里 `@docs/handoff/V040_CLOUD_AGENT_HANDOFF.md`，按本文 build → upload → Flutter 开发 → 发版。  
> **目标版本：** `v0.4.0` · App `0.4.0+32`（暂定）  
> **仓库：** `github.com/Tito-XD/tito-dex` · 基线分支 **`main`**（含 v0.3.0 + bundle v5 代码，**CDN `/v3/` 尚未上线**）

---

## 0. 当前线上 vs 代码状态

| 项 | 生产 CDN | 代码 / main |
| --- | --- | --- |
| 域名 | `https://dex.tito.cafe` | 同左 |
| R2 bucket | `titodex-dex` | 同左 |
| Worker | `tito-dex`（**只读** GET/HEAD） | `cloudflare/dex-cdn/` |
| 路径 | **`/v2/`** only | App 默认读 **`/v3/`** |
| bundleVersion | **4** | **5** |
| 物种数 | **493** | **1025** |
| manifest | `bundle-manifest.json` → v2 archive | 应指向 v3 |

**验证命令：**

```bash
curl -s https://dex.tito.cafe/bundle-manifest.json | jq .
curl -I https://dex.tito.cafe/v3/summaries.json   # 期望 404（待 upload）
curl -s https://dex.tito.cafe/cdn-health | jq .
```

---

## 1. Cloudflare 侧职责（本 Agent 先做这块）

### 1.1 账号资源

| 资源 | 名称 / ID |
| --- | --- |
| R2 bucket | `titodex-dex` |
| Worker | `tito-dex` |
| 自定义域 | `dex.tito.cafe` → zone `tito.cafe` |
| Worker 部署分支 | `deploy/dex-cdn`（Git push 自动 deploy） |

### 1.2 上传凭证（Shell 必须可用）

**任选其一**（写入 Cloud Agent Environment Secrets 后 **Restart VM**）：

**方案 A — R2 S3 API（推荐，大文件）**

```bash
CLOUDFLARE_ACCOUNT_ID=<account_id>
R2_ACCESS_KEY_ID=<key>
R2_SECRET_ACCESS_KEY=<secret>
```

**方案 B — Wrangler API Token**

```bash
CLOUDFLARE_ACCOUNT_ID=<account_id>
CLOUDFLARE_API_TOKEN=<token with R2 Edit>
```

**验证：**

```bash
python3 tools/upload_dex_bundle_r2.py dist/dex-v5-smoke/upload --cdn-prefix v3
# 或 smoke 后：
echo '{"ok":true}' > /tmp/probe.json
# 用 boto3 或 wrangler 上传 v3/_healthcheck.json 再 curl 验证
```

> **注意：** `upload_dex_via_worker.py`（`/_put/` bootstrap）**已不可用** — 线上 Worker 405。不要依赖此路径。

> **MCP `Cloudflare-bindings`：** 可读 bucket/worker 列表，**不能**写 R2 对象。上传必须走 Shell 凭证。

---

## 2. CDN 目录结构（R2 key 布局）

### 2.1 路径版本对照

| CDN 前缀 | bundleVersion | 物种 | 状态 |
| --- | --- | --- | --- |
| `/v2/` | 4 | 493 | ✅ 生产 |
| **`/v3/`** | **5** | **1025** | ❌ 待 build + upload |

根目录：

```
titodex-dex/
├── bundle-manifest.json          # 短 cache；指向当前推荐 bundle.tar.zst
└── v3/
    ├── manifest.json             # 包内元数据（offline install）
    ├── summaries.json            # 1025 条列表
    ├── moves.json                # 全局招式索引
    ├── abilities.json            # 全局特性索引
    ├── types.json                # 18 属性克制
    ├── bundle.tar.zst            # 离线安装包（含下列 JSON + sprites，不含 artwork）
    ├── details/{1..1025}.json    # 单只详情
    ├── sprites/{1..1025}.png     # 列表立绘
    ├── type_icons/{type}.png     # 18 个属性图标
    └── artwork/{1..1025}.png     # 大图（CDN 按需；可不进 tar）
```

v0.4.0 **还需新增**（见 §4）：

```
v3/
├── games.json                    # 23 游戏版本元数据 + 图标 URL + fallback 链
├── game_icons/{slug}.png         # 各游戏图标（PokeAPI /version/）
├── natures.json
├── egg_groups.json
├── status_conditions.json
├── weather.json
├── terrains.json
├── items.json                    # 常用道具子集（全量 2000+ 太大）
└── regional_dex/                 # 可选：预计算地区 id 列表
    ├── national.json
    ├── paldea.json
    └── ...
```

---

## 3. 图片 / 资源规格

| 路径 | 格式 | 尺寸 / 处理 | 数量 |
| --- | --- | --- | --- |
| `v3/sprites/{id}.png` | PNG α | max width **220px**，PokeAPI official-artwork 缩放 | **1025** |
| `v3/artwork/{id}.png` | PNG α | 原图或宽边 ≤512px（lazy，可不进 tar） | **1025** |
| `v3/type_icons/{type}.png` | PNG | max **64px**，Gen III colosseum 图标；fairy 可能缺失 | **18** |
| `v3/game_icons/{slug}.png` | PNG | PokeAPI version sprite，约 32–64px | **~23** |

**不包含在 bundle.tar.zst 内（仅 CDN）：** `artwork/`（减小离线包体积）。

**类型 slug 列表：**  
`normal fire water electric grass ice fighting poison ground flying psychic bug rock ghost dragon dark steel fairy`

---

## 4. JSON 数据范围（v0.4.0 全量 schema）

### 4.1 `summaries.json` — 每条 1 只，共 **1025**

```json
{
  "id": 25,
  "nameEn": "Pikachu",
  "nameZh": "皮卡丘",
  "types": ["electric"],
  "spriteUrl": "https://dex.tito.cafe/v3/sprites/25.png",
  "artworkUrl": "https://dex.tito.cafe/v3/artwork/25.png",
  "pokedexNumbers": {
    "national": 25,
    "kanto": 25,
    "original-johto": 22,
    "paldea": 74,
    "galar": 68
  }
}
```

### 4.2 `details/{id}.json` — 单只完整详情

**已有（v5 builder）：**

- `summary`, `genusZh`, `heightDm`, `weightHg`
- `baseStats`（hp/attack/defense/specialAttack/specialDefense/speed）
- `weaknesses`, `resistances`, `immunities`, `typeMultipliers`, `stabSuperEffective`
- `flavorEntries[]` — **v0.4.0 需扩展为全 23 游戏版本**（见 §5.1）
- `moveSet`（HGSS 兼容字段）+ `moveSets{}` keyed by version-group
- `abilities[]` — `{ nameEn, nameZh, descriptionZh, isHidden }`
- `obtainLocations[]` — **v0.4.0 改为按游戏分组** `obtainLocationsByGame{}`
- `evolutionChain`, `eggGroups`, `genderFemalePercent`, `hatchCounter`

**v0.4.0 新增字段：**

```json
{
  "baseHappiness": 70,
  "captureRate": 45,
  "evYield": { "speed": 2 },
  "flavorEntries": [
    {
      "gameEdition": "sv",
      "versionGroup": "scarlet-violet",
      "version": "scarlet",
      "labelZh": "朱·紫",
      "iconUrl": "https://dex.tito.cafe/v3/game_icons/scarlet-violet.png",
      "text": "……"
    }
  ],
  "obtainLocationsByGame": {
    "heartgold-soulsilver": [
      { "areaSlug": "route-29-area", "areaLabelZh": "29号道路", "minLevel": 2, "maxChance": 20 }
    ],
    "scarlet-violet": []
  },
  "moveSets": {
    "heartgold-soulsilver": {
      "levelUp": [{ "moveId": 33, "method": "level-up", "level": 1 }],
      "machine": [],
      "egg": [],
      "tutor": []
    }
  }
}
```

### 4.3 全局索引文件

| 文件 | 内容 | 预估大小 |
| --- | --- | --- |
| `moves.json` | id → 中英文名、属性、威力、命中、PP、分类 | **3–8 MB** |
| `abilities.json` | id → 中英文名、描述、关联 pokemonIds | **~0.5 MB** |
| `games.json` | 23 游戏版本定义（§5.1） | **~20 KB** |
| `natures.json` | 25 性格 + 升降 stat | **~10 KB** |
| `egg_groups.json` | 15 分组 | **~5 KB** |
| `status_conditions.json` | 灼伤/中毒/麻痹等 | **~5 KB** |
| `weather.json` | 晴/雨/沙暴等 | **~5 KB** |
| `terrains.json` | 电气/精神场地等 | **~5 KB** |
| `items.json` | 常用道具 curated | **0.5–2 MB** |

### 4.4 构建脚本

```bash
# 依赖
pip install requests zstandard pillow

# 全量 1025（2–4 小时，PokeAPI rate limit）
python3 tools/build_dex_bundle.py \
  --cdn-base https://dex.tito.cafe \
  --output dist/dex-v5 \
  --max-id 1025 \
  --delay 0.25

# 冒烟
python3 tools/build_dex_bundle.py --output dist/dex-v5-smoke --max-id 5

# 校验
python3 tools/test_dex_bundle_v5.py
python3 tools/test_dex_bundle_v5.py --check dist/dex-v5-smoke/staging/details/1.json
```

**上传：**

```bash
python3 tools/upload_dex_bundle_r2.py dist/dex-v5/upload --cdn-prefix v3
# 或
bash tools/upload_dex_bundle.sh dist/dex-v5/upload v3
```

**Worker 缓存：** 上传后需在 `cloudflare/dex-cdn/src/worker.js` 的 `cacheControlForKey` 增加 `v3/` 前缀规则（与 v2 相同），push `deploy/dex-cdn`。

---

## 5. 23 游戏版本列表（用户确认 · 截图 1）

全局 **唯一** `GameEdition`（首页 / 图鉴 / 详情 / 对战工具共用）：

| # | 显示名 | slug | PokeAPI version-group | 数据策略 |
| --- | --- | --- | --- | --- |
| 1 | 红/绿/蓝 (RGB) | rgb | `red-blue` | PokeAPI |
| 2 | 皮卡丘 (Y) | yellow | `yellow` | PokeAPI |
| 3 | 金/银 (GS) | gs | `gold-silver` | PokeAPI |
| 4 | 水晶 (C) | crystal | `crystal` | PokeAPI |
| 5 | 红宝石/蓝宝石 (RS) | rs | `ruby-sapphire` | PokeAPI |
| 6 | 绿宝石 (E) | emerald | `emerald` | PokeAPI |
| 7 | 火红/叶绿 (FRLG) | frlg | `firered-leafgreen` | PokeAPI |
| 8 | 钻石/珍珠 (DP) | dp | `diamond-pearl` | PokeAPI |
| 9 | 白金 (Pt) | pt | `platinum` | PokeAPI |
| 10 | 心金/魂银 (HGSS) | hgss | `heartgold-soulsilver` | PokeAPI · **旅程默认** |
| 11 | 黑/白 (BW) | bw | `black-white` | PokeAPI |
| 12 | 黑2/白2 (BW2) | bw2 | `black-2-white-2` | PokeAPI |
| 13 | X/Y (XY) | xy | `x-y` | PokeAPI |
| 14 | 欧米加红宝石/阿尔法蓝宝石 (ORAS) | oras | `omega-ruby-alpha-sapphire` | PokeAPI |
| 15 | 太阳/月亮 (SM) | sm | `sun-moon` | PokeAPI |
| 16 | 究极之日/月 (USUM) | usum | `ultra-sun-ultra-moon` | PokeAPI |
| 17 | Let's Go 皮卡丘/伊布 (LGPE) | lgpe | `lets-go-pikachu-lets-go-eevee` | PokeAPI |
| 18 | 剑/盾 (SWSH) | swsh | `sword-shield` | PokeAPI |
| 19 | 晶灿钻石/明亮珍珠 (BDSP) | bdsp | `brilliant-diamond-shining-pearl` | PokeAPI（招式/描述可能稀疏 → fallback） |
| 20 | 传说阿尔宙斯 (LA) | pla | `legends-arceus` | PokeAPI |
| 21 | 朱/紫 (SV) | sv | `scarlet-violet` | PokeAPI |
| 22 | 传说 Z-A (LZA) | lza | — | **无 PokeAPI** → UI 显示「暂无」，引导自选版本 |
| 23 | Champions (Champions) | champions | — | **无 PokeAPI** → 同上 |

### 5.1 图鉴描述（flavor）规则

1. **默认展示当前全局游戏版本** 的官方/可用文案。  
2. 无中文 → 英文；该版本无条目 → **fallback 到最近可用版本**（BDSP→DPPT，LZA→SV）。  
3. **可滑动** 查看其他已收录版本描述；每条带 **game icon**。  
4. LZA / Champions：**不伪造数据**，显示「当前版本暂无图鉴描述」+ 按钮「选择其他版本查看」。

### 5.2 11 个地区图鉴（用户确认）

`DexRegionalPokedex` 全开；**默认高亮与当前游戏相关的地区**（如 SV → 帕底亚/全国；HGSS → 城都/关东/全国）。

| 地区 | PokeAPI keys |
| --- | --- |
| 全国 | `national` |
| 关东 | `kanto` |
| 城都 | `original-johto`, `updated-johto` |
| 丰缘 | `hoenn`, `updated-hoenn` |
| 神奥 | `original-sinnoh`, `extended-sinnoh` |
| 合众 | `unova`, `updated-unova` |
| 卡洛斯 | `kalos-central`, `kalos-mountain`, `kalos-coastal` |
| 阿罗拉 | `original-alola`, `updated-alola` |
| 伽勒尔 | `galar`, `isle-of-armor`, `crown-tundra` |
| 帕底亚 | `paldea`, `kitakami`, `blueberry` |
| 洗翠 | `hisui` |

**图鉴页 UI 待改：** 当前仍只用 `DexRegionalScope` 三选一 → v0.4.0 接满 11 区。

---

## 6. CDN 体积估算（v0.4.0 全量）

| 组件 | v2 实测 (493) | v3/v0.4.0 预估 (1025 + 全版本) |
| --- | --- | --- |
| sprites PNG | ~8 MB | **~36 MB** |
| details JSON | ~3 MB | **~30–50 MB** |
| summaries + indices | ~0.2 MB | **~2–10 MB** |
| moves.json | ~78 KB | **~5–10 MB** |
| abilities + games + natures + … | — | **~2 MB** |
| type_icons | ~0.02 MB | ~0.02 MB |
| **upload/v3 合计（不含 artwork）** | 13 MB | **~75–100 MB** |
| **bundle.tar.zst（离线包）** | 3.7 MB | **~18–28 MB** |
| artwork/（CDN only） | 另计 | **+80–120 MB** |

**App 侧流量：** 首次 `summaries.json` ~1 MB；单条 `details/{id}.json` ~20–40 KB。

---

## 7. Flutter App 待改清单（v0.4.0 · 用户已确认）

> 基线：`main` @ v0.3.0。以下在 CDN `/v3/` 上线后联调。

### 7.1 Bug 修复

| # | 项 | 说明 |
| --- | --- | --- |
| B1 | **首页游戏名切换** | 点击应弹出 **23 项二级菜单**（非 cycle 轮换）；选后立即刷新 UI（修 GoRouter `pageKey` / `refreshListenable`） |
| B2 | **全局单一游戏版本** | 首页选择 = 图鉴/详情/对战/描述默认版本（`GameEdition` 统一存储） |
| B3 | **特性「待更新」** | CDN 有 `abilities` 则展示含 **隐藏特性**；无则明确空态 + 引导换版本 |
| B4 | **搜索页对战助手配色** | `CompanionToolsPanel` 深底上文字改浅/对比度 |

### 7.2 图鉴列表

| # | 项 | 状态 |
| --- | --- | --- |
| D1 | 地区菜单 **11 区全开**，默认高亮当前游戏相关地区 | ✅ v0.4.1 底部 sheet |
| D2 | 全国 **1–1025** 浏览/搜索 | ✅ |
| D3 | ~~版本栏改为 23 游戏~~ → **列表页去掉游戏筛选**，只保留地区图鉴 | 📋 **已确认待改**（2026-07） |

**D3 产品决策（Tito 确认）：**

- 图鉴**列表**不再显示横向 23 游戏条；用户用地区选择器（全国 / 城都 / …）即可。
- **游戏版本**仍保留在：详情页（招式/获得/描述）、首页、设置、搜索对战工具；全局 `GameEdition` 不从列表页改。
- 原因：点游戏会强制切地区，选全国不会重置游戏，两控件职责重叠易混淆。列表 = 看哪套图鉴；详情 = 按哪个版本解读数据。
- 与其它图鉴 UX 改动**一起批量改**，见 [ROADMAP.md](../../ROADMAP.md) Phase E。

### 7.3 详情四 Tab

| Tab | 项 | 状态 |
| --- | --- | --- |
| **简介** | 全版本 flavor 轮播 + game icon；**初始亲密度 / 基础点数(EV) / 捕获率**；特性完整 | 🚧 |
| **基本** | 种族值 **条形 ↔ 雷达** 小开关 | 🚧 |
| **获取** | `obtainLocationsByGame` 按当前游戏过滤；无数据 → 空态 + 换版本 | ⚠️ 有数据但 **地点名未映射**（截图：301、823 等裸 ID） |
| **招式** | 默认当前游戏 `moveSets`；筛选：**等级 / 教学 / 蛋 / 学习器**（单选激活） | ⚠️ 顶部 23 游戏 chips 占空间 |

**获取 Tab — 地点映射（Tito 确认待改，2026-07）：**

- 出现地点应显示中文地名（如「28号道路」「互连瀑布」），不能是裸数字 ID。
- 现状：`encounterAreaLabelsZh` 仅覆盖少量 PokeAPI slug；未命中则直接显示 slug/数字。
- 已有但未接入：`hgss_map_list.dart`（存档 map ID → 英文名，`game_zh` 本地化）。
- 待做：扩展 **encounter location 映射表**（bundle 构建时写入 `areaLabelZh` + App 展示兜底）。

**招式 Tab — 游戏筛选位置（Tito 确认待改，2026-07）：**

- **去掉**招式 Tab 顶部横向 23 游戏 chips（`_MoveGameEditionBar`）。
- 把 **「以下招式范围：心金/魂银 (HGSS)」** 改成可点击，弹出游戏选择列表（同地区图鉴 bottom sheet 模式）。
- 上方省一行，方法筛选 chips（等级/学习器/蛋/教学）保留。

与其它图鉴 UX 一起批量改 → [ROADMAP.md](../../ROADMAP.md) Phase E。

### 7.4 训练家 / 旅程 / 队伍（Tito 确认待改 · 2026-07）

完整分析 → [JOURNEY_PROFILE_PLAN.md](../../docs/JOURNEY_PROFILE_PLAN.md)

| # | 项 | 说明 |
| --- | --- | --- |
| J1 | **头像** | 现仍坏；改到 **设置** 里选图+裁切 |
| J2 | **设置分区** | 可改：训练家名、头像；**不可改**：地点/徽章/游戏时间（只读存档） |
| J3 | **游戏模式** | 设置全局版本 = NS/手游/无 parser → **不读档** |
| J4 | **首页** | 手动模式：隐藏继续旅程 Card；快捷 **4→3**；竖屏 **三格一行** |
| J5 | **底栏** | 手动模式：隐藏 **旅程** tab |
| J6 | **队伍** | 支持自填/编辑成员；顶部 **队伍整体数值估算** |

**现状：** 头像仅首页点击；设置里仍可手动改地点/徽章；存档解析仅 HGSS；队伍页只读。

### 7.5 资料中心（截图 2 & 3 · 用户确认「全都要」）

**建议：** `/search` 改为顶部分段 **搜索 | 常用资料 | 对战资料**（不增加第 6 个底栏 tab）。

**常用资料（截图 2）：**

- 指南：LZA 交互地图等 **外链**
- 资料列表：招式 / 特性 / 生蛋分组 / 性格 / 道具 / 天气 / 场地 / 状态异常 → **CDN JSON 驱动**
- 地区图鉴入口

**对战资料（截图 3）：**

- 对战：属性克制 / 属性伤害 / 打击盲点 / 联防盲点 / 伤害计算
- 培育：能力值 / 个体值 / 队伍编辑
- 在线：使用率排行 / Showdown 网页版 → **外链**

已有：属性克制、能力值、快速伤害（在搜索页）→ 迁入「对战资料」分区。

### 7.6 旅程 / 存档

- HGSS `.sav` seen/caught 仍限 **493** 全国图鉴位图（save-linked 模式）。
- 1025 浏览不影响存档解析。
- **待改：** NS/手游模式不读档 — 见 §7.4 / [JOURNEY_PROFILE_PLAN.md](../../docs/JOURNEY_PROFILE_PLAN.md)。

### 7.7 发版

- 版本：**v0.4.0**
- APK：`releases/TitoDex-0.4.0-rg-arm64.apk`
- GitHub Release + 更新 `bundle-manifest.json` 指向 v3

---

## 8. 关键代码路径（App）

```
flutter/lib/features/dex/
  dex_cdn_config.dart      # v3 URLs, bundleVersion 5
  dex_cdn_data_source.dart # 在线 CDN 读取
  dex_scope.dart           # DexGameVersion(8) → 扩到 GameEdition(23)
  dex_repository.dart
  dex_settings_repository.dart

flutter/lib/pages/
  dex_page.dart            # 地区/版本 UI 待扩
  pokemon_detail_page.dart
  search_page.dart         # → 资料中心 Hub

flutter/lib/app.dart       # 首页 _onGameBadgeTap bug
flutter/lib/features/game/game_catalog.dart  # 旧 7 游戏 cycle → 替换

tools/
  build_dex_bundle.py      # v5 builder，v0.4.0 扩展 schema
  upload_dex_bundle_r2.py  # 上传入口
  test_dex_bundle_v5.py
```

---

## 9. 推荐执行顺序（新 Agent 第一步）

```text
1. git pull origin main
2. 配置并验证 R2 上传凭证（§1.2）
3. 扩展 build_dex_bundle.py → v0.4.0 schema（§4）
4. python3 tools/build_dex_bundle.py --max-id 1025
5. python3 tools/upload_dex_bundle_r2.py dist/dex-v5/upload --cdn-prefix v3
6. curl 验证 v3/summaries.json + details/1.json 含 abilities
7. Flutter v0.4.0 功能（§7）
8. flutter test && 构建 APK && GitHub Release v0.4.0
```

---

## 10. 给用户的下一步命令模板

在新 VM 开对话后可直接粘贴：

```text
@docs/handoff/V040_CLOUD_AGENT_HANDOFF.md
按 §9 执行：先验证 R2 上传，再 build 1025 + upload v3，然后做 §7 全部 Flutter 改动，发 v0.4.0。
```

或分步：

```text
@docs/handoff/V040_CLOUD_AGENT_HANDOFF.md 只做 CDN：build 1025 + upload v3 + 验证
```

```text
@docs/handoff/V040_CLOUD_AGENT_HANDOFF.md CDN 已上线，做 Flutter §7 发 v0.4.0
```

---

*文档生成：2026-07-12 · 对应仓库 main @ v0.3.0*
