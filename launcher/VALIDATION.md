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
