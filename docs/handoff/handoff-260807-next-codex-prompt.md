# TitoDex next-Codex handoff prompt — 2026-08-07

下面整段可直接交给另一台 Codex：

---

你接手的是 TitoDex 仓库。请在当前工作区继续完成 **形态媒体 + v19 数据尾项审计与回补**，不要从头重做，也不要把“全国图鉴物种覆盖”误报为“形态覆盖”。

## 先做的事

1. 先读 `AGENTS.md`、`docs/AI_CONTEXT.md`、`docs/handoff/handoff-260807.md` 和本 prompt。
2. 检查 `git status --short`、`git diff --check`、最近 5 个提交。当前应在 `main`，相对 `origin/main` 领先约 18 个提交，并有大量未提交改动。
3. 这是脏工作区。`.qoder/`、`docs/mockups/` 是用户现有内容，不要修改、删除或清理；不要 reset/checkout 用户改动。
4. 当前用户要继续补功能和数据，**暂时不要截图、不要构建 APK、不要发布 bundle、不要 push/tag/release**。没有明确授权时也不要暴露私有 CDN 地址。

## 用户的明确要求

- 所有缺口都按统一来源顺序重新找：
  1. PokeAPI API / `PokeAPI/sprites` / `PokeAPI/cries` 的真实文件；
  2. PokeAPI 没有时，查 52Poké 的条目、模板、原始文件和 MediaWiki API；
  3. 两边都没有时才保留“无准确素材”，绝不能借默认形态、其他世代或其他形态冒充。
- PokeAPI 的在线媒体适合使用固定 commit 的 raw URL，并在 App 下载后缓存。
- 52Poké 图片不要只保存 `Special:FilePath` 猜测链接；应通过 MediaWiki `imageinfo` 找原图并验证 App 端可访问性。若热链不稳定或有防盗链，按许可和署名要求镜像到 bundle/自有媒体树；不要让 App 依赖会 403 的链接。
- 形态必须逐形态验证。叫声、动图、静态图、闪光图是不同维度，不能用一个总数代替。

## 当前已经完成的代码

- 逐代 sprite 已改为“PokeAPI 固定 Git commit 中真实存在的文件 × 不早于物种首发世代”。生成器：`tools/generate_sprite_version_existence.py`；数据：`data/dex/sprite_version_existence.json`；Dart：`flutter/lib/features/dex/sprite_version_existence.g.dart`。
- 美术查看器不再有全局“背面”开关。只有同一图源真的有背面图时才显示双向箭头，正背只在该图源内部切换，不跨世代 fallback。
- 同行宝可梦选择器已支持形态、闪光、动画来源/世代、叫声版本/形态、试听和持久化。相关文件：
  - `flutter/lib/widgets/companion_picker_sheet.dart`
  - `flutter/lib/widgets/companion_standby.dart`
  - `flutter/lib/features/companion/companion_media.dart`
  - `flutter/lib/features/companion/companion_repository.dart`
  - `flutter/lib/features/dex/online_media_catalog.dart`
- 已修同 ID 形态串图：未知图腾字母等形态与默认形态共享 PokeAPI Pokémon ID 时，不再借默认形态动图，而显示自己的准确静态图；有独立媒体 ID 的形态才走对应动图候选。
- `PokemonFormDetail.summaryFor` 已修复：非默认外观形态自己的 sprite 不会被默认形态 artwork 覆盖。
- 已补常见 52Poké 叫声后缀别名匹配，但目前仍是启发式，后续应换成显式 `formKey -> cry` 映射。
- Settings 媒体资源页、媒体缓存管理、媒体选择标签持久化均已完成。

## 当前本地 v19 候选（未发布）

- 道具：2130。
- 中文说明：2090/2130。
- 本地图标：1645/2130。
- TM：230 个按招式属性映射到 18 种 160×160 图标；bundle 中机器图标共 19 个 hash（18 属性 + 通用兜底）。
- 物种媒体目录：1025/1025；这是“物种条目数”，不是形态数。
- 形态数据：803 条，其中默认形态 249、非默认形态 554。
- 554 个非默认形态中，546 个有区别于本体的准确静态图；8 个尚无独立图：
  - `koraidon-limited-build` (10264)
  - `koraidon-sprinting-build` (10265)
  - `koraidon-swimming-build` (10266)
  - `koraidon-gliding-build` (10267)
  - `miraidon-low-power-mode` (10268)
  - `miraidon-drive-mode` (10269)
  - `miraidon-aquatic-mode` (10270)
  - `miraidon-glide-mode` (10271)
