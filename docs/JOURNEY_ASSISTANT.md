# 问 TitoDex / 旅程卡关助手

> 状态：v0.8.19 172/173 保留首次明确同意后才开启的边界，并将连接、问答记录与游戏版本收成三个独立入口；本机最近 50 组问答可手动压缩或清空，同游戏最近 6 组用于追问。回答采用浅色对话底板、无外框 Companion、柔和生成动效，并以安全富文本排版标题、强调、列表与可横向滚动表格；引用 URL 只在聚合来源面板内按需展开，实体仍以精灵球／背包／星星／闪电 Chip 跳转。多个百科／攻略站继续合并为一项连接能力，Tavily 与 DeepSeek V4 Flash 保持并行宽范围试用；中文 Tavily 检索先尝试 52Poké，证据为空或未通过核验时再回退其他限定来源。助手与 HGSS 审核种子仍直接内建，旧 Journey Assistant 1.0.0 只保留读取兼容。

“问 TitoDex”是可选的存档优先卡关助手。主 APK 内建上下文能力和三个 HGSS 审核链路，但整个功能默认关闭；用户必须先在设置中确认联网、AI 检索和最近对话上下文说明，Journey／Search 才会出现入口。关闭时不预留入口位置，也不发起健康检查或问答请求。开启后仍然本地优先，并可再单独关闭在线回答。在线审核库增加了 DPPt、BW/BW2、XY、ORAS、SM/USUM、SWSH、BDSP、传说阿尔宙斯和朱紫的少量关键卡点，但仍不是完整流程攻略，也不会把“能识别版本”误写成“已经解析所有剧情进度”。

## 匹配顺序

```text
已解析存档 / 用户所选版本
  → 明确标注字段可靠性
  → 主 APK 内建审核资料：地点、阻塞对象、别名的确定性模糊匹配
      → 唯一命中：完全本地回答
      → 未命中 / 并列：可选 Worker
          → 宝可梦／道具／招式／特性问题先从现有 Dex R2 bundle 读取结构化事实
          → 精确版本遭遇、携带物与招式表直接回答
          → 开放式培养／攻略／路线问题：bundle 事实 + 固定来源 + Tavily 中文 52Poké 优先、其余来源回退
          → AI Search（BGE-M3 hybrid/RRF）只召回候选 hintId
          → 只接受本地审核白名单中的 hintId
          → 默认 Workers AI 只做候选分类/段落排序
          → 审核库仍未命中：严格范围门禁后限定查询 PokéAPI / StrategyWiki / Wikidata
          → 结构化进化/招式可先按当前版本确定性提取
          → Tavily／固定来源与 DeepSeek V4 Flash 原生限定搜索并行，避免串行超时
          → Qwen 优先根据 bundle 与白名单片段生成并做第二遍事实支持核对
          → Tavily／固定来源与 DeepSeek 都成功时，再由 Qwen 判断核心事实是否独立印证且无版本冲突
          → 宽范围试用模式下，若第二遍核对失败但已有固定域名来源，降为低置信度而非直接丢弃
          → 两路都失败才澄清或 no_match
```

存档信息优先级高于用户选择。请求会分别标注：游戏是 `save_verified` 或 `user_selected`；地点是 `save_verified` 或 `unknown`；徽章是精确 ID、仅数量或未知；里程碑是已验证或当前解析器不支持。仅有徽章数量时绝不推断具体徽章，未解析关键道具/剧情 flag 时也不会用常识补全。

当前在线审核记录共 17 个卡点，覆盖 HGSS、DPPt、BW/BW2、XY、ORAS、SM/USUM、SWSH、BDSP、传说阿尔宙斯与朱紫；其中 SM 与 USUM、DPPt 与 BDSP 都按精确版本分开建模。权威文件是 [`data/journey/progression_hints.json`](../data/journey/progression_hints.json)；主 APK 仍只内建三个 HGSS 离线链路，Worker 检索文档从完整权威文件生成。schema 与来源规则见同目录及根目录 [`CREDITS.md`](../CREDITS.md)。

## 数据供应链闸门

未来全版本资料不会批量复制百科或攻略正文。自动导入白名单只有固定提交的
PokeAPI/api-data 与固定 revision 的 Wikidata 结构化数据；百科页面只用于人工
核对事实。流程提示必须由 TitoDex 贡献者重新写成短小的原子事实，保留精确
source revision、许可和审核记录。52Poké/Bulbapedia 的原文、图片、音频不得
进入 AI Search 或 embedding。只允许 Tavily／DeepSeek 返回的有界引用片段在单次
问答中瞬时使用；Bulbapedia 与 52Poké 必须分别显示 CC BY-NC-SA 2.5 / 3.0 改写标记。

