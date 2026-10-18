# TitoDex Launcher — 设计与触屏体验交接

更新时间：2026-10-18（Asia/Shanghai）。

## 当前接续状态

- 用户已认可贴纸桌面的方向，并授权原生 Kotlin + Jetpack Compose 重写、系统小组件、APK 覆盖安装。
- 原生迁移与动效已在 `codex/titodex-launcher` 提交。线上动效预览源码为 `db779e51f30c89d5a5705904d013be547df6d04d`；不要把先前“修改尚未提交”的记录当成现状。
- 当前源代码在 `app/src/main/kotlin/com/tito/titodex/launcher/`；Flutter `lib/` 删除是已授权的框架迁移。
- 2026-10-18 接续时，RG Rotate 已安装 0.3.0 / versionCode 4 调试包，默认 HOME 也已是 TitoDex Launcher。旧报告中“尚未安装四项调整”的结论不完整；以设备与源码为准。
- 本轮补齐：横向大字 2×1；用户随后纠正“留白”模板应使用竖向 1×2，新增竖排小时/分钟；日期短写、天气贴纸不显示城市、小时/每日预报；日期与天气不再随整行缩小，天气使用所选城市的时间偏移。
- `0.3.1-motion.1` / versionCode 6 已作为 [GitHub Pre-release](https://github.com/Tito-XD/tito-dex/releases/tag/launcher-v0.3.1-motion.1) 上线并保留数据安装至 RG。原设置和壁纸已备份、恢复及逐文件核对。50 项回归通过，真实触控复测包含编辑返回后再次点开应用库；详见 `VALIDATION.md`。
- 用户进一步反馈竖排时钟间距偏大：改为同一段双行文字，统一控制基线间距，消除独立 Text 的重复字体留白；保持 1×2 网格占位与 16sp 日期/天气。紧凑版 APK 文件名增加 `-compact` 以区分同版本本地预览。
- 用户最新要求：竖排日期与镂空英文星期统一为 16sp、同字体粗细、同基线；保持 `10/18 SUN` 同排和中文星期读屏。1×2 时间按剩余宽高放大，使用等宽数字与稳定测量避免分钟切换时尺寸跳动，并保留日期/天气的空间。此要求取代上一轮限制数字字号的试用方向；时钟调整版 APK 文件名增加 `-clock-fit`。
- 用户澄清 TitoDex 入口应保留 Launcher 专属球形造型和差异化，不要求照搬 App 图标。当前使用 `TitoEmblem`：蓝色上半球、深色下半球、浅色中线与中央圆环；手帐为纸质虚线徽章，塑料为有亮边/厚度的圆形按键，扁平为蓝黑色块圆章及珊瑚色中心。小尺寸、大尺寸与入口菜单统一，固定入口仍打开正式 `com.tito.titodex`；编辑器小尺寸名为「徽章」，持久化 key 不变。此方向取代上一轮方形 App 图标底座，当前 APK 文件名增加 `-emblem`。
- 主应用主题在独立 `codex/theme-refresh` 分支；预览包使用 `com.tito.titodex.themepreview`，不替换正式 `com.tito.titodex`，固定 TitoDex 入口仍指向正式包。
- 构建必须串行，Gradle 堆限制 2 GB、最多 2 workers；不再并行运行两套构建。

以下是最初 0.2 的产品交接记录，保留用于追溯；其中 Flutter 路径、版本和未授权小组件等旧状态不再代表当前实现。

## 目标与验收重点

面向 RG Rotate 等 Android 游戏掌机的独立轻量桌面。保留 TitoDex 的训练家手帐、固态塑料、扁平贴纸三个主题。用户希望每天愿意使用、有辨识度、触屏顺手；基础功能完整是前提。

用户最新明确反馈：现有版本单调、乏味、没有特色，操作不够符合习惯。最不顺手的是 **触屏操作、整理桌面、调整外观**。请优先解决这些流程，保留手柄兼容，不要把本轮重点误解为只优化手柄焦点。

## 必须保留的能力

- Android HOME / DEFAULT 声明与系统默认桌面选择入口。
- 固定快速打开 TitoDex：`com.tito.titodex`；Launcher 独立包名：`com.tito.titodex.launcher`。
- Trainer Card 问候；上层时间、日期和天气；容易进入的 App Library。
- 自选壁纸、几个内置背景 / 效果、无壁纸默认状态与恢复默认。
- 掌机方屏 / 横屏适配，触屏与实体按键都可使用。
- 本地偏好持久化；天气由用户选择城市，不申请定位。

## 用户确认的设计痛点

- 几个大按钮或通用卡片占满屏幕，缺少视觉主次。
- 模块不够灵活，留给背景的空间不足，缺少通透感。
- 多余的图标可以省略；保留有意义、易理解的操作入口。
- 三主题需要可辨认的性格和 TitoDex 气质，不应只靠颜色和圆角区分。
- 希望主动思考、完善产品，并参考优秀开源桌面 / 启动器的成熟组织与交互方式。

评估真实操作：如何进入 / 返回应用库，如何发现编辑入口，移动 / 调整大小 / 添加 / 隐藏模块需要几步，换主题 / 壁纸 / 效果能否看见结果，改错后能否容易恢复。

## 方案边界

上一位 agent 提出了“桌面原位编辑、拖动 / 缩放 / 隐藏模块、外观实时预览”作为候选方向。尚未实现，也未经过用户体验验证；不要把这些当作冻结设计或用户逐项确认的规格。

保持轻量。ROM 扫描、游戏时长、系统小组件、账号和云同步尚未被要求。不要自行扩大成复杂的游戏管理平台。

2026-10-17 已提交 0.3 方向提案，等待用户确认：[`design/DIRECTION-0.3.md`](design/DIRECTION-0.3.md)，包括现状问题、信息架构、触屏流程、取舍和迁移；可交互原型 `design/prototype.html`，草图由 `design/capture.sh` 生成。原型已在 RG Rotate 的 Firefox 中以实际尺寸验证触屏流程（不安装、不改设置）；实体按键映射尚未在真机验证。确认前不要据此大范围改动 `lib/`。

## 当前实现

- 当前源代码与最后安装的预览版：`0.2.0+2`。用户尚未认可最终体验。
- `lib/main.dart`：导航、设置、天气与原生桥接协调。
- `lib/home_page.dart`：当前模块首页；`lib/layout_editor.dart`：当前独立编排页。
- `lib/library_page.dart`：应用库、收藏管理；`lib/settings_page.dart`：当前长设置页。
- `lib/appearance.dart`：三主题、背景、面板、焦点按钮；`lib/models.dart`：偏好与模块配置。
- `android/app/src/main/kotlin/com/tito/titodex/launcher/MainActivity.kt`：HOME、应用枚举 / 启动、系统入口、按键、照片导入与本地设置。
- 最新一轮只完成需求梳理和源码快照，没有实现 0.3，也没有替用户安装新的框架。

已有 20 项组件 / 单元测试和 RG Rotate 集成验证，详见 `VALIDATION.md`。这些是行为证据，不表示视觉和触屏体验已经获用户认可。参考记录见 `README.md`。

## 构建与设备

目标设备实测 Android 12、720×720、240 dpi（约 480×480 logical）、ARM64。开发用 Java 17、Android SDK 36，最低 API 24。预览 APK 使用本机 debug signer；没有公开正式发布。

```sh
cd launcher
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target lib/main.dart --target-platform android-arm64
```

真机测试必须用 `tool/test_device.py <serial>`（配置 Java 与 Android SDK），它先备份私有设置 / 照片，以 `--no-uninstall` 运行测试，结束恢复并逐文件校验。首次直接执行 Flutter 集成测试曾因默认卸载清空用户设置；已向用户说明并恢复能确认的偏好。绝不能重复该失误。

不要公开上传设备偏好备份、私有照片、本地密钥或 build 产物。保持系统默认桌面和系统壁纸由用户自行选择。不要修改 TitoDex 主 App 的包名或版本。

## Git 交接

本项目仍在 `Tito-XD/tito-dex` 仓库，代码目录为 `launcher/`，没有另建仓库。

Launcher 专用交接分支：`codex/titodex-launcher`，基于同步时的 `origin/main`（`33dbb4b`），只包含 Launcher 与本交接说明。请从该分支继续框架设计。

另有 `codex/workspace-sync-20261016` 保存原本地工作区历史及全部待同步源代码，包括其他任务的 Journey Assistant / Exa 搜索和属性选择器改动。它是工作区快照，尚未完成与最新远端主线的语义整合或生产验收。不要把其中所有代码视为 Launcher 的必要依赖。

接手前先读上层 `docs/AI_CONTEXT.md`、`docs/DESIGN_SYSTEM.md`、本目录 `AGENTS.md` 和这份文档。保留其他任务的改动；所有新设计工作优先限定在 `launcher/`。
