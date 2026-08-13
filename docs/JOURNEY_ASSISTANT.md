# 问 TitoDex / 旅程卡关助手

> 状态：当前 v0.8.13 158/159 修正版把助手和审核资料直接集成到主 App，不再要求安装附加 APK；旧 Journey Assistant 1.0.0 只保留读取兼容。

“问 TitoDex”是可选的存档优先卡关助手。主 APK 内建存档上下文、入口和审核资料；本地规则无法唯一匹配时，用户还可另行开启在线 AI。第一版事实库只覆盖 HeartGold / SoulSilver 的三个链路，不会把 Gen I–VII 的“能识别存档”误写成“已经解析所有剧情进度”。

## 匹配顺序

```text
已解析存档 / 用户所选版本
  → 明确标注字段可靠性
  → 主 APK 内建审核资料：地点、阻塞对象、别名的确定性模糊匹配
      → 唯一命中：完全本地回答
      → 未命中 / 并列：可选 Worker
          → AI Search（BGE-M3 hybrid/RRF）只召回候选 hintId
          → 只接受本地审核白名单中的 hintId
          → 默认 Workers AI 只做候选分类/段落排序
          → 明确开启时才可试用 DeepSeek，不能作为公共无限兜底
          → 最终文字仍由审核事实组装；失败则澄清或 no_match
```

存档信息优先级高于用户选择。请求会分别标注：游戏是 `save_verified` 或 `user_selected`；地点是 `save_verified` 或 `unknown`；徽章是精确 ID、仅数量或未知；里程碑是已验证或当前解析器不支持。仅有徽章数量时绝不推断具体徽章，未解析关键道具/剧情 flag 时也不会用常识补全。

当前审核记录：36号道路树才怪/杰尼龟喷壶、栎树林大葱鸭/居合斩、满金广播塔地下钥匙/钥匙卡。权威文件是 [`data/journey/progression_hints.json`](../data/journey/progression_hints.json)；主 APK 内建副本由测试强制逐字节一致，Worker 检索文档也从权威文件生成。schema 与来源规则见同目录及根目录 [`CREDITS.md`](../CREDITS.md)。

## 数据供应链闸门

未来全版本资料不会批量复制百科或攻略正文。自动导入白名单只有固定提交的
PokeAPI/api-data 与固定 revision 的 Wikidata 结构化数据；百科页面只用于人工
核对事实。流程提示必须由 TitoDex 贡献者重新写成短小的原子事实，保留精确
source revision、许可和审核记录。52Poké/Bulbapedia 的原文、图片、音频不得
进入 AI Search、embedding 或模型输入。

最小供应链骨架位于：

- `data/journey/sources/source_registry.json`：来源、许可、允许用途和读取模式；
- `data/journey/sources/source_lock.json`：固定 commit/revision、permalink
  与内容摘要；当前三条提示引用的五个页面均锁定到明确 oldid；
- `data/journey/packs/hgss/facts.json`：从现有三条 HGSS 提示迁移出的
  TitoDex 原创事实，不包含百科正文，已完成独立修订核对；
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

Journey 直接提供问答入口；Search 为通用/非存档入口提供“大入口 / 紧凑 / 隐藏”三档，默认紧凑。设置页管理内建助手启停、在线 AI 和 Search 展示方式，不再下载、安装或卸载第二个 APK。

主 APK 始终携带审核资料，Android 包管理器或 ContentProvider 状态不会阻止离线问答。若设备已经安装旧 Journey Assistant 1.0.0，主 App 仍会按同签名、固定 provider、manifest size/SHA-256 校验读取；读取失败立即回退内建资料。旧协议见 [`EXTENSIONS.md`](./EXTENSIONS.md)。

未来按游戏下载的资料包应作为 App 数据文件经 Worker/CDN 获取、摘要校验并存入应用私有目录，不再使用可安装 APK；当前版本只交付随主包的三条 HGSS 审核链路。

## 隐私边界

- 在线 AI 默认关闭；启用前展示联网与字段说明，发送前可移除地点和徽章。
- contract 只允许：240 字问题、游戏/世代、可选规范地点 ID、精确徽章 ID 或数量、支持的里程碑 ID、语言、解析器修订号与可靠性枚举。
- 永不发送原始存档、存档哈希、训练家名/ID/Secret ID、昵称、队伍、资金、坐标、时间线、头像、文档 URI 或硬件标识。
- 匿名随机 App 键只用于限流，清除 App 数据后变化。
- Worker 日志不含问题文本和精确地点；AI Gateway 调用关闭 prompt log、cache 与重试，请求 5 秒超时，响应上限 16 KiB。

## Cloudflare 选型