即时限定来源回答与审核数据供应链分开：Worker 可在审核库未命中后查询
PokéAPI REST v2 的结构化实体、StrategyWiki 的最新 revision 与 Wikidata 的
CC0 实体搜索，随后由 Workers AI Qwen 只根据这些有界资料生成明确标为“未经
TitoDex 人工审核”的回答。精确招式数值会根据所选游戏的 version-group 与
`past_values` 在来源层先行解析；Qwen 组成必须先确认资料直接支持问题，并经过
第二次事实支持核对。开放式培养／攻略／路线／推荐问题可显式开启 Tavily，先用
中文问题单独查询 52Poké，并把返回域名再次限制为 `wiki.52poke.com`；只有资料为空
或组成／核验不能支持答案时，才对其余允许站点执行中英文回退查询。正常模式仍要求两个独立证据组；
v0.8.16 的明确试用开关允许已有一个固定域名证据组时返回低置信度答案，而不是静默
丢弃，并在界面展示试用警告。窄问题则仅在固定来源仍无法支持时调用。Tavily 只对
Pokémon.com、Bulbapedia、Serebii、StrategyWiki、PokéAPI、Pokémon Database、52Poké wiki、
Smogon、Marriland、GameFAQs、Game8、IGN、Nintendo Life 与 Eurogamer
做有界 `basic` 搜索。Tavily 不生成答案、不返回页面全文，其短片段仍必须通过同一遍 Qwen
组成与第二遍事实支持核对。Worker 不接收客户端或模型给出的 URL/域名，也不会
把即时回答自动写入 R2。PokéAPI 实体优先由 App 已有的中文宝可梦／招式／道具／
特性／地点紧凑目录确定性映射；StrategyWiki 若拒绝 Cloudflare 出站请求则跳过，
不影响其余来源和本地回退。52Poké仍保留为未来人工事实核对与 source-lock 来源；
Worker 不直接抓取其页面正文，Tavily 摘要也不持久化。未取得额外授权时，不得将它们
索引到 AI Search、写入 R2 或打包进 APK。经过重新表述、固定
revision、许可检查和人工复核后，优质事实才可在后续版本进入审核 R2 索引。

最小供应链骨架位于：

- `data/journey/sources/source_registry.json`：来源、许可、允许用途和读取模式；
- `data/journey/sources/source_lock.json`：固定 commit/revision、permalink
  与内容摘要；所有已审核提示都锁定到明确 oldid；
- `data/journey/packs/*/facts.json`：按游戏组保存 TitoDex 原创事实，不包含
  百科正文，并通过发布模式的修订与审核核对；
- 同目录三个严格 JSON schema 和 `tools/validate_journey_fact_pack.py`。

维护模式允许检查待迁移资料；发布模式要求真实 revision/摘要及至少一名审核者：

```bash
python3 tools/validate_journey_fact_pack.py
python3 tools/validate_journey_fact_pack.py --release
python3 -m unittest tools.test_validate_journey_fact_pack
```

只有 `approved` 的事实可以标记 `allowedForAiIndex: true`。结构化导入必须来自
允许 `structured_data` 的来源；文字改编必须来自允许 `text_adaptation` 的来源；
原创事实只能引用允许 `fact_check` 的 revision lock。这个闸门不改变现有
`progression_hints.json` schema；AI Search 文档构建会先强制执行
release gate，并要求审核事实与 hint ID 完全一致。

## 内建入口与旧附加包兼容

首次同意并开启总开关后，Journey 才提供问答入口；Search 为通用/非存档入口提供“大入口 / 紧凑 / 隐藏”三档，默认紧凑。总开关默认关闭，升级安装也不会继承旧版短暂存在的默认开启状态；关闭时两个页面都不构建助手入口或占位。设置页在首次开启时展示联网、AI／检索、最近对话上下文和不上传字段的说明，确认后才同时开启助手与在线回退；之后可单独关闭在线回答，或关闭整个助手。不再下载、安装或卸载第二个 APK。

主 APK 始终携带审核资料，Android 包管理器或 ContentProvider 状态不会阻止离线问答。若设备已经安装旧 Journey Assistant 1.0.0，主 App 仍会按同签名、固定 provider、manifest size/SHA-256 校验读取；读取失败立即回退内建资料。旧协议见 [`EXTENSIONS.md`](./EXTENSIONS.md)。

