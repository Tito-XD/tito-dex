# Cloudflare

| 目录 | 用途 | 自动部署分支 |
| --- | --- | --- |
| [`dex-cdn/`](dex-cdn/) | 离线图鉴 CDN Worker（R2 代理） | **`deploy/dex-cdn`** |
| [`journey-assistant/`](journey-assistant/) | 内建可选 Journey 问答的独立 Worker：BGE-M3 AI Search + Dex bundle + Workers AI Qwen + Tavily／DeepSeek 限定搜索 | 独立部署；App 总开关默认关闭 |

**Production:** `https://dex.tito.cafe` · Worker **`tito-dex`** · R2 **`titodex-dex`** · live bundle **v20** on `/v5/`; v0.9.0 Offline embeds the verified v20 archive

Worker 部署说明：[`dex-cdn/DEPLOY.md`](dex-cdn/DEPLOY.md)

图鉴包构建 / R2 上传：[`../docs/CLOUDFLARE_DEX_CDN.md`](../docs/CLOUDFLARE_DEX_CDN.md)

卡关助手的隐私 contract、AI Search 索引和独立部署前置条件：[`../docs/JOURNEY_ASSISTANT.md`](../docs/JOURNEY_ASSISTANT.md)。附加 APK/R2 代理协议见 [`../docs/EXTENSIONS.md`](../docs/EXTENSIONS.md)。它不复用图鉴 CDN Worker 或部署分支。