- 228 个非默认形态与本体共享媒体 ID；326 个有独立媒体 ID。
- `media_catalog_52poke.json` 当前有 1643 个形态/HOME 文件记录、1168 条叫声、290 个多图物种、120 个多叫声物种。
- 重要：目录中的 `forms[]` 目前主要只有 `file + kind`，App 没有把这 1643 个文件逐条绑定到 `formKey`。资源页只显示数量；这是下一步的核心缺口。

## 已确认的 52Poké 情况

- 52Poké“形态变化”页面明确列出了故勒顿的制限/完全/疾驰/破浪/乘风形态，以及密勒顿的受限/完整/行驶/浮水/滑翔模式。
- 但是 52Poké `Template:MSP/switch` 将故勒顿四个非战斗形态全部映射为同一个 `1007L` 图示，密勒顿四个也全部映射为同一个 `1008L` 图示。不能把同一张 `L` 图标复制四份并声称四种模式已经分别补齐。
- 继续检查形态页面 wikitext、页面所嵌文件、MediaWiki `imageinfo`、分类文件和可能的官方游戏截图/模型图，确认是否真的存在四个独立视觉素材。若只有一个 L 图，就保留明确 fallback 并在 UI/数据中标注共享，而不是伪造。
- 参考入口：
  - `https://github.com/PokeAPI/sprites`
  - `https://github.com/PokeAPI/cries`
  - `https://wiki.52poke.com/wiki/形态变化`
  - `https://wiki.52poke.com/wiki/Template:MSP/switch`

## 必须继续做的 P0：形态媒体完整审计

1. 从 `dist/dex-v19/staging/details/*.json` 生成机器可读的形态审计表，至少每个 `formKey` 有：
   - species id、pokemon/form media id、中文名、形态类型；
   - PokeAPI 静态图、HOME、official artwork、Showdown GIF、逐代 GIF/PNG 是否真实存在；
   - 普通/闪光是否分别存在；
   - 52Poké 对应文件、原图 URL、形态代码；
   - 52Poké 对应叫声及后缀；
   - 最终选用来源和署名。
2. 不要继续使用“拼出 URL 就算存在”。PokeAPI 必须用固定 commit Git tree/existence manifest验证；52Poké 必须用 API/file metadata + 实际请求验证。
3. 给 `OnlineFormArt`/媒体 catalog 增加显式 `formKey`、可用 URL、来源、普通/闪光、静态/动图等字段，把 52Poké 的 1643 个文件真正接进形态选择器和 fallback 链。
4. 叫声不要只靠 `contains()` 猜 suffix；从 52Poké MSP/媒体文件命名生成显式映射。未知 suffix 仍可手动选择，但自动匹配必须可测试。
5. 对 554 个非默认形态输出最终覆盖矩阵和缺口列表；分别报告静态、动图、闪光、叫声覆盖率，不能只说“1025/1025”。
6. 重新搜索当前用 PokeAPI 临时补尾的 5 个物种是否已有 52Poké 媒体：312、973、990、1022、1023。现在它们由 `tools/patch_dex_bundle_v19_items.py` 写入 PokeAPI HOME + latest cry fallback。

## 必须继续做的 P1：v19 道具尾项

### 中文说明仍缺 40 条

分类：剧情推进 8、携带物 7、玩法 6、招式素材 6、活动道具 5、三明治食材 5、邮件 2、野餐 1。

slug：

`ice-berry miracleberry berry burnt-berry berserk-gene mysteryberry gold-berry auroraticket bead-mail berry-pouch bicycle bike-voucher butter bw-grass-tablecloth cramorant-down dream-mail fame-checker grubbin-thread illumise-fluid jam kofus-wallet koraidons-poke-ball magma-emblem miraidons-poke-ball morpeko-snack mysticticket noodles oaks-parcel old-sea-map pokeblock-case powder-jar rainbow-pass rice ruby sapphire seedot-stem teachy-tv tofu tri-pass vullaby-feather`

