# Cloudflare

| 目录 | 用途 | 自动部署分支 |
| --- | --- | --- |
| [`dex-cdn/`](dex-cdn/) | 离线图鉴 CDN Worker（R2 代理） | **`deploy/dex-cdn`** |
| [`journey-assistant/`](journey-assistant/) | 附加 APK 的可选 HGSS 在线检索与 R2 内容代理：BGE-M3 AI Search + Workers AI 默认 / DeepSeek 显式试用 | v0.8.13 已部署；审核索引已启用，DeepSeek 关闭 |

**Production:** `https://dex.tito.cafe` · Worker **`tito-dex`** · R2 **`titodex-dex`** · live bundle **v19** on `/v5/` (v14 compact Offline seed)

Worker 部署说明：[`dex-cdn/DEPLOY.md`](dex-cdn/DEPLOY.md)

图鉴包构建 / R2 上传：[`../docs/CLOUDFLARE_DEX_CDN.md`](../docs/CLOUDFLARE_DEX_CDN.md)

卡关助手的隐私 contract、AI Search 索引和独立部署前置条件：[`../docs/JOURNEY_ASSISTANT.md`](../docs/JOURNEY_ASSISTANT.md)。附加 APK/R2 代理协议见 [`../docs/EXTENSIONS.md`](../docs/EXTENSIONS.md)。它不复用图鉴 CDN Worker 或部署分支。
