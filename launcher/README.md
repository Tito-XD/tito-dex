# TitoDex Launcher

面向 Android 游戏掌机的独立轻量桌面。首个目标设备是 RG Rotate（Android 12、720×720、240 dpi）。与 TitoDex App 并列安装，保留其「训练家手帐」「固态塑料」「扁平贴纸」视觉语言。

下一轮框架与触屏体验重做请先读 [HANDOFF.md](HANDOFF.md)。用户尚未认可 0.2.0 的最终体验；候选新方案尚未落地。

## 0.2.0 预览版

- Android HOME / DEFAULT 声明；设置内通过系统界面选择默认桌面，也可切回其他桌面。
- 固定打开 `com.tito.titodex`；找不到正式版时给出安装提示。
- 「漫游 / 面板 / 留白」三种桌面预设；训练家、TitoDex、常玩、最近打开四个模块可排序、切换半宽 / 整行、隐藏；固定保留 TitoDex 入口。
- Trainer Card：本地称呼、随时段变化的问候、自定义一句话；大时钟与壁纸留白区，底部常驻轻量 Dock。
- 半透明面板（70–100% 不透明度）、独立背景虚化开关；三主题各有表面处理、减少动态效果开关。
- 本机时间、日期、12/24 小时制、电量、充电与联网状态。
- 当前 Android 用户的可启动应用库：图标、搜索、收藏到桌面（最多 12 个）、应用信息；收藏可拖动或按按钮排序，应用库 3–6 列自适应；回到前台刷新安装列表。
- 方向键 / 左摇杆导航、A 确认、B 返回、X 应用选项、明显的焦点描边；触摸同样可用。
- 无壁纸默认背景、海岸 / 暮色 / 森林内置背景、系统文件选择器导入照片（缩小并按 EXIF 方向校正）；原图 / 柔焦模糊 / 暗色遮罩 / 扫描线；恢复默认背景。
- 手动选城市的 Open-Meteo 天气，无定位权限；30 分钟刷新、手动重试、明确失败状态；离开前台停止定时刷新。
- 系统设置、Wi-Fi 设置和默认桌面管理入口。

包名：`com.tito.titodex.launcher`。Launcher 不读取 TitoDex 的私有存档或训练家资料；称呼、收藏、外观独立本地保存。照片复制并缩小到应用私有目录，默认背景仅影响 Launcher 自身。

## 构建与检查

```sh
cd launcher
flutter pub get
flutter analyze
flutter test
JAVA_HOME=/opt/homebrew/opt/openjdk@17 flutter build apk --release --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.tito.titodex.launcher/.MainActivity
```

本地 Java 路径按环境调整。Android SDK 36、NDK 28.2.13676358、Java 17；最低 Android 7.0 / API 24。当前 `release` 构建是使用本机 debug signer 的设备预览包，公开分发前需要独立正式签名。

真机桥接与 UI 验证（要求设备已安装正式 TitoDex）：

```sh
JAVA_HOME=/opt/homebrew/opt/openjdk@17 python3 tool/test_device.py <serial>
```

测试脚本先以 `adb install -r` 保留数据更新调试包，备份私有设置与照片，再以 `--no-uninstall` 运行测试，最后逐文件校验恢复结果。备份保存在被 Git 忽略的 `build/validation/`，不得公开分享。不要直接使用默认会卸载应用的 `flutter test integration_test/... -d ...`。测试覆盖真实应用枚举/图标、设置存取、缺失包处理和带软键盘的应用库搜索。网络探针：`dart run tool/check_weather.dart`，使用公开样例城市 Shanghai，不读取设备位置。

## 桌面操作

- 底部「编排」或长按桌面空白处可编排模块；拖动把手排序，手柄也可使用上移 / 下移按钮。预设会重排模块，不清空称呼、收藏或壁纸。
- 应用库长按应用或焦点停留后按 X，添加 / 取消收藏、打开应用、查看系统应用信息。收藏页的「整理」可排列常玩顺序，也能移除已卸载的收藏。
- 「最近打开」默认隐藏，只记录从这个 Launcher 成功打开的应用；不申请系统使用记录权限。
- 「搜索」直接打开搜索框；在桌面留白区向上划也能打开应用库。设置里可调整列数、面板透明度、虚化、主题、壁纸效果和手柄提示。
- 默认保存到本机，无账号、同步或位置权限。旧版偏好自动迁移到模块布局。

## 默认桌面

安装后打开 TitoDex Launcher → 设置 → 设为默认桌面 → 在 Android 系统选择器选中 TitoDex Launcher。Home 返回首页并关闭弹层；B / 返回从应用库或设置回到首页，首页返回不会退出。系统边缘手势仍可呼出系统栏。

## 范围与后续

当前不接入 ROM 扫描、游戏时长、系统小组件、跨 Android 用户 / 工作资料 / 私密空间应用、通知权限或云账户。App Library 显示系统报告的当前用户可启动 Activity。收藏引用具体 Activity，应用卸载后不会占据首页；应用重装可重新出现。

模拟的按键事件与真实手柄手感是不同验证项；需在设备上继续体验长按连发、摇杆连续导航、旋转后的焦点位置和系统返回手势。后台恢复能更新应用库；当前不驻留后台监听安装广播。

## 设计参考

参考了 [Kvaesitso 的收藏分层与排序](https://kvaesitso.mm20.de/docs/user-guide/concepts/favorites)、[Lawnchair 的桌面自定义](https://github.com/LawnchairLauncher/lawnchair) 和 [MinUI 的掌机聚焦设计](https://github.com/shauninman/MinUI)。本项目独立实现界面和交互，没有复制这些项目的代码或素材。具体设备证据见 [VALIDATION.md](VALIDATION.md)。

## 来源与许可

- 主题名称、配色和 Nunito 沿用仓库 [设计系统](../docs/DESIGN_SYSTEM.md)。Nunito 使用 SIL OFL 1.1，全文打包在 `assets/licenses/nunito-OFL.txt`，可在应用许可页查看。
- 天气与城市搜索来自 [Open-Meteo](https://open-meteo.com/)，天气数据按 CC BY 4.0 标注；当前个人预览使用其非商业免费 API。见 [天气接口](https://open-meteo.com/en/docs)、[城市搜索](https://open-meteo.com/en/docs/geocoding-api)、[服务条款](https://open-meteo.com/en/terms)。网络开启后仅提交搜索词或所选城市坐标。
- 默认桌面采用 Android [HOME role](https://developer.android.com/reference/android/app/role/RoleManager#ROLE_HOME) 与系统默认应用选择界面。
- 原创矢量背景，不打包第三方 Pokémon 壁纸。非官方个人项目，与 Nintendo、Creatures、GAME FREAK 或 The Pokémon Company 无隶属、授权或赞助关系。