未来按游戏下载的资料包应作为 App 数据文件经 Worker/CDN 获取、摘要校验并存入应用私有目录，不再使用可安装 APK；当前主包只离线交付三条 HGSS 审核链路，其余审核卡点经在线 Worker 使用。

## 隐私边界

- 整个助手默认关闭；首次启用前展示联网、AI／检索和字段说明，拒绝时不出现入口。启用后仍可单独关闭在线回答，发送前可移除地点和徽章。
- App 只在本机保留最近 50 组问答，超过时删除最早一组；每次请求最多附带同一游戏最近 6 组问答以理解“那它呢”等追问。
- contract 只允许：240 字问题、最多 12 条严格交替的用户／助手历史消息、游戏/世代、可选规范地点 ID、精确徽章 ID 或数量、支持的里程碑 ID、语言、解析器修订号与可靠性枚举。
- 永不发送原始存档、存档哈希、训练家名/ID/Secret ID、昵称、队伍、资金、坐标、时间线、头像、文档 URI 或硬件标识。
- 匿名随机 App 键只用于限流，清除 App 数据后变化。
- Worker 日志不含问题文本、历史正文和精确地点；AI Gateway 调用关闭 prompt log、cache 与重试。普通模型 JSON 响应上限 16 KiB；DeepSeek 原生搜索为容纳工具续传结果，单次请求最多 18 秒、整条链路最多 26 秒，响应上限 128 KiB，只把回答与重新校验过域名的来源下发 App。

## Cloudflare 选型

- **AI Search + BGE-M3：需要，但保持可选。** BGE-M3 运行在 Cloudflare 托管侧，不塞进 Worker bundle，也不在设备下载模型。它支持中文/多语言 embedding；hybrid + RRF 同时利用别名关键词和语义近似。
- **Dex R2 结构化事实：回答底座与校验层。** Worker 只读现有版本化 Dex bundle 的根 manifest、数值物种详情和固定目录对象，利用宝可梦、进化、属性、能力值、特性、精确版本遭遇、携带物、招式表，以及道具／招式目录。版本遭遇、携带物、版本招式表等明确问题可直接确定性组装；开放式培养、攻略、路线或推荐问题则把当前实体的最多 6,000 字符结构化证据与固定来源、Tavily 联网结果一起交给 Qwen，用 bundle 核对实体、版本和数值，再做第二遍事实支持验证。bundle 命中不等于禁止联网。通用进化条件与招式数值不会覆盖原有的逐版本 PokéAPI 核对路径。对象、路径、大小、实体 ID 与精确游戏 key 全部校验；App 不直连 R2，也不会把朱／紫等成对版本的数据混用。
- **Workers AI Qwen：公共默认。** 唯一本地命中不会调用模型；只有未命中/并列才可能消耗 Workers AI 免费额度，额度或模型失败后返回本地确定性澄清/no_match。
- **免 Key 限定来源：审核库未命中时可选。** `CURATED_WEB_ENABLED=true` 时仅查询 PokéAPI、StrategyWiki、Wikidata；不需要新 Cloudflare 资源或第三方 key。现有每设备 20 次/分钟限流继续生效，不另设每天 5 次上限。范围分类、来源请求或生成任何一步失败都保留原本的本地 `no_match`。
- **Tavily 限定搜索：可选的联网证据层。** 中文问题先发起一组仅允许 52Poké 的查询，并再次校验返回 host；若没有得到可支持答案的证据，开放式培养／攻略／路线／推荐问题才会对其余允许站点发起中英文两组回退查询，窄问题则发起一组混合语言回退。`TAVILY_API_KEY` 必须存为 Worker Secret，且 `TAVILY_WEB_ENABLED=true` 才启用；当前生产配置已在 Secret 就绪后开启。每组 basic search 最多 6 条、短超时、响应字节上限、无重试；额度/网络失败继续其他路径，最终始终输出简体中文。
- **DeepSeek V4 Flash 原生搜索：宽范围试用，与 Tavily 并行。** Worker 固定调用 `custom-deepseek-anthropic` 的 `anthropic/v1/messages` 与 `deepseek-v4-flash`，并显式选择 BYOK 别名 `TitoDex`，缺失时不会回退到 `default`。密钥只保存在 BYOK/Secrets Store，Gateway 身份与 Run token 只保存在加密 Worker Secrets。已确认原生搜索会实际执行，但当前响应常不含 `cited_text`；因此 Worker 会重新校验每个来源域名，有片段时交给 Qwen 复核，没有片段时在 `EXPERIMENTAL_BROAD_ANSWERS=true` 下明确标为低置信度试用答案。若 Tavily／固定来源的主回答也成功，会额外调用一次 Qwen，只判断 DeepSeek 是否对核心事实形成独立印证且没有地点、数值或版本冲突；只有通过才显示 `Qwen × DeepSeek 交叉核对`，正文仍保留主证据链。任何失败仍可由 Tavily + Qwen 或本地确定性结果接管。
- **不使用 Agents SDK / Durable Objects / Queues / Workflows。** 当前是短请求、无会话状态、事实白名单的检索分类，普通 Worker 已足够。

