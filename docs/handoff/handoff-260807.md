# TitoDex 交接文档 — 2026-08-07

> 用途:给下一位评审/接手的模型。按「已完成 / 未完成 / 半成品 / 用户提出过的问题」整理,含关键路径与命令。

## 0. 环境与仓库状态

- 分支 `main`,领先 `origin/main` 约 18 个提交,**未 push**。
- 本机:Flutter 3.44.6(`C:\Users\tito\Development\flutter`)、Android SDK 36、wrangler 4.107.1(已 OAuth 登录)、三个 AVD(`TitoDex_Phone_API36` / `TitoDex_RG_720` / `TitoDex_Tablet`)。
- 生产 CDN(已上线):`bundleVersion=18`、`items.json=2130` 条、`mediaCatalogEntries=1020`、CDN 健康检查 ok;`v5/items.json` 的 1 年 immutable 缓存已手动清除并验证(ETag 已变)。
- 本会话模拟器进程反复被环境回收,integration drive 不稳定(见 §2-H)。

## 1. 已完成并上线(v14 → v18)

| 版本 | 内容 |
| --- | --- |
| v14 | 紧凑归档:去掉与 `sprites/` 重复的 `artwork/`(v13 106 MB → 54.8 MB) |
| v15 | 52poke 中文风味文本:1025/1025(1000 赛富豪为维护者提供概述);CC BY-NC-SA 署名进包 |
| v16 | 52poke 携带物品:现代世代(SwSh/BDSP/LA/SV/Z-A)补全;520 物种有数据;`items.json` 542→594;无概率行继承已知率(默认 5%) |
| v17 | 全量道具图鉴:2130 项、16 个 `categoryZh` 分类、967 张图标;app 分类筛选列表已同步 |
| v18 | 在线媒体目录 `media_catalog_52poke.json`(1020 物种、1163 叫声、1638 形态/HOME 图)打进 bundle;媒体文件本身走在线 |

- Cloudflare 审计完成,遗留 Worker `autumn-shape-2b65` 已删除。
- Workflow:线上发布 workflow = `.github/workflows/upload-dex-bundle.yml`(v18);v7/v12–v17 已存档到 `docs/archive/workflows/`。
- 增量发布工具:`tools/publish_dex_bundle_incremental.py`(本地只传相邻版本差异对象 + manifest-last + 回滚 manifest 保留)。
- App 功能(代码+测试就绪,**尚未发版**):详情美术查看器按图源翻面、Settings 媒体资源管理页、同行宝可梦形态/闪光/动图世代/叫声版本选择并持久化、道具分类 16 组筛选。
- 本地数据候选:v19(未发布)把道具中文说明提升到 2090/2130、图标提升到 1645/2130、物种媒体目录补到 1025/1025;另有 803 条形态记录(554 个非默认形态,其中 546 个有准确静态图);帕奇利兹的 4 个 LA 携带道具均有图和说明。
- 测试:全量 **340 个通过**、`flutter analyze` 0 issue;手机 AVD 上完整 integration 冒烟**在修复前通过过一次**。

## 2. 未完成 / 半成品 / 需完善(按用户提出顺序)

### A. 逐代 sprite 映射(用户重点不满,代码修复完成,待打包)

**现象**:搜索 帕奇利兹(417)/赛富豪(1000)会列出其出生前世代,且各世代图相同(全是默认图)。

**根因**:bundle `summaries.json` 的 `spriteUrlsByVersion` 对每个物种都写入全部 21 个版本组的 CDN `by-version` URL;PokeAPI 对未出生世代也返回 URL,但仓库里没有对应文件,CDN Worker 的 `by-version` 路由回退到默认 sprite → 全一样。

