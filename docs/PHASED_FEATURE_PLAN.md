# TitoDex 功能路线 — 三批 Phase 计划

> **Status:** Active plan (2026-07-30)。本文取代 `codex/dex-forms` 分支上
> `docs/handoff/FUNCTIONAL_ROADMAP_IDEAS.md` 的 26 项建议：砍到 9 项，分三批。
> 当前状态以 [`AI_CONTEXT.md`](./AI_CONTEXT.md) 为准（最新发布 **v0.8.2**，
> CDN 图鉴包 **v13**，Offline APK 紧凑包 **v14**）。
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
| ② | 深链接带形态/版本 | 🔒 **预留** | `/dex/:id` 加 `?form=&version=`。检索线要往列表/URL 塞筛选状态，query-param 方案必须一起定，等检索线收口 |
| ④ | 回退数据标注 | 🔒 **预留** | 只暴露 `dataCompleteness` 的「来自相邻版本」语义，不做四元组。落点 `pokemon_detail_sections.dart` / `dex_reference_detail.dart`，后者检索线正在改 |

## Phase 2 — 目标 3：进化链获得规划 + 版本限定（一个版本的主线）

原则：做成 dex 详情「获取」tab 的**第二段**，不做独立页面；
判定全部来自现有 bundle 数据（`obtainLocationsByVersion` + `evolutionChain`），
零新数据源。

| 部分 | 状态 | 说明 |
| --- | --- | --- |
| 逻辑层 | ✅ **已实现** | `features/dex/version_availability.dart`：`versionExclusivity`（配对版本限定判定）、`planChainCompletion`（逐段 catchable / evolve / tradeRequired / breedRequired / unavailable，含生蛋救援与「进化型野生可捕则无需交换」）、`isTradeTriggerZh` |
| 获取 tab 第二段 UI | 🔒 预留 | 「本版本能否独立集齐这条链 + 缺口在哪」卡片；等检索线对 detail 页的改动落地 |
| 进化卡标注 | 🔒 预留 | `pokemon_card.dart` 正在检索线上改进化条件展示，标注（交换锁/版本缺失徽标）合并进去而不是再改一层 |
| 图鉴进度分类 | ⏳ 随后 | 「仅缺交换/进化」计数挂在 `DexScopeStats` 上，直接消费 `ChainCompletionPlan` |
| Bundle 增强 | ✅ **已落地**（检索线，3095ec3） | `EvolutionNode.triggers`：完整 alternatives 结构化（trigger slug / item / heldItem / minLevel / timeOfDay / …），`triggerZh` 保持字节不变。`evolutionRequiresTrade` 已迁移：优先结构化字段（巨钳螳螂式「交换+携带」精确判定，美纳斯式非交换替代路径解锁），旧 bundle 回退字符串匹配 |

剩余限制：alternatives 中的非交换替代路径（如美纳斯的美丽度升级）按可达处理，
但它是否在**当前版本**可用（HGSS 无华丽大赛）属于 MechanicsProfile 的范畴，
待 P0-4 收敛时精确化。旧安装 bundle（v11 及更早）无 `triggers` 字段，
自动回退字符串判定，无需强制重下。

## Phase 3 — 需要基建（一个版本一块）

| 步骤 | 依赖 | 说明 |
| --- | --- | --- |
| 1. 地点反向索引 | 🔒 `build_dex_bundle.py` 空闲 | **构建侧**生成 `游戏→地点→方式→宝可梦` 索引写进 bundle，客户端只读；不做运行时 invert（会拖启动，v0.5.0 预计算方向一致） |
| 2. 结构化地点树 | 依赖 1 | 地点页 = 树 + 完成度；**永远不做交互地图**（素材无底洞） |
| 3. 存档助手 | 依赖 1 + Phase 2 | 卡片按存档数据分级自动显隐，**不等存档全覆盖**：版本缺失卡（全部 14 格式）→ 阶段可获得/进化线卡（Gen1/2/4 共 7 种有徽章）→ 队伍提醒卡（Gen4 两线有队伍）→ 附近未捕获卡（HGSS 有 mapId）。徽章→进度解锁是每游戏一张人工小表，不是解析问题 |

## 检索线（并行中，不在本计划内但相关）

三点已提给检索线（本文仅记录，不重复实现）：

1. 颜色用**色块多选**不用色名（PokeAPI 无橙色，卡蒂狗在 brown）。
2. 补**相对大小**分档（`heightDm` 已在 summary，三到五档）。
3. `SHAPE_ZH`/`COLOR_ZH` 的中文标签直接写进 bundle summary，
   避免 Python/Dart 两份映射（同 `AI_CONTEXT.md` 道具分类同步的坑）。

## 砍掉清单（速查）

按需资料包（重做 CDN 布局，最贵收益最低）· Living Dex 七档 ·
多存档跨版本 · 掌机快捷面板（Search hub 已覆盖）· 纠错入口 ·
搜索 DSL（改为筛选面板补维度）· 招式获得规划器（缩为招式 tab 一行来源）·
P5 剩余娱乐项（最多再挑通关证书一个）。
