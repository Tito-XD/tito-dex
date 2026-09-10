# Companion 动画候选清单

接入版本：v0.9.19（2026-09-10）；正式签名制品与发布验证见 [RELEASES.md](RELEASES.md)。沿用现有“同行宝可梦 → 形态／异色 → 动图来源”入口；APK 内置索引，用户确认后才下载所选动画，下载成功才切换同行宝可梦。

## 当前收录与分组

`flutter/assets/data/companion_animation_catalog.json` 包含 1,550 条精确身份／来源／颜色映射：Paraíso 剑盾素材集 1,310 条、究极日月 217 条、ShinyHunters 23 条。涉及 546 个物种、732 个物种与形态组合，**不是全图鉴覆盖**。普通色与异色各是一条记录，少量共享外观也保留各自的形态身份。

- Paraíso 使用来源目录的游戏代际分组；“剑盾素材集”不代表其中每只宝可梦都能在剑盾获得。
- ShinyHunters 的原游戏未逐项确认，归“通用”，不使用宝可梦初登场世代推测。
- ShinyHunters 首批限于已经解码、能够准确绑定的样本；内部编号与全国编号分开处理。静态 PNG、未确认奶油／骑乘／真伪形态的样本不进入清单。
- WikiDex WebM、FurretTurret ZIP 尚未接入；52Poké 保持既有已审计缓存范围。

清单由 `tools/generate_companion_animation_catalog.py` 从研究审计快照生成，不访问网络、不下载媒体、不改动 v20 图鉴包。`pubspec.yaml` 既有 `assets/data/` 声明覆盖该文件，Lite 和 Offline 都可内置。

## 选择与下载行为

候选按游戏代际和来源展示。选中时显示尺寸、下载大小或“已下载”；确认按钮为“下载并使用”或“使用此动画”。浏览列表和选择候选不会请求远程动画，预览使用已缓存动画或静态图。

普通／异色切换会重新筛选候选并清除旧颜色的选择。共用 species ID 的不同形态仍可使用有明确 formKey 的新候选，不会借用默认形态动画。内置御三家也必须下载显式选择的新来源，不能因已有内置小 GIF 而跳过下载。

下载失败保留当前同行宝可梦，并在对话框提供重试；取消会终止网络请求，不保存新选择。重复确认被阻止。保存的旧来源若已不在当前候选里，不能在界面显示“自动”时继续提交旧 URL。

## 验证边界

Paraíso 大部分候选在清单生成时只通过精确身份映射与 GIF 文件头核验。它们是**待用户选择下载的在线候选**，不是已在设备上验证完的动画。为避免预下载整套多 GB 素材，本实现把完整媒体验证放在首次下载阶段；这调整了初期打包方案中“先全量解码再入清单”的要求。

新候选下载时检查 HTTP 状态、实际字节数、GIF 魔数、结束标记、画布尺寸和多帧数量，并用 Flutter 解码器逐帧解码后才提交缓存。已知样本还核对帧数。解码验证以最多 256 px 宽、禁止放大的预览尺寸进行；实际显示仍使用原始文件。下载体积上限 128 MiB，单次网络空闲／响应等待有超时，支持取消。

当前未提供源文件 SHA-256 清单。缓存文件名中的摘要来自资产身份、URL、审计尺寸与字节数，用于区分来源／版本，**不是远程文件的内容校验值**。源站如果替换文件导致尺寸或大小变化，下载会失败，需要重新审计并更新内置清单。

## 缓存与兼容

新候选独立缓存为 `物种编号.animation-摘要.gif`，不与原有 `编号.gif`／`编号.shiny.gif` 混用。下载先写 `.part`，完成验证后再改为正式缓存文件；临时文件不出现在资源列表里。

`CompanionChoice.animationAssetId` 保存新候选身份，已有 URL 选择和“自动”模式仍兼容。清空或切回自动时移除候选 ID。显式新候选重启后只读对应缓存；缓存删除／丢失时使用精确静态图或占位，不在进入主页时自动重下高清动画。大图使用平滑采样。

资源管理页将新缓存显示为宝可梦／形态、游戏／来源与异色标签，可查看大小和删除。在线目录暂不可用时仍保留本地缓存列表。缓存变化会通知主页刷新。

## 代码位置

- `flutter/lib/features/companion/companion_animation_catalog.dart`：懒加载索引、身份匹配、来源标签与缓存身份。
- `flutter/lib/features/companion/companion_media.dart`：流式下载、取消、格式／逐帧验证和独立缓存。
- `flutter/lib/features/companion/companion_repository.dart`：候选 ID 持久化与旧数据兼容。
- `flutter/lib/widgets/companion_picker_sheet.dart`：候选选择、缓存预览、下载确认与重试。
- `flutter/lib/widgets/companion_standby.dart`：显式候选的本地播放、缓存删除刷新和采样方式。
- `flutter/lib/pages/media_resource_page.dart`：可读缓存标签和删除入口。

## 复核命令

```powershell
python tools/generate_companion_animation_catalog.py --check
python -m unittest tools.test_audit_hd_companion_sources -v
cd flutter
flutter analyze --no-pub
flutter test --no-pub
```

真实源验证独立启用，日常测试默认跳过，避免 CI 依赖外站：

```powershell
$env:TITODEX_LIVE_MEDIA_TEST = '1'
flutter test --no-pub test/companion_animation_live_test.dart
```

该测试读取大尾立普通／异色与 Paraíso 火球鼠三个真实文件，经过 App 下载器和逐帧验证，再禁止网络检查缓存读取，最后删除测试临时媒体。它是 Flutter 测试运行器验证，不能代替 Android 真机的持续播放、内存和功耗验收。

## 正式制品记录

v0.9.19 Lite / Offline 已发布，签名与 v0.9.18 一致；清单在正式 APK 中为 551,815 字节，压缩占 66,659 字节。两个包的字体、原有 29 个 Companion GIF 均与 v0.9.18 一致，Offline 复用同一完整 v20 归档。正式源码为 `286474e`，完整制品与 CI 证据见 [RELEASES.md](RELEASES.md)。Android 模拟器冒烟通过，实体设备持续播放与功耗尚未验证。

## 本次验证记录

- `flutter analyze --no-pub`：无问题。
- `flutter test --no-pub`：684 项通过，2 项跳过；其中真实源测试独立启用后通过。
- 审计映射测试 8 项、素材归属元数据测试 4 项通过；生成清单 `--check` 一致。
- 新旧来源缓存混用、已删除来源仍被提交这两个场景均验证了“旧行为失败、修正后通过”的回归测试。
- Android arm64 调试构建通过。APK 内清单为 551,816 字节，压缩后 78,926 字节，约 77.1 KiB；核对 APK 中的清单与工作区逐字节一致。这是清单条目的实际占用，不是整个功能的 APK 增量。
- 独立预览包 `TitoDex Companion Preview` 通过 ZIP CRC、arm64 Flutter 引擎与 APK v2 签名检查；APK 中仍只有原有 29 个内置 Companion GIF。预览文件及校验记录位于 `flutter/build/companion-preview/`，没有发布为正式版本。
- 未连接 Android 设备，未做真机播放或功耗测试。预览构建使用独立 application ID，可与正式版并存；调试版体积不能作为正式版包大小的参考。
