# TitoDex 功能路线 — 三批 Phase 计划

> **Status:** Active plan (2026-07-30)。本文取代 `codex/dex-forms` 分支上
> `docs/handoff/FUNCTIONAL_ROADMAP_IDEAS.md` 的 26 项建议：砍到 9 项，分三批。
> 当前状态以 [`AI_CONTEXT.md`](./AI_CONTEXT.md) 为准（最新发布 **v0.8.8**，
> CDN 图鉴包 **v19**，Offline APK 紧凑包 **v14**）。
>
> **并行约束：** 图鉴检索线（体形/颜色/大小/分类检索 + move/ability 资料详情）
> 与道具图鉴线已随 v12 / v0.8.0 落地；体形筛选图标与形态进化链随 v0.8.1 /
> bundle v13 落地。下文「预留」项仍待接线。

---

## 结论回顾

原 26 项中：完全落地 1 项，部分落地 10 项，未做 15 项。砍掉 17 项
（按需资料包、Living Dex 多档、多存档旅程、掌机快捷面板、纠错入口、
P5 剩余 7 条等——理由见各节）。保留 9 项分三批。

三处守则冲突提醒（做之前需显式产品决策）：招式获得规划器、搜索 DSL、
对战队模式均踩 `CLAUDE.md` 的「不扩成 wiki 镜像 / 竞技模拟器」线。

---

## Phase 1 — 接线（不是新功能）

| # | 项 | 状态 | 说明 |
| --- | --- | --- | --- |
| ① | 存档导入自动选游戏版本 | ✅ **已实现** | `gameEditionForSaveGame`（`game_edition.dart`）+ `GameEditionRepository.applyForSaveGame`；显式导入无条件应用并带 flavor（Pearl→dp/pearl），启动重同步只在存档游戏变化时应用，不会打架手动选择 |
| ③ | 离线数据「重新校验」 | ✅ **已实现** | `DexOfflineService.verifyOfflineData()` + Settings 按钮；manifest/catalog/summaries/详情逐项检查，缺图仅提示（在线可回退），缺详情判不健康 |
| ② | 深链接带形态/版本 | ✅ **已实现** | `/dex/:id?form=&version=` 会在详情加载后校验并应用形态与精确版本，无效参数安全回退默认值 |
| ④ | 回退数据标注 | ✅ **已实现** | 形态继承/资料不完整与招式借用来源均会明确标注，不把回退数据显示成当前版本原生资料 |

## Phase 2 — 目标 3：进化链获得规划 + 版本限定（一个版本的主线）

原则：做成 dex 详情「获取」tab 的**第二段**，不做独立页面；
判定全部来自现有 bundle 数据（`obtainLocationsByVersion` + `evolutionChain`），
零新数据源。

| 部分 | 状态 | 说明 |
| --- | --- | --- |
| 逻辑层 | ✅ **已实现** | `features/dex/version_availability.dart`：`versionExclusivity`（配对版本限定判定）、`planChainCompletion`（逐段 catchable / evolve / tradeRequired / breedRequired / unavailable，含生蛋救援与「进化型野生可捕则无需交换」）、`isTradeTriggerZh` |
| 获取 tab 第二段 UI | ✅ **v0.8.5 已发布** | 选择精确版本后显示「能否单版本集齐 + 各阶段获得方式 + 缺口」，DLC 会继承同版本本体遭遇 |
| 进化卡标注 | ✅ **v0.8.5 已发布** | 进化链保留交换锁；版本规划卡补充配对版本限定与每一阶段的捕获/进化/交换/生蛋/不可用状态 |
| 图鉴进度分类 | ✅ **v0.8.5 已发布** | `DexScopeStats.evolutionOrTradeOnly` +「待进化」筛选；使用 APK 内置约 27 KB 的预计算索引，不扫描详情文件、不发逐只网络请求 |
| Bundle 增强 | ✅ **已落地**（检索线，3095ec3） | `EvolutionNode.triggers`：完整 alternatives 结构化（trigger slug / item / heldItem / minLevel / timeOfDay / …），`triggerZh` 保持字节不变。`evolutionRequiresTrade` 已迁移：优先结构化字段（巨钳螳螂式「交换+携带」精确判定，美纳斯式非交换替代路径解锁），旧 bundle 回退字符串匹配 |

`MechanicsProfile` 已在 v0.8.8 落地：alternatives 会按当前
version-group 过滤，美纳斯在 HGSS 不再借用不可执行的美丽度/棱镜鳞片路线。
旧安装 bundle（v11 及更早）无 `triggers` 字段时仍回退字符串判定。

## Phase 3 — 需要基建（一个版本一块）

| 步骤 | 依赖 | 说明 |
| --- | --- | --- |
| 1. 地点反向索引 | ✅ 构建侧已实现 | bundle 已生成 `location_index.json`（`游戏→地点→方式→宝可梦`）；客户端仍坚持只读，不做运行时 invert |
| 2. 结构化地点树 | ✅ v0.8.8 | App 按需加载并按版本显示地点、遭遇方式、宝可梦与捕获完成度；**永远不做交互地图** |
| 3. 存档助手 | ✅ v0.8.8 | Journey card 用轻量地点索引摘要显示附近待捕；Journey 二级页展开附近未捕获、队伍下一阶段进化、配对版本直接遭遇缺口及进化/生蛋/交换补全。无法匹配地点或未选精确版本时明确降级，不猜测结果 |

## 检索线（并行中，不在本计划内但相关）

三点已提给检索线（本文仅记录，不重复实现）：

1. 颜色用**色块多选**不用色名（PokeAPI 无橙色，卡蒂狗在 brown）—— ✅ **v0.8.5 已落地**。
2. 补**相对大小**分档（`heightDm` 已在 summary，三到五档）—— ✅ **v0.8.5 已落地**。
3. 形状/颜色/成长率/栖息地标签统一来源—— ✅ v0.8.8：
   `data/l10n/zh/dex_axes.json` 是唯一人工维护源，Dart fallback 由脚本生成，
   新 bundle 会把中文标签与 slug 一起写入；v19 继续用 APK fallback 兼容。

## 砍掉清单（速查）

按需资料包（重做 CDN 布局，最贵收益最低）· Living Dex 七档 ·
多存档跨版本 · 掌机快捷面板（Search hub 已覆盖）· 纠错入口 ·
搜索 DSL（改为筛选面板补维度）· 招式获得规划器（缩为招式 tab 一行来源）·
P5 剩余娱乐项（最多再挑通关证书一个）。
