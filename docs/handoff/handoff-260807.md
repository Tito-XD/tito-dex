# TitoDex 交接文档 — 2026-08-07

> 用途:给下一位评审/接手的模型。按「已完成 / 未完成 / 半成品 / 用户提出过的问题」整理,含关键路径与命令。

## 0. 环境与仓库状态

- 分支 `main`,领先 `origin/main` 约 16 个提交,**未 push**。
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
- App 功能(代码+测试就绪,**尚未发版**):详情美术查看器「背面」切换、Settings 媒体资源管理页、companion 叫声优先 52poke 形态/世代、道具分类 16 组筛选。
- 测试:全量 **332 个通过**(含背面查看器、sprite 映射、媒体目录模型测试);手机 AVD 上完整 integration 冒烟**在修复前通过过一次**。

## 2. 未完成 / 半成品 / 需完善(按用户提出顺序)

### A. 逐代 sprite 映射(用户重点不满,本次已部分修复)

**现象**:搜索 帕奇利兹(417)/赛富豪(1000)会列出其出生前世代,且各世代图相同(全是默认图)。

**根因**:bundle `summaries.json` 的 `spriteUrlsByVersion` 对每个物种都写入全部 21 个版本组的 CDN `by-version` URL;PokeAPI 对未出生世代也返回 URL,但仓库里没有对应文件,CDN Worker 的 `by-version` 路由回退到默认 sprite → 全一样。

**已修(待提交/待打包)**:
- `flutter/lib/features/dex/sprite_generation_catalog.dart`:`kSpriteVersionGroupMaxId` 全版本组上限表;`spriteEditionOptionsForPokemon` 对两个循环都按上限过滤;黑2白2 无真实图(仓库 404)已只进上限表。
- `tools/build_dex_bundle.py`:`VERSION_GROUP_MAX_ID`,构建 summaries 时过滤未出生世代(下次重建 bundle 生效)。
- 测试:`test/sprite_generation_catalog_test.dart` 新增「Gen IV 物种不出现在 Gen I–III」「Gen IX 物种只保留朱紫组」。

**仍未解决(需要下一步)**:
1. 全国图鉴上限过滤仍不够精确:**地区限定游戏**(LGPE 仅关都、BDSP/LA/SwSh/SV 各有物种子集)需要「物种 × 版本组」真实存在矩阵。建议:逐物种探测 PokeAPI sprites 仓库文件是否存在(约 1025×14 HEAD,可离线跑一次),生成 `sprite_version_existence` 数据,或直接把真实逐代 sprite 拉到自家 CDN 并按存在矩阵提供 URL。
2. 当前逐代 URL 仍指向 `raw.githubusercontent.com`;用户网络曾出现加载失败回退默认(用户建议:bundle 只放默认图,逐代走在线、可上自家 CDN,不做离线打包)。
3. 本次 Dart 修复后的 **APK 尚未重建**;用户手上的旧包不含此修复。

### B. 道具中文简介(用户确认「要补」)

- `items.json` 2130 项中 **1589 项 `descriptionZh`/`effectZh` 为空**(新增的 TM/素材/剧情道具等;原 542 项有简介)。
- 方案:从 52poke「包包信息 / 效果」抓中文简介 → 打 v20 数据补丁 → 增量发布。

### C. TM 图标(用户反馈「看起来都一样」)

- 已确认:`data/assets/item-sprites/` 中 232 个 TM 图标有 **230 个 hash 完全相同**(PokeAPI TM sprite 是通用图)。
- 方案:52poke 按属性的 TM 图标(`Bag_TM_<属性>_SV_Sprite.png` 等),需要 TM 号 → 招式 → 属性映射(v19)。

### D. 道具图标不全(用户反馈「道具图还不全」)

- 2130 项只有 967 张图标;约 33 个下载失败;30 个 LA 物品既无图也无描述。
- v19 一并补(PokeAPI 有则拉,否则 52poke 抓图)。

### E. 携带物品

- 用户实测「几个是有的」,基本确认无数据问题;已知 **Mega Dimension 携带物为 0 条**(52poke 无数据)。
- 若再遇具体缺失:需提供 宝可梦名 + 版本 再逐例核对。

### F. 叫声/动图「代数可选」选择器(下一批 app 功能,用户已确认下批做)

- 现状:companion 自动选形态最优叫声;详情查看器有世代静态图(正/背面);**没有**按世代/形态选择叫声与动图的 UI。
- 要做:选择器 UI + 选择持久化(companion repository / dex settings)。

### G. 媒体目录小尾巴

- 5 只无媒体:負电拍拍 / 纏红鹤 / 铁轍迹 / 鐵磐岩 / 鐵頭殼(52poke 页面无 `{{形象}}/{{叫声}}`)。
- 26 项物品用英文名兜底(未解析到中文)。

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

- 本次(handoff 同批提交):`sprite_generation_catalog.dart` + 测试 + `tools/build_dex_bundle.py` 的映射过滤;handoff 文档本身。
- 待办排序建议:A(存在矩阵/真实 sprite 源)→ C/D(TM 与道具图标)→ B(简介)→ F(叫声/动图选择器)→ H(三尺寸截图)→ I(发布 0.9.0)。