**已修(待提交/待打包)**:
- `flutter/lib/features/dex/sprite_generation_catalog.dart`:`kSpriteVersionGroupMaxId` 全版本组上限表;`spriteEditionOptionsForPokemon` 对两个循环都按上限过滤;黑2白2 无真实图(仓库 404)已只进上限表。
- `tools/build_dex_bundle.py`:`VERSION_GROUP_MAX_ID`,构建 summaries 时过滤未出生世代(下次重建 bundle 生效)。
- 测试:`test/sprite_generation_catalog_test.dart` 新增「Gen IV 物种不出现在 Gen I–III」「Gen IX 物种只保留朱紫组」。
- 后续修复:新增 `tools/generate_sprite_version_existence.py`,从 PokeAPI/sprites 官方 Git 树生成 `data/dex/sprite_version_existence.json` + Dart 常量,当前固定到 commit `8777f5066431f39fbe07614e0250a61b2029671c`。
- App 现在只展示「真实文件存在 × 不早于首发世代」的交集;BDSP/朱紫按真实物种子集过滤;v18 合成的 `/sprites/by-version/` URL 不再覆盖真实源或添加不存在的游戏组。
- 在线逐代图固定到上述 commit 的 `raw.githubusercontent.com` 路径;`tools/pokeapi_assets.py` 与 `build_dex_bundle.py` 共用同一矩阵,新 summaries 写真实固定源,不再生成无对象的 CDN URL。
- 验证:`flutter test --concurrency=1` **336 个通过**、`flutter analyze` 0 问题;Python Sprite/bundle 回归 22 个通过(1 个既有 smoke 条件跳过)。

**仍未解决(需要下一步)**:
1. 逐代映射修复已打过 `0.8.5-dev` APK 且用户反馈测试无问题;本轮新增的媒体选择/翻面/v19 数据尚未另打 APK。
2. 若用户网络仍无法稳定访问 `raw.githubusercontent.com`,可按已生成矩阵把同一批真实逐代文件增量镜像到自家 CDN;仍不放入离线 bundle。
3. LGPE / SwSh / LA 在 PokeAPI/sprites 没有真实逐版本正面图目录,因此现在正确地不显示;若未来引入其他可署名来源,必须扩展生成器来源表后再开放。

### B. 道具中文简介(本地 v19 已完成,未发布)

- 修正了 PokeAPI 语言代码实际为小写 `zh-hans` 的兼容问题;PokeAPI 优先命中 955 个缺口,52poke 再补剩余。
- v19 最终 **2090/2130** 有中文说明(新增 1549);机器道具通过 PokeAPI machine → move 补上可学招式及招式说明;剩余主要是弃用/内部占位/无正式说明对象。
- 生成物:`data/l10n/zh/items_v19_pokeapi_enrichment.json` + `items_v19_enrichment.json`;构建工具:`tools/patch_dex_bundle_v19_items.py`。

### C. TM 图标(本地 v19 已完成,未发布)

- `tools/enrich_tm_icons_v19.py` 用 PokeAPI 当前机器 → 招式 → 属性映射,再下载 52poke 朱紫 18 属性 160×160 图标。
- 230 个 TM 已换成属性图;bundle 内 238 个机器图标从 1 个 hash 变为 **19 个 hash**(18 属性 + 通用兜底)。

### D. 道具图标不全(本地 v19 已完成一轮,未发布)

- 全量 2130 项跑 PokeAPI → 52poke 搜索回退;只在像素面积更大时覆盖旧图。
- 图标覆盖 **967 → 1645**;52poke 成功取得/升级 1240 项,其中 833 张为 160×160。
- 帕奇利兹 417 的经验糖果Ｓ/橙橙果/精通种子/蛀球果全部有本地图;后三个缺口不再空白。

### E. 携带物品

- 用户实测「几个是有的」,基本确认无数据问题;已知 **Mega Dimension 携带物为 0 条**(52poke 无数据)。
- 若再遇具体缺失:需提供 宝可梦名 + 版本 再逐例核对。

### F. 叫声/动图「代数可选」选择器(代码完成,未发版)

- 同行宝可梦选择页现在提供:形态、闪光、动图来源(按世代)、叫声版本/形态及试听。
- 选择 URL/标签写入 `CompanionRepository` 的 SharedPreferences;首页优先使用用户选择,失败再回退自动候选。
- 形态覆盖不能用 1025 这个物种数表示:v19 实际是 803 条形态记录、554 个非默认形态、546 个准确静态形态图。共享物种媒体 ID 的外观形态(如未知图腾字母)固定使用自己的静态图,不会再误借默认形态动图;仅故勒顿/密勒顿 8 个无独立上游图片的骑乘模式回退本体图。
- PokeAPI 提供 latest/legacy 叫声和逐代动图,52poke 媒体目录提供形态叫声。

