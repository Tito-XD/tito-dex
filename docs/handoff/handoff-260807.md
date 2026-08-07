# TitoDex 交接完成记录 — 2026-08-08

> 2026-08-07 的形态媒体与 v19 道具尾项已经在 v0.8.7 收口。本文件保留最终事实和复现入口；当前状态仍以 [`../AI_CONTEXT.md`](../AI_CONTEXT.md) 为准。

## 最终交付

- App：Lite `0.8.7+140`、Offline `0.8.7-offline+141`。
- 数据：生产 CDN bundle v19，继续使用 `/v5/`；Offline APK 保留紧凑 v14 种子，安装后可更新到 v19。
- 本地 0.8.6 的 sprite 预览修复已并入：逐版本图只展示固定 PokeAPI/sprites commit 中真实存在、且不早于物种首发世代的文件；同图源确有背面图时才提供翻面；Android 第一次返回先关闭查看器。
- 同行媒体改为显式 `formKey` 映射，普通/闪光、静态/动图、叫声分别选择和缓存；同 ID 外观形态不会借默认形态动图。

## 形态媒体审计

- 物种：1025。
- 形态记录：803，其中默认 249、非默认 554。
- 554 个非默认形态覆盖：普通静态 548、闪光静态 497、普通动图 386、闪光动图 386、任意叫声 554、形态专属叫声 143。
- 52poke：2116 个唯一原图 URL 通过 `imageinfo` 与实际请求验证；未解析文件 0、失败文件 0。
- PokeAPI：媒体路径固定到 commit `8777f5066431f39fbe07614e0250a61b2029671c`，存在性由 Git tree manifest 验证，不再靠拼 URL。
- 312、973、990、1022、1023 已找到并验证 52poke HOME 图；叫声使用明确的 PokeAPI fallback。
- 机器可读结果：`data/dex/form_media_audit.json`。

仍没有独立普通静态素材的 6 个真实缺口：

- `koraidon-sprinting-build`
- `koraidon-swimming-build`
- `koraidon-gliding-build`
- `miraidon-drive-mode`
- `miraidon-aquatic-mode`
- `miraidon-glide-mode`

这些形态不会用同一张 L 图伪装成六张独立素材。

## v19 道具审计

- 道具：2130。
- 中文说明：2130/2130。
- 本地图标：2130/2130；1057 个唯一 hash。
- 230 个 TM 与 100 个 TR 使用属性模板，bundle 中机器图标共 37 个 hash。
- 显式共享模板 669 项；精确尾项 10 项；通用模板兜底仅 `bw-grass-tablecloth` 1 项。
- 1242 项保留 52poke 原文件来源记录；共享、重复但未分类、唯一但未分类均在审计中单列，不把文件覆盖率误报为独立美术覆盖率。
- 帕奇利兹的 `exp-candy-s`、`oran-berry`、`seed-of-mastery`、`spoiled-apricorn` 均有中文说明与本地图标。
- 机器可读结果：`data/dex/item_media_audit_v19.json`。

## 验证与发布入口

```bash
python3 tools/patch_dex_bundle_v19_items.py
python3 tools/audit_item_media_v19.py
python3 tools/patch_dex_bundle_v19_items.py
python3 tools/verify_dex_upload_tree.py dist/dex-v19/upload
python3 tools/verify_dex_v19_items.py dist/dex-v19/staging

cd flutter
flutter pub get
flutter test --no-pub
flutter analyze --no-pub
```

发布 workflow：

- `.github/workflows/upload-dex-bundle.yml`：以线上 v18 为只读基座构建 v19，只上传变化对象，最后切根 manifest，并保留 v18 回滚 manifest。
- `.github/workflows/android-release-build.yml`：并行构建签名 Lite/Offline APK；v0.8.7 使用 build number 140/141，Offline 复用上个版本的紧凑 v14 种子。

公开 README、GitHub Release 文案不得包含生产 CDN 直链；运维细节见 `docs/PERMISSIONS.md`。