逐条先查 PokeAPI 小写 `zh-hans`，再查 52Poké 对应条目的包包信息框/游戏说明。若确实没有官方说明，允许写清楚来源的维护者概述，但不要把英文名或空泛模板当说明。

### 图标仍缺 485 个

- 极巨结晶 300。
- TR 100。
- 招式素材 25。
- 剧情推进 11。
- 野餐 9。
- 营养/糖果 8。
- 三明治食材 7。
- 特定宝可梦糖果 6。
- 战利品 4、超级石 4、太晶碎块 2、咖喱食材 2、玩法 2、活动道具 2，其余零散 5。

现有 `tools/enrich_items_v19.py` 已实现 PokeAPI → 52Poké 搜索和原图下载，`tools/enrich_tm_icons_v19.py` 处理 TM。不要盲目重复全量下载；先生成缺口清单，再对 485 个逐类查 52Poké。极巨结晶/TR 可能天然共用模板图，必须区分“确实共用”与“缺失”。若来源只有共用图，应在数据中显式标记，不要假装 400 张独立图。

## 关键脚本和数据

- `tools/enrich_items_v19.py`
- `tools/enrich_tm_icons_v19.py`
- `tools/patch_dex_bundle_v19_items.py`
- `tools/verify_dex_v19_items.py`
- `tools/test_enrich_items_v19.py`
- `data/l10n/zh/items_v19_enrichment.json`
- `data/l10n/zh/items_v19_pokeapi_enrichment.json`
- `data/l10n/zh/tm_v19_enrichment.json`
- `data/l10n/zh/item_name_overrides_v19.json`
- `data/assets/item-sprites/` 当前约有 1511 条 modified/untracked 状态，不要清理。
- 本地构建产物：`dist/dex-v19/`（ignored，未发布）。

## 帕奇利兹专项回归

`dist/dex-v19/staging/details/417.json` 的四个 LA 携带道具必须一直保持“中文名 + 中文说明 + 本地图标”齐全：

- `exp-candy-s`
- `oran-berry`
- `seed-of-mastery`
- `spoiled-apricorn`

## 当前验证基线

- `flutter test --no-pub`：340/340 通过。
- `flutter analyze --no-pub`：0 issue。
- `python tools/verify_dex_upload_tree.py dist/dex-v19/upload`：通过。
- `python tools/verify_dex_v19_items.py dist/dex-v19/staging`：通过，输出应包含：
  - items 2130
  - descriptionCoverage 2090
  - spriteCoverage 1645
  - machineIconHashes 19
  - mediaCatalogEntries 1025
  - formRecords 803
  - alternateForms 554
  - alternateFormsWithExactVisual 546
- v19 archive 约 60.66 MiB，manifest SHA 与归档一致。

数据或代码每改一轮后至少运行：

```powershell
cd flutter
flutter test --no-pub
flutter analyze --no-pub
cd ..
python tools/verify_dex_upload_tree.py dist/dex-v19/upload
python tools/verify_dex_v19_items.py dist/dex-v19/staging
git diff --check
```

若改了 enrichment 数据，按顺序运行 `enrich_items_v19.py`、`enrich_tm_icons_v19.py`、`patch_dex_bundle_v19_items.py` 后再校验。不要发布。

## 工作区/交付约束

- 不要 stage/commit/push，除非用户明确要求。
- 不要删除 `.qoder/`、`docs/mockups/` 或现有 dev APK。
- 不要把 `dist/dex-v19` 当已上线；生产仍是 v18。
- 任何覆盖数字都必须由脚本实时计算，并把“物种、形态、静态、动图、闪光、叫声”分开报告。
- 完成后更新 `docs/AI_CONTEXT.md`、`docs/handoff/handoff-260807.md` 和本 prompt 的数字、缺口及验证结果。

最终向用户用中文简洁汇报：做了什么、PokeAPI/52Poké 各补了多少、还剩哪些真实缺口、测试结果、是否构建/发布（默认没有）。

---