- **AI Search + BGE-M3：需要，但保持可选。** BGE-M3 运行在 Cloudflare 托管侧，不塞进 Worker bundle，也不在设备下载模型。它支持中文/多语言 embedding；hybrid + RRF 同时利用别名关键词和语义近似。
- **Workers AI Qwen：公共默认。** 唯一本地命中不会调用模型；只有未命中/并列才可能消耗 Workers AI 免费额度，额度或模型失败后返回本地确定性澄清/no_match。
- **DeepSeek：可以接自己的 key，但需双开关显式启用。** 通过 AI Gateway BYOK/Secrets Store 调 provider-native API；App 和源码都不持有 key。它不是无限制公共兜底，失败后先尝试 Workers AI，再回到确定性结果。自托管 OpenAI-compatible 服务先在 Gateway 创建 authenticated custom provider，Worker 只接受 `deepseek` 或 `custom-*` provider 名，不接受任意 URL。
- **不使用 Agents SDK / Durable Objects / Queues / Workflows。** 当前是短请求、无会话状态、事实白名单的检索分类，普通 Worker 已足够。

AI Search 只信五个自定义 metadata 字段：`hint_id` text、`audited` boolean、`game` text、`generation` number、`location_id` text。Cloudflare 要求字段名全小写。它返回的 chunk 文本被完全忽略。实例创建时固定 embedding 模型；更换模型要新建实例，不能在原索引上静默改向量维度。

## 已对齐的 Cloudflare 资源与绑定

账户侧资源已创建；源码只记录资源名，不记录 Account ID、密钥或生产 URL：

1. `JOURNEY_CONTENT` → R2 bucket `titodex-journey-content`，只由 Worker 读取；App 不直连 R2。
2. `JOURNEY_SEARCH_NAMESPACE` → AI Search namespace `tito-dex`；Worker 仅在 `AI_SEARCH_ENABLED=true` 时调用 `.get("titodex-journey-search")` 获取实例。`ai_search` 单实例 binding 只能访问 `default` namespace，因此这里必须使用 `ai_search_namespaces`。实例 embedding 选择 `@cf/baai/bge-m3`，启用 hybrid，并配置上述五个 metadata 字段。
3. `AI` → Workers AI；Gateway ID 固定为 `titodex-journey-assistant`，Worker 通过 `env.AI.gateway(...)` 使用，App 不直连 Gateway。

确认后的 R2 对象布局：

```text
journey-search/v<datasetVersion>/<hintId>--<game>--<locationId>.md
extensions/journey-assistant/extension-catalog.json  # 仅旧 1.0.0 兼容
extensions/journey-assistant/objects/<immutable-digest-name>.apk  # 仅旧兼容
```

AI Search 数据源只包含 `journey-search/`，不能索引 `extensions/`。当前主 App 只需 `/v1/ask`；旧 catalog 与固定 `objects/*.apk` 路径暂留兼容，但内建助手不会调用它们。

生成待上传的审核检索文档：

```bash
python3 tools/build_journey_search_documents.py /tmp/titodex-journey-search
```

正式上传前检查 `search-upload-plan.json`：每个搜索对象只能带 `hint_id`、`audited`、`game`、`generation`、`location_id` 这五项 custom metadata。R2 metadata 是字符串；AI Search 字段 schema 会把 `audited`/`generation` 转为 boolean/number。确认索引完成后，才在私有部署配置中把 `AI_SEARCH_ENABLED` 设为 `true`。DeepSeek 试用时必须同时设置 `AI_EXTERNAL_PROVIDER_ENABLED=true` 与 `AI_PROVIDER=deepseek`；公共默认保持 `false` / `workers-ai`。

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

部署前人工确认：索引只含审核文档；metadata 类型与 filter 命中；Gateway 不收集 prompt；DeepSeek key 只在 BYOK/Secrets Store；Worker 错误能回退；主 APK 确实包含审核 JSON；RG 与 Android 15 实机确认无需附加 APK即可进入 Journey/Search 问答。

v0.8.13 Worker 已使用现有资源名和 binding 部署，六份审核文档已启用 AI Search。主 App 内建相同审核事实；DeepSeek 保持关闭，live v19 图鉴 CDN 不变。生产 URL、Account ID 与密钥不写入源码或文档。官方参考：[AI Search BGE-M3 支持](https://developers.cloudflare.com/ai-search/configuration/models/supported-models/) · [metadata filtering](https://developers.cloudflare.com/ai-search/configuration/retrieval/filtering/) · [R2 data source](https://developers.cloudflare.com/ai-search/configuration/data-source/r2/) · [DeepSeek provider](https://developers.cloudflare.com/ai-gateway/usage/providers/deepseek/) · [custom providers](https://developers.cloudflare.com/ai-gateway/configuration/custom-providers/)。
