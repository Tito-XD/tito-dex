# P2 后续工作：揭示控制器与主题整理

> 2026-09-14：第一轮 Ask 组件拆分已落入源码；版本号仍为 0.9.19+206。
> 当前功能与架构以 [AI_CONTEXT.md](AI_CONTEXT.md) 为准。
> 本文保留两轮边界与验收入口；独立后续事项另行维护。

## 第一轮范围

P1/P3 原始修整先保存为独立基线，再实施 P2。Ask 页面保留请求、版本上下文、
历史落盘、语义揭示和滚动编排。展示组件位于 `flutter/lib/widgets/ask/`：

| 文件 | 职责 |
| --- | --- |
| `ask_paper_style.dart` | Ask 纸面样式；纸色引用 `AssistantSurface.paper` |
| `ask_connection_status_card.dart` | 连接状态、上下文标签及能力弹层 |
| `ask_history_sheet.dart` | 历史面板与操作选择 |
| `ask_conversation.dart` | 空状态、问题气泡、输入框 |
| `ask_answer_text.dart` | Markdown、内联文字与两种光标组件 |
| `ask_answer_blocks_view.dart` | 答案块、流式澄清和候选按钮 |
| `ask_answer_card.dart` | 实时/历史回答卡及证据展开动画 |
| `ask_answer_sources.dart` | 证据摘要、来源弹层与 URL 校验 |
| `ask_entity_links.dart` | 实体解析入口、跳转和标签动画 |

数据层 `features/journey/ask_titodex_answer_blocks.dart` 公开原有正文、列表和表格
解析函数，供协议投影校验和 UI 共用。正文仍是权威内容；未更换 Markdown 规则，
也未改变 `items` / `rows` 的有效性校验或回退优先级。

三个公共入口继续从 `pages/ask_titodex_page.dart` 导出：
`AskTitoDexPage`、`AskTitoDexSourceOpener`、`buildAskTitoDexClarificationQuestion`。
组件不反向导入页面。Key、导航路径、动画时长、字数上限和三主题差异保留。
实时卡和历史卡仍独立；两种光标、证据展开与实体标签动画原样搬移，未合并。

第一轮还修复了 P1 按需轮询的路由边界：设置总览被子页覆盖时，共享下载可能
开始或结束。总览恢复为当前路由后重新读取进度和缓存，空闲时仍不轮询。

## 验收入口

```sh
cd flutter
flutter analyze --no-pub
flutter test --no-pub
```

- `ask_titodex_stream_protocol_test.dart`：正文权威、投影回退、语义重置。
- `ask_titodex_stream_ui_test.dart`：逐步展示、澄清、旧请求失效、阅读位置。
- `ask_titodex_motion_integration_test.dart`：原有动效及新增的打字中途后台/
  路由遮挡恢复、减少动画开关和光标重新闪烁。
- `ask_titodex_test.dart`：来源、历史、连接和实体交互。
- `settings_download_route_test.dart`：返回设置后的下载进度、完成、取消、
  已在后台完成的缓存刷新，以及下载结束后停止轮询。
- `app_l10n_parity_test.dart`：保留 P1/P3 文案键一致性检查。

基线与整合结果、模拟器验收以本次实际执行记录为准。Widget 测试不能代替
物理设备的帧率、签名升级和发布验收；本轮不产生公开发行版本。

## 第二轮 A：语义揭示控制器（源码已实施，未发布）

`AskTitoDexRevealController` 已接入页面。控制器只负责答案块队列、阶段显示
时长、逐字推进、语义重置和取消；页面继续拥有服务调用、版本上下文、历史、
导航和滚动。不要按原文件行号把整个页面状态塞进控制器。

- 请求身份必须保持统一，覆盖网络回包、揭示队列与历史写入；不能在页面和
  控制器里建立互不相干的“当前请求”。
- 控制器不持有 `BuildContext` 或 `ScrollController`；页面传入减少动画偏好，
  并保持原有读取时机。控制器状态通知仍驱动现有滚动策略。
- 保留 20ms 揭示间隔、112 步预算、96ms 光标停顿和 150ms 阶段下限。
- 先验证重置、最终答案替换、切版本/新请求/销毁后的旧任务失效，再搬逻辑。
  字符分段、计时及最终结果处理都需要原有页面测试继续覆盖。
- 打字节奏、取消语义或其他可见行为修正应独立于机械抽离。

## 第二轮 B：主题整理（限定范围已实施，未发布）

本轮仅统一 Ask 历史/来源行的同构边框圆角，以及实时/历史回答卡的默认纸色。
三主题 × 手机/掌机尺寸 × 深度开关的 12 组合、36 张前后测试截图一致；
测试字体截图用于回归比较，实际展示仍以模拟器/设备为准。

先选确实一致的少量组件合并规则，按组件语义保留必要差异。
队伍头像与伙伴定位头像虽然都是三主题分支，Flat 描边、Plastic 透明度仍不同；
不能仅凭代码形状相似就使用相同默认值。

优先复用 `StickerCard`、`AssistantSurface` 等已有组件，暂不引入全站万能装饰器。
抽出的样式要对照 Journal/Plastic/Flat、深度开关、手机/掌机尺寸；
保留描边、透明度、阴影层级、裁剪和点击反馈。

第二轮结论已合并到 `AI_CONTEXT.md`；本文保留验收边界及独立后续事项，
不作为当前版本和实际发布状态的替代记录。
