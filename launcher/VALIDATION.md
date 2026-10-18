# 0.3.0 Launcher 专属球形 TitoDex 徽章（2026-10-18）

## 0.3.1-motion.1 原生动效预发布

- 本轮新增可打断的应用库过渡、直接拖动/松手交接、模块落位、按压与焦点、菜单/撤销提示。关闭应用库即移除交互节点，退出绘制不能遮挡首页；不再持续摇摆。
- 50 项本地单元/Robolectric 测试通过，0 失败。新增 10 项覆盖三主题反向、1:1 拖动、松手交接、应用/系统减少动画、退出点击穿透、Home 中断、撤销和小组件 ID。
- 实机发现编辑舞台回到首页后，缓存触控框停留在动画中间位置，导致应用库按钮无法点击。改为激活时读取当前布局坐标；新增真实坐标点击用例核对可见范围与触控框一致。
- 暂停测试时钟时显式提交外部状态，避免检查旧界面；退出断言定位应用库节点，允许桌面保留同名收藏。拖拽交接持续订阅动画值，保证松手后正确落定。
- debug/release 构建通过；最终 release 已在 RG 保留数据升级，备份恢复逐文件一致、启动无崩溃。录屏复测快速开合、拖动关闭、长按整理、Home 返回、编辑返回后的真实坐标点击、系统动画比例 0 与模拟 D-pad/B 返回通过；测试后系统设置恢复。实体手柄、持续性能和功耗未验收。
- [已发布 Pre-release](https://github.com/Tito-XD/tito-dex/releases/tag/launcher-v0.3.1-motion.1)。APK 源码 `db779e51f30c89d5a5705904d013be547df6d04d`；文件 1,349,648 字节，SHA-256 `6404aa4184bb1eaca4b4dcaf11018b08fc8667f5ba3b544fde623a2d12ef3ced`。开发签名、包名/版本、ZIP 与对齐通过；正式 App 和 GitHub Latest v0.9.24 未改变。


- 用户澄清：保留之前的球形入口，不必百分百还原 App 图标，重点是 Launcher 自己的风格和独立于其他应用的辨识度。该方向取代上一条方形 App 图标底座试用。
- 统一 `TitoEmblem` 使用蓝色上半球 / 深色下半球、浅色中线与中央圆环。手帐是有硬阴影与虚线纸边的圆徽章；塑料是带高光、边缘厚度和下沉中心的圆形按键；扁平是蓝黑圆章、浅色粗边和珊瑚色中心。几何按尺寸缩放，绘制边缘与阴影保留在尺寸内。
- 小尺寸、带标签大尺寸和入口菜单共享造型；小尺寸名为「徽章」，原尺寸 key 与网格占位不变。移除上一轮复制的未使用 App 图标资源，普通应用仍使用自己的图标。固定入口与正式 App 包名逻辑未改。
- 40 项现有检查通过（0 failure / error / skip）；debug / release 构建成功，签名验证通过。仅为表面视觉修改，不添加重复绘图实现的测试。
- 已用 `tool/test_device.py` 备份 / smoke / 恢复并逐文件验证原设置与照片。RG 上分别查看三主题，圆章完整可见；点击确认前台为 `com.tito.titodex/.MainActivity`。正式 App 仍为 0.9.24，安装时间仍为 2026-10-11 11:11:38。
- 主题检查后恢复用户原手帐主题，原照片、布局、收藏与城市保留，默认 HOME 仍为 Launcher。启动正式 App 按原逻辑记录最近使用。最终 crash buffer 无记录；不代表新增实体按键全流程验收。
- 真机截图：`build/validation/20261018-emblem/journal.png`、`plastic.png`、`flat.png`，同目录保存构建 / 设备日志。私有备份和截图只留在忽略的 build 目录。
- 最终安装时间 2026-10-18 21:05:29，0.3.0 / code 5；本地预览 APK：`build/outputs/TitoDex-Launcher-0.3.0-preview.5-emblem-rg-arm64.apk`。
- SHA-256：`1d2f63077df15af35a739ce417862023d856b2fa6da940cfb04637ea341f41aa`。未提交、推送或发布。

---

# 0.3.0 正式 TitoDex App 入口（2026-10-18）

- 用户要求用已有 TitoDex App 配合各主题，替换原自绘圆钮。删除 `TitoKey`，小尺寸入口、带标签大尺寸与入口菜单统一使用正式 `com.tito.titodex` 的已安装图标；只改变图标外的主题底座，不改 App 颜色或使用主题预览包图标。
- 手帐：纸贴边缘和虚线；固态塑料：浅色渐变、亮边和厚度；扁平贴纸：珊瑚色块与深蓝边框。应用列表尚未加载时使用主 App 原始矢量图标兜底（源文件逐字一致），不再画替代徽标。
- 编辑器的小尺寸名称改为「图标」，持久化尺寸 key 不变。固定入口的移动、换尺寸和打开正式包行为保留。
- 40 项现有检查通过，debug / release 构建成功，APK 签名验证通过。未为这次表面样式另加重复实现的测试。
- `tool/test_device.py` 本轮备份、smoke、恢复并逐文件核对通过。RG 真机逐一核对三个主题；点击新入口后的前台 Activity 确认为 `com.tito.titodex/.MainActivity`。正式 App 仍为 0.9.24，安装时间仍为 2026-10-11 11:11:38。
- 验收后通过界面回到用户原手帐主题；保留原照片、桌面布局、收藏、城市和默认 HOME。启动 App 会按已有逻辑记录最近使用。最终 crash buffer 无记录。
- 真机截图：`build/validation/20261018-app-icon/journal.png`、`plastic.png`、`flat.png`；同目录保存构建、设备日志和调整前截图。截图及私有备份只留在忽略的 build 目录。
- 最终 Launcher 安装时间 2026-10-18 20:55:49，0.3.0 / code 5。APK：`build/outputs/TitoDex-Launcher-0.3.0-preview.5-app-icon-rg-arm64.apk`。
- SHA-256：`afa43b4d63a4d63a9ef026ccd3bc715a439663988283f24cbea9900023f89c4d`。未提交、推送或发布。

---

# 0.3.0 日期对齐 / 1×2 大时钟复验（2026-10-18）

- 用户要求日期和星期字号统一、对齐，并放大 1×2 时间。日期与镂空英文星期现均为 16sp / ExtraBold，显式按基线对齐，保留透明字形描边和中文星期读屏。
- 时间使用等宽数字，并按稳定两位数宽度与扣除日期/天气后的高度自适应放大；去掉数字不使用的上下字体留白，保持两行紧凑、不超出格子。此为用户最新方向，取代上一轮限制数字首选字号的试用版。
- 最终 40 项检查全部通过（含日期星期字号相等、基线相等、数字不超高或超宽），debug / release 构建成功，APK 签名验证通过。
- RG 真机截图已核对：小时/分钟明显放大，日期与 SUN 同字号、同基线，日期/天气完整可见。截图：`build/validation/20261018-clock-fit/after.png`，同目录保留调整前截图与构建 / 设备验证日志。
- 本轮完整执行 `tool/test_device.py`：备份原设置和照片、smoke 无 fatal、恢复后逐文件比对通过，再安装最终 release。未清空数据、替换壁纸或改变默认 HOME。检查时 crash buffer 无记录。
- 最终 RG 安装时间 2026-10-18 20:49:56，版本仍为 0.3.0 / code 5。APK：`build/outputs/TitoDex-Launcher-0.3.0-preview.5-clock-fit-rg-arm64.apk`。
- SHA-256：`66835b040f5a1d6873cf31ebb5fb6bb8bb32cf095dce02d964df896f8dad5ece`。未提交、推送或发布。

---

# 0.3.0 日期 / 镂空星期同排试用（2026-10-18）

- 用户要求把星期合并到日期一行，或尝试 SUN / MON / SAT 镂空指示。当前竖排时钟采用同排 `10/18 SUN`：日期 16sp 实心，星期 18sp 字形描边、透明填充，按实际日期切换，保留中文星期读屏说明。该行过窄（如大系统字体）时换行而不缩小文字。
- 保持 1×2 占位、紧凑双行数字；限制数字首选字号，避免合并元数据后数字又放大占满原空间。仅影响竖排尺寸，其他尺寸的日期外观保留。
- 最终 40 项本地测试通过，debug / release 构建成功。已有 UI 检查更新为验证日期与星期同排、未超出格子、数字未裁切、中文读屏可达。
- RG 真机核对 SUN 空心字形可读、日期与星期同排、数字与天气完整可见；截图 `build/validation/20261018-weekday/after.png`。天气仍能正常刷新。最终检查时 crash buffer 无记录。
- 本轮 smoke 按备份流程执行，私有设置/照片恢复后逐文件比对通过；最后仅限制数字首选字号并重新测试、覆盖安装。保留数据、原壁纸和默认桌面。备份与截图均在忽略的 build 目录，不应公开。
- 最终安装 2026-10-18 20:44:43，0.3.0 / code 5。APK：`build/outputs/TitoDex-Launcher-0.3.0-preview.5-weekday-rg-arm64.apk`。
- SHA-256：`1b29bf1826244149d95f1d55bc74ae73f3a85718c04f9d2d3ad730fb77a1dea9`。未提交、推送或发布。

---

# 0.3.0 竖排时钟间距复验（2026-10-18）

- 用户反馈小时/分钟与日期间距过大。保持 1×2 网格占位，双行数字统一基线，去掉重复字体留白与末行数字不需要的下降部留白；日期、星期和天气维持 16sp。
- 最终本地 40 项测试全部通过，debug / release 构建成功。RG 真机确认两行数字间距收紧、日期靠近，无数字与小字裁切；截图 `build/validation/20261018-spacing/after.png`，调整前为同目录 `before.png`。
- 已按 `tool/test_device.py` 流程创建本轮私有备份，恢复原设置/照片后逐文件校验通过，smoke 无 fatal。最终只进一步调整字体空白并重新覆盖安装，未改偏好数据；最终 crash buffer 无记录。
- RG 最终安装时间 2026-10-18 20:10:26，版本仍为 0.3.0 / code 5。APK：`build/outputs/TitoDex-Launcher-0.3.0-preview.5-compact-rg-arm64.apk`。
- SHA-256：`dc483a69e9f60b4a07ff1605a644d9680594e0311af92d52481f86ece99b5b7e`。本轮只修改时钟排版、相关已有检查和交接记录；未提交、推送或发布。

---

# 0.3.0 Compose 预览版真机补验

日期：2026-10-18。RG Rotate Android 12，720×720、240 dpi。

## 本轮修改

- 原生 Kotlin / Jetpack Compose 保持不变。留白模板改用 **1×2 竖排时钟**（小时、分钟两行）；其他模板保留 2×1 紧凑 / 大字与 4×1 横幅选项。
- 日期采用 `10/18 周日` 短写；竖排拆成日期、星期两行，日期 / 星期 / 天气保持 16sp。移除整体缩放，按真实字体测量自适应数字，修复真机分钟下沿裁切。
- 首页天气不显示城市。点击显示未来 6 个小时与 4 天预报；窄屏弹层限制尺寸并可滚动，刷新保留弹层与已有数据。
- 天气按接口城市时区解析；缺失天气码不伪装晴天，非法日期不宽松归一化。
- Gradle 最大堆 2 GB、2 workers、禁并行项目构建、Kotlin 进程内编译。Launcher 与 Flutter APK 串行构建。

## 验证结果

- 最终 `testDebugUnitTest`、`assembleDebug`、`assembleRelease` 成功：40 项测试、0 失败（迁移 8、UI 12、Model 6、天气 3、网格 11）。涵盖两种方向的留白 1×2、日期天气可见性、数字文本不裁切、天气弹层返回等。
- 真机截图发现自动检查遗漏的分钟裁切后进行了修复、再次构建与覆盖安装；最终 1×2 的小时、分钟、日期、星期、温度均完整可见。截图：`build/validation/20261018/launcher-vertical-final.png`。
- 实际网络预报成功显示 6 小时 / 4 天，高低温和天气文字可读；ADB B 关闭弹层返回桌面。截图：`build/validation/20261018/launcher-weather-final.png`。
- 本轮修改前已备份并逐文件核对 Launcher 私有设置和照片。设备 smoke 流程成功、恢复后逐文件核对成功；修复了 release 不可 run-as 时先覆盖回 debug、恢复、再装目标包的流程。备份位于忽略的 `build/validation/device-backup-*.tar`，不得提交或公开。
- 最终安装只使用保留数据覆盖安装；保留用户壁纸、收藏、城市、昵称，时钟已通过界面改为用户要求的竖排。系统原有默认 HOME 仍为 `com.tito.titodex.launcher/.MainActivity`。
- 最终包 `com.tito.titodex.launcher`，0.3.0 / code 5，安装时间 2026-10-18 19:09:19。APK v2 签名校验成功，本机开发证书。检查时 crash buffer 无记录。

APK：`build/outputs/TitoDex-Launcher-0.3.0-preview.5-rg-arm64.apk`。
SHA-256：`c1086957e13c9283b34c0a196436a5f544ce5529ffc092321998c995d29432ef`。

另已在 RG 安装独立的 TitoDex 主题预览包 `com.tito.titodex.themepreview`，标签「TitoDex 主题预览」，版本 0.9.6-theme-preview / code 191；此为主题分支快照。正式 App 仍为 0.9.24 / code 216、安装时间 2026-10-11 11:11:38，未覆盖或复制正式数据。桌面固定 TitoDex 入口仍打开正式 App。

## 边界

- 最新数字测量修复后重新运行全部 40 项本地测试、安装与截图验收；私有数据备份恢复 smoke 在同轮较早版本执行，最终仅字体测量/UI 检查变动，没有重复写入测试数据。
- 真实物理摇杆连发、旋转手感、系统小组件提供方兼容性、重启及长期使用未在本轮全面复验。
- 保留此前其他任务的 staged / unstaged 原生迁移改动；本轮未 Git 提交、推送或发布 Release。以下 0.2 / 0.1 记录为历史 Flutter 版本，不代表当前实现。

---

# 0.2.0 预览版验证记录

日期：2026-10-15。RG Rotate：Android 12、ARM64、720×720、240 dpi。

## 本次改版

- 大按钮首页改为时钟 / 天气留白区、可编排模块和底部 Dock。模块可半宽 / 整行、隐藏、拖动或按按钮排序；保留固定 TitoDex 入口。
- 漫游、面板、留白三种预设；常玩收藏和可选最近打开；收藏排序在首页和应用库保持一致。
- 三主题的半透明表面、独立面板虚化、减少动态效果、原创矢量背景；移除首页重复功能图标。
- 应用库改为紧凑网格，长按 / X 展开选项，收藏管理可排序与删除已卸载条目；可调列数。
- 实机发现并修复软键盘导致的搜索页溢出；带收藏的应用菜单可滚动；小屏大字体下编排按钮自动换行。
- 图片导入按 EXIF 方向校正，再保存受尺寸限制的私有副本。

## 已完成验证

- `flutter analyze` 无问题；`flutter test` 20 项通过。覆盖旧设置迁移、坏数据恢复、三预设在 360×360 / 480×480 / 800×450 的布局与 A 键激活、布局保存重启、模块隐藏 / 宽度 / 顺序、收藏增删与顺序、X 菜单、1.5 倍文字和高占屏软键盘。
- RG Rotate 原生集成测试通过：真实应用枚举与图标、固定 TitoDex 包可见、缺失包处理、偏好存取、带软键盘的包名搜索、布局 / 透明度 / 列数保存。新 `tool/test_device.py` 实际执行通过，设置与照片备份在测试后逐文件校验恢复。
- 真机检查三主题：手帐默认、固态塑料 + 暮色、扁平贴纸 + 海岸。后两张为临时样例收藏展示，截图后恢复。`build/validation/v020/` 内包含截图。
- 真机应用库显示 54 个可启动 Activity；ADB X 打开应用选项，B 关闭菜单并返回首页；编排页面可达。
- Android 文件选择器导入专用 320×200、EXIF orientation=6 四色 JPEG。实际私有副本为 200×320，四角颜色逐像素抽样符合顺时针 90° 结果。界面恢复默认背景后 `wallpaper=none`、`photo=null`；专用测试源文件已移除。
- 首页真实显示武汉天气；城市采用用户此前选定的武汉，未访问定位权限。Tito 昵称和武汉城市已恢复并在界面核对。
- 最终 release 预览包安装成功。ADB A 从首页启动正式 TitoDex；显式 HOME Intent 与 B 返回保持在 Launcher；当前进程 AndroidRuntime / Flutter 错误日志为空。最终截图为 `build/validation/v020/RG-Rotate-home-final.png`。
- 最终系统 HOME 查询返回 ResolverActivity（尚未固定默认桌面），需要用户在设置中的系统选择器自行选定；本轮未自动替用户选择。
- APK v2 签名校验通过；包名 `com.tito.titodex.launcher`，版本 `0.2.0+2`，仅 ARM64，使用本机 debug signer 的 release 模式预览包。

## 测试流程事件

本轮第一次直接运行 Flutter 真机测试，默认的结束清理卸载了 Launcher，导致本地设置被清除。已明确告知用户，并恢复能从测试前界面确认的 Tito 昵称、武汉城市和默认手帐外观。此前没有完整设置备份，不能声称恢复了所有未知偏好。之后添加并实际验证专用备份脚本：保留数据安装、备份私有设置 / 照片、`--no-uninstall`、结束恢复且逐文件比对；操作说明和 AGENTS.md 已同步。私有备份只在被忽略的 build 目录，不应公开分享。

## 验证边界

- 实体摇杆连续导航、按键手感和 RG Rotate 旋转体验仍需用户实际体验；ADB 注入和 Flutter 按键测试不能代替这些。
- 未自动选择系统默认桌面；选择默认后的重启恢复、长期使用、其他 Android 掌机机型尚未覆盖。
- EXIF 实机覆盖 orientation=6；其余镜像方向的代码路径尚未逐一用图片验收。
- 当前没有 ROM 扫描、游戏时长、系统小组件、账号 / 云同步或跨用户应用库。

交付 APK：`build/outputs/TitoDex-Launcher-0.2.0-preview-rg-arm64.apk`。
SHA-256：`e8b5fc10c52c4b4cbfc94bceccba6f716093db4b9abecc275f4ec8fec34916a1`。

仅修改 `launcher/`，保留已有 TitoDex 与 Journey Assistant 未提交改动。未提交、推送或发布 Release。

---

# 0.1.0 预览版验证记录

日期：2026-10-15。目标：RG Rotate，Android 12，ARM64，720×720，240 dpi。

## 已验证

- `flutter analyze`：无问题。
- `flutter test`：6 项通过；覆盖设置序列化与损坏恢复、恢复默认背景、应用搜索/收藏排序、时钟/天气状态，以及 480×480、360×360、800×450 的首页/应用库/设置布局与 A 键激活。
- `integration_test/launcher_device_test.dart`：RG Rotate 实机 1 项通过。真实应用枚举含 TitoDex、图标返回、设置持久化、缺失包返回失败、应用库搜索。
- 安装预览 APK 成功；独立包名 `com.tito.titodex.launcher`，已识别到 54 个可启动 Activity。
- Android HOME 候选查询包含 Launcher；设置内能打开系统默认主屏幕选择器。验证后取消，系统默认仍是 Quickstep。
- ADB 注入 `KEYCODE_BUTTON_A` 可由首页启动正式 `com.tito.titodex`；方向下 + A 进入应用库；B 返回首页。显式 HOME Intent 回到首页。
- 训练家手帐与固态塑料已查看真机截图；主题切换立即生效。扁平贴纸切换有 widget 覆盖。
- 系统文件选择器选择本次专用测试图片，成功导入为私有副本；柔焦模糊可见；恢复默认背景正常。测试源图已从设备下载目录删除。
- 电脑端使用同一 Dart 服务向 Open-Meteo 查询公开样例城市 Shanghai：城市搜索返回 8 项，实时天气返回有效温度与 WMO 天气码。设备未擅自设置城市，天气需用户选城市后开启。
- APK 签名校验通过（v2），原生库仅 ARM64。当前是本机 debug signer 签署的 release 模式预览包。

## 仍需人工体验

- 实体掌机摇杆、按键连发、实际手柄键位偏好与旋转手感；ADB 按键注入不能代替这些体验。
- 选择为默认桌面后的长期使用、重启恢复和系统手势体验；本轮保留原默认桌面。
- RG Rotate 当前网络下的天气端到端体验；接口已在电脑端验证。
- 大量应用、高分辨率或带 EXIF 旋转照片、其他掌机机型和 Android 版本。

本轮变更仅新增 `launcher/`；原 TitoDex App 与已有未提交的 Journey Assistant、属性选择器改动保持原状。未提交 Git、推送或发布 Release。

最终交付 APK：`build/outputs/TitoDex-Launcher-0.1.0-preview-rg-arm64.apk`。
SHA-256：`0b724f7e6b1216528bcac830e43b9621afe198a087cfaf7569ee7cac6b950226`。
最终首页截图：`build/validation/RG-Rotate-home.png`。
最终安装后已通过界面再次恢复默认背景，清理测试照片引用；前台为 Launcher，过滤日志无 AndroidRuntime / Flutter 错误。