AI Search 只信五个自定义 metadata 字段：`hint_id` text、`audited` boolean、`game` text、`generation` number、`location_id` text。Cloudflare 要求字段名全小写。它返回的 chunk 文本被完全忽略。实例创建时固定 embedding 模型；更换模型要新建实例，不能在原索引上静默改向量维度。

## 已对齐的 Cloudflare 资源与绑定

账户侧资源已创建；源码只记录资源名，不记录 Account ID、密钥或生产 URL：

1. `JOURNEY_CONTENT` → R2 bucket `titodex-journey-content`，只由 Worker 读取；App 不直连 R2。
2. `DEX_CONTENT` → 现有版本化 Dex R2 bucket，只由 Worker 对根 manifest、数值物种详情及固定 `items.json`／`moves.json`／`dex_catalog.json` 路径做有界读取；不会修改或公开 CDN manifest／对象。
3. `JOURNEY_SEARCH_NAMESPACE` → AI Search namespace `tito-dex`；Worker 仅在 `AI_SEARCH_ENABLED=true` 时调用 `.get("titodex-journey-search")` 获取实例。`ai_search` 单实例 binding 只能访问 `default` namespace，因此这里必须使用 `ai_search_namespaces`。实例 embedding 选择 `@cf/baai/bge-m3`，启用 hybrid，并配置上述五个 metadata 字段。
4. `AI` → Workers AI；Gateway ID 固定为 `titodex-journey-assistant`，Worker 通过 `env.AI.gateway(...)` 使用，App 不直连 Gateway。

`CURATED_WEB_ENABLED` 是纯 Worker 开关，不是 binding。当前 App 的响应契约已能
显示通用 `answered`、来源名称与本次实际执行路径。限定来源查询逻辑本身只更新
Worker 即可生效；若要看到连接状态卡、伙伴等待动画及细分路径标签，则需要安装
包含该 UI 的主 APK。PokéAPI、StrategyWiki 与 Wikidata 的公开读取接口都不需要
在 Cloudflare Dashboard 新建资源或保存 Secret。Tavily 不需要 Cloudflare 新资源，但需要将
`TAVILY_API_KEY` 保存为现有 Worker 的加密 Secret，然后再单独开启 `TAVILY_WEB_ENABLED`。

进入“问 TitoDex”时，App 会读取 Worker 的 `/health`，显示 Worker、Workers AI
Qwen、AI Search 与限定来源的配置状态。通用 `webSearch` 和
`webSearchProviders` 会分别显示已配置的 `tavily` 与 `deepseek-native`。旧客户端的
`braveSearch: false` 仅保留兼容。后续源码的状态弹窗逐项列出 Worker、Qwen、AI Search、
Dex bundle、合并后的“多个百科来源”和两条联网路径，并显示本机问答数量；完整可能来源及权利说明统一放在 Settings Credits。这个
状态只代表部署配置和 Worker 当前可达，不伪称模型额度或第三方来源一定成功；每条
回答另外显示本次实际走过的 `answerMode`、`modelUsed`、`aiSearchUsed` 与
`sourceKinds`。因此本地唯一命中会显示“本次未调用 Qwen”，太阳伊布等本地审核库
未覆盖的问题若成功使用即时来源，会显示“限定来源 · Qwen 整理”及真实来源；在线
超时／失败则明确显示已回退本地，不再静默伪装成普通 no-match。

确认后的 R2 对象布局：

```text
journey-search/v<datasetVersion>/<hintId>--<game>--<locationId>.md
extensions/journey-assistant/extension-catalog.json  # 仅旧 1.0.0 兼容
extensions/journey-assistant/objects/<immutable-digest-name>.apk  # 仅旧兼容
```