### G. 媒体目录小尾巴(本地 v19 已完成)

- 5 只缺口(312/973/990/1022/1023)已用固定 PokeAPI HOME + latest cry 直接链接补齐,媒体目录 **1025/1025**;同时修正其简体名。
- PokeAPI `zh-hans` 修复后纠正 476 个名称/编号;最后 6 个英文 slug 由 52poke 页面名/维护者描述兜底。极巨结晶 `★And15` 一类是正式游戏内编号,保留不翻译。
- 美术查看器已移除全局“背面”开关;只有有背面素材的版本卡显示双向箭头,严格在同一图源正/背间切换,不再跨世代 fallback。

### H. 集成测试 / 模拟器截图(未完成)

- `flutter/integration_test/media_verify_test.dart`(直接泵查看器+媒体页,不依赖 app 启动)已写好但**未在设备跑通截图**;`verify_app_test.dart` 修复前完整通过一次,修复后 drive 在模拟器上反复超时/卡死(本会话模拟器进程被环境回收)。
- 三个尺寸(Phone / RG720 / Tablet)截图未完成。

### I. 发布(未做)

- 未 push;建议版本 **0.9.0**(Lite `0.9.0+138`,Offline `0.9.0-offline+139`)。
- 流程:全量测试 → 签名 release 构建(`flutter build apk --release --target-platform android-arm64` + `tools/verify_release_apk.sh`)或走 CI `publish-android-release.yml` → push → tag `v0.9.0` → GitHub Release(说明中**不要**贴 CDN 私链,见 `docs/PERMISSIONS.md`)。

## 3. 用户明确指示 / 偏好(必须遵守)

- **数据类打进 bundle;媒体类除「默认图鉴图 + 道具图标」外全部走在线**(可放自家 CDN,不做离线打包)。
- 逐代 sprite:映射要做对;bundle 只放一份默认图。
- 优先**增量构建/增量发布**,减少全量重建;发布可用本地脚本,不强制 GitHub Actions。
- Linux 掌机已放弃(文档已同步)。
- UI 中文;分类筛选列表与 `categoryZh` 保持同步(`dex_json_reference_page.dart`)。
- 本仓库 AGENTS.md 要求:先读 `docs/AI_CONTEXT.md`;不要发布 CDN URL 到公开文案。

## 4. 关键命令速查

```powershell
# 测试 / 构建
cd flutter
flutter test
flutter build apk --debug --target-platform android-arm64   # 试用包
flutter build apk --release --target-platform android-arm64 # 正式包(签名在 android/key.properties)
..\tools\verify_release_apk.sh build\app\outputs\flutter-apk\app-release.apk

# 增量发布(bundle v19/v20 用;需 wrangler OAuth 已登录)
python tools/patch_dex_bundle_vXX_... --output dist/dex-vXX
python tools/verify_dex_upload_tree.py dist/dex-vXX/upload
python tools/publish_dex_bundle_incremental.py --versions vXX=dist/dex-vXX/upload --base-v5 dist/dex-v(XX-1)/upload

# 模拟器
C:\Users\tito\AppData\Local\Android\Sdk\emulator\emulator.exe -avd TitoDex_Phone_API36  # / RG_720 / Tablet
flutter drive --driver=test_driver\integration_test.dart --target=integration_test\media_verify_test.dart -d emulator-5554
```

## 5. 当前未提交/刚提交状态

- 当前工作区包含逐代 sprite、翻面、媒体选择器、形态防串图、v19 道具数据/图标和测试的整批未提交改动;另有约 1511 条 `data/assets/item-sprites/` 状态行。不要清理或拆掉这些成果。
- 下一台 Codex 的可直接粘贴 prompt:`docs/handoff/handoff-260807-next-codex-prompt.md`。后续优先级改为:形态媒体显式映射与 PokeAPI→52poke 全量缺口审计 → v19 剩余 40 条说明/485 个图标 → 全量验证;截图、APK、发布继续暂缓。
