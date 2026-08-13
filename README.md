**简体中文** | [English](README.en.md)

# TitoDex

**TitoDex** 是一款温暖、离线优先的宝可梦**旅程助手**，面向 Android 掌机与手机。它把存档进度、队伍与旅程管理、全国图鉴 1–1025、中文资料和轻量对战工具装进一套紧凑、有掌机感的界面。

它希望让你每次回到旧存档时都能马上接上旅程：知道停在哪里、队伍里有什么、下一步该抓谁或进化谁，并快速打开对应资料。TitoDex 不打算替代完整社区 Wiki 或竞技模拟器，而是专注于实际游玩时最常用的信息。

| 渠道 | 版本 | 说明 |
| --- | --- | --- |
| Lite APK | [v0.8.13](https://github.com/Tito-XD/tito-dex/releases/tag/v0.8.13) · App `0.8.13+158` | 内建旅程助手，不再要求安装第二个 APK |
| Offline APK | [v0.8.13](https://github.com/Tito-XD/tito-dex/releases/tag/v0.8.13) · App `0.8.13-offline+159` | 内置紧凑 v14 图鉴数据与旅程助手 |
| Journey Assistant | 主 App 内建 | 首版审核三条 HGSS 卡关链路；旧 1.0.0 附加包仅保留兼容 |

> 名为 `TitoDex-1.0.x-*` 的旧附件属于已冻结的 Flutter 之前原型，仅保留作历史记录，并不比当前 0.8.x 版本更新。

图鉴数据：在线包 **v19** / Offline 内置紧凑种子 **v14** · 1025 个物种 · 803 条形态记录 · 静态、动态、闪光与叫声媒体已审计 · 道具中文说明和图标完整。

> **非官方声明：** TitoDex 是非商业、仅面向学习与个人游玩辅助的工具，与 Nintendo、Creatures、GAME FREAK、The Pokémon Company 及其关联公司不存在隶属、授权、赞助或认可关系。相关名称、角色、图像、音频与商标归各自权利人所有。完整来源、许可与媒体 Credits 见 [CREDITS.md](CREDITS.md)。

## 当前亮点

- **旅程首页**：显示当前游戏、地点、队伍、徽章、游玩时间与常用入口。
- **存档助手**：给出当前位置附近未捕获、队伍进化路线、成对版本可直遇缺口，以及进化／孵蛋／交换补全建议。
- **问 TitoDex**：旅程助手与三条 HGSS 审核资料直接内建主 App，不再安装第二个 APK；优先用已解析存档和本地资料模糊匹配，未唯一命中时才调用 BGE-M3 AI Search 与免费额度内的 Workers AI Qwen。Search 展示可在设置中选大/紧凑/隐藏；绝不上传原始存档或训练家、队伍资料。
- **存档联动**：绑定一个 `.sav` 文件并保留读取权限；实验性识别 Gen 1–7 元数据，HGSS 会同步队伍、昵称、携带道具、招式与 PP、特性、经验、亲密度、性格、闪光、IV／EV、战斗能力、地图／坐标、资金、训练家资料、城都／关都徽章区与图鉴进度。
- **全国图鉴 1–1025**：支持形态搜索、地区或 G1–G9 范围、体形／颜色／大小等组合筛选、形态进化链、精确游戏与 DLC 获取方式、招式、特性和形态媒体。
- **地点图鉴**：按所选版本用紧凑网格查看地点与完成度，弹窗优先列出未捕获并可直达图鉴。
- **资料中心**：招式、特性、性格、蛋群、道具、天气、场地和异常状态；道具可用性与价格、招式和机制会跟随所选游戏与世代。
- **队伍辅助**：队伍页展示招式、特性与下一阶段进化，可将成员和攻击招式直接带入伤害速算。
- **对战工具**：属性克制、能力值与伤害估算、队伍盲点，以及特性、道具、天气、场地、异常状态和太晶修正；计算假设会明确展示。
- **Pokémon Sleep 小工具**：搜索资料页内置睡眠分数与料理基础能量试算，支持跨午夜时长、19 种食材、1–70 级食谱倍率与固有加成；公式固定追溯到 Neroli’s Lab 提交并随包提供 Apache-2.0 许可证。
- **Android 快捷入口**：长按 App 图标默认显示“图鉴 + 搜索”，可在设置中自定义至多三个二级功能。
- **原生应用联动**：选择已安装的模拟器或游戏应用，从 TitoDex 快速继续游玩。
- **离线优先**：可下载带中文标签、地图、配置和图标的图鉴数据；Offline 版本首次启动直接准备已验证的本地种子。
- **掌机布局**：覆盖手机、平板、方屏掌机与手柄焦点导航。

## 产品原则

1. **快速继续旅程**：先展示继续游玩真正需要的信息。
2. **尊重游戏上下文**：资料与机制跟随所选版本和世代。
3. **离线可用**：优先使用本地存档、缓存数据和随包兜底资源。
4. **保持聚焦**：提供实用深度，不复制完整 Wiki。
5. **适配不同设备**：兼顾 Android 手机和紧凑掌机屏幕。

## 技术栈

| 层级 | 方案 |
| --- | --- |
| App | **Flutter + Dart**（`flutter/`） |
| 路由 | `go_router`：首页、队伍、旅程、图鉴、搜索、设置 |
| 持久化 | `shared_preferences` + 本地 `dex_offline/` |
| 存档 | 单文件 URI + Gen 1–7 元数据识别；HGSS 队伍／地图／图鉴解析 |
| 图鉴数据 | 预构建 v19 数据包，带 v5 → v4 → v3 → v2 回退与 APK 内置兜底 |
| UI 语言 | 简体中文 |

详细说明：[架构](docs/ARCHITECTURE.md)

## 安装

前往 [GitHub Releases](https://github.com/Tito-XD/tito-dex/releases) 下载 **`TitoDex-0.8.13-lite-rg-arm64.apk`** 或 **`TitoDex-0.8.13-offline-rg-arm64.apk`**。两个版本都面向 arm64-v8a Android 设备。v0.8.13 已轮换 Android 签名；从 v0.8.12 或更早版本升级时，请先导出旅程、卸载旧版，再安装本版。

- **Lite**：推荐，安装包更小，需要时可在设置中下载离线数据。
- **Offline**：内置同一套核心数据，首次启动会准备随包数据，适合网络不稳定的设备。

如果 Android 提示与本地 Debug 包签名冲突，请先卸载 Debug 包再安装正式版。

## 开发

```bash
cd flutter
flutter pub get
flutter test
flutter run              # 真机 / 模拟器
flutter run -d chrome    # 功能有限的 Web 预览
```

构建与发布：[docs/RELEASE_BUILD.md](docs/RELEASE_BUILD.md)

维护者资料：[图鉴数据包与 CDN](docs/CLOUDFLARE_DEX_CDN.md) · [仓库权限](docs/PERMISSIONS.md)

## 文档

| 文档 | 内容 |
| --- | --- |
| [AI 上下文](docs/AI_CONTEXT.md) | 当前版本、功能状态、架构和维护约束 |
| [路线图](ROADMAP.md) | 发布历史与后续方向 |
| [架构](docs/ARCHITECTURE.md) | 技术选型、数据流与平台边界 |
| [旅程卡关助手](docs/JOURNEY_ASSISTANT.md) | 存档优先模糊匹配、隐私 contract、AI Search/DeepSeek 与部署闸门 |
| [旧 Android 附加包兼容](docs/EXTENSIONS.md) | 1.0.0 兼容协议与迁移到主 App 内建资料的说明 |
| [Flutter App](flutter/README.md) | App 开发说明 |
| [设计系统](docs/DESIGN_SYSTEM.md) | 视觉、字体、布局与交互规范 |
| [发布构建](docs/RELEASE_BUILD.md) | APK 构建和校验清单 |
| [Release Notes](docs/RELEASES.md) | 中文优先的发布文案规范与历史 |
| [数据来源与 Credits](CREDITS.md) | 数据、媒体、开放许可与非官方声明 |
| [第三方许可证](THIRD_PARTY_NOTICES.md) | 随包字体、图标、依赖 notices 与权利边界 |

## HGSS 测试存档

仓库内置 `PKMSS.sav` fixture，用于解析和导入测试。预期可读出 3 枚徽章、满金市，以及包含火岩鼠和波克比的队伍。

```bash
python3 tools/probe_hgss_save.py fixtures/PKMSS.sav
```