AI Search 数据源只包含 `journey-search/`，不能索引 `extensions/`。当前主 App 只需 `/v1/ask`；旧 catalog 与固定 `objects/*.apk` 路径暂留兼容，但内建助手不会调用它们。

现有 Dex bundle 不复制到 `journey-search/`：精确实体、版本遭遇、携带物和招式表
直接从 `DEX_CONTENT` 读取并确定性组装，优先于联网搜索，也不会消耗 Qwen；开放式
问题抽取当前实体所需的小型证据对象作为联网回答的校验底座，并与固定来源、Tavily
证据共同组成和复核。后续若为口语别名增加派生 AI Search
文档，索引只负责返回候选宝可梦／道具／招式与版本；Worker 仍必须
回读当前 R2 详情对象并重新校验，不能把向量 chunk 文本当作事实答案。这样可复用
已有 bundle，又不会产生两套容易漂移的图鉴数据。

许可边界仍然生效：中文 flavor prose 不进入模型或 embedding；携带物中来自
52Poké 的批次只用于带来源说明的确定性回答，不送给 Qwen／AI Search。攻略回答可
把 PokeAPI／版本 overlay 的结构化字段作为背景，但“某道具能推进剧情”只有在审核
Journey requirement 明确关联时才能成立，不能从“野生宝可梦会携带它”自行推断。

生成待上传的审核检索文档：

```bash
python3 tools/build_journey_search_documents.py /tmp/titodex-journey-search
```

正式上传前检查 `search-upload-plan.json`：每个搜索对象只能带 `hint_id`、`audited`、`game`、`generation`、`location_id` 这五项 custom metadata。R2 metadata 是字符串；AI Search 字段 schema 会把 `audited`/`generation` 转为 boolean/number。确认索引完成后，才在部署配置中把 `AI_SEARCH_ENABLED` 设为 `true`。Tavily 与 DeepSeek 已在各自 Secret/BYOK 和 live smoke 就绪后启用；公共整理仍优先使用 Workers AI Qwen，所有搜索失败都回退到确定性回答。

## 验证与部署闸门

```bash
python3 -m unittest \
  tools.test_progression_hints \
  tools.test_build_journey_search_documents
cd flutter && flutter analyze --no-pub && flutter test --no-pub
cmp data/journey/progression_hints.json flutter/assets/data/journey/progression_hints.json
# 旧兼容包维护时才运行：cd flutter/android && ./gradlew :journey-assistant-pack:check
cd ../../cloudflare/journey-assistant && npm ci && npm run check && npm test && npm run dry-run
```

部署前人工确认：索引只含审核文档；metadata 类型与 filter 命中；Gateway 不收集 prompt；Tavily key 只在 Worker Secret 且 health 不泄露；DeepSeek key 只在 BYOK/Secrets Store；Worker 错误能回退；主 APK 确实包含审核 JSON；RG 与 Android 15 实机确认无需附加 APK即可进入 Journey/Search 问答。

Tavily 与 DeepSeek 原生搜索适配器及回退测试都已准备；当前检入配置同时启用两者，并开启明确标注的宽范围试用策略。真实 Secret 只存在于 Cloudflare 加密配置中。

当前 Worker 启用 AI Search、免密钥固定来源、Tavily 与 DeepSeek，公共整理默认使用 Workers AI。Dex bundle 只读接入不修改 live v19 图鉴 CDN manifest 或对象。生产 URL、Account ID 与密钥不写入源码或文档。官方参考：[AI Search BGE-M3 支持](https://developers.cloudflare.com/ai-search/configuration/models/supported-models/) · [metadata filtering](https://developers.cloudflare.com/ai-search/configuration/retrieval/filtering/) · [R2 data source](https://developers.cloudflare.com/ai-search/configuration/data-source/r2/) · [Tavily Search API](https://docs.tavily.com/documentation/api-reference/endpoint/search) · [AI Gateway BYOK](https://developers.cloudflare.com/ai-gateway/configuration/bring-your-own-keys/) · [Worker binding 限制](https://developers.cloudflare.com/ai-gateway/usage/worker-binding-methods/) · [custom providers](https://developers.cloudflare.com/ai-gateway/configuration/custom-providers/) · [Gateway authentication](https://developers.cloudflare.com/ai-gateway/configuration/authentication/) · [DeepSeek Anthropic API](https://api-docs.deepseek.com/guides/anthropic_api)。
