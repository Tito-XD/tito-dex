# TitoDex 动效预览

## 参考与取舍

参考 [Motion Prompt](https://github.com/showheyohtaki/motion-prompt)，作者 Shohei Ohtaki，MIT，研究版本 `770eefb7091cc725ab0eb6d4ef5cbf28b28e282c`。该项目提供动效命名、演示和参数，不是 Android 动画依赖。

本轮关注 #001 Pop-in、#002 Stagger、#009 Easing、#010 Overshoot、#011 Squash & stretch。用 Flutter / Compose 自行实现，并把演示中的大幅弹跳、旋转和循环压缩为适合掌机的短距离、有限次数反馈。不复制 JS、图片或字体，也不增加 WebView 或动画运行库。

- 动画表达进入、按下、释放、选中和层级关系；不持续抢占壁纸、文本或游戏入口。
- 三主题延续纸贴落定、塑料阻尼和扁平快速切换的性格，沿用紧凑圆角、独立浅色首页入口和专属球形 TitoDex 固定入口。
- 关闭动态效果或系统减少动画时立即到达最终状态；不延迟按钮点击、返回或读屏，不展示虚假的逐步天气/进度。
- 快速重复开关必须从当前状态转向新目标；返回与取消不能遗留透明遮挡层。

## App 本轮实现

- 首页在数据准备和页面转场完成后，共用一条入场时间线，卡片到三个快捷入口依次出现。重建、数据刷新、横竖布局切换和返回首页不重播，首次触控/按键立即收束。
- 手帐保留硬阴影下沉并短暂回弹；塑料有轻微压缩；扁平沿用状态反馈。拖动超过触控阈值、取消、多指交替、快速再次按压和 D-pad 失焦都会正确释放。
- 设置开关在两端之间短距离滑动，手帐与塑料中途轻微拉伸，落位恢复圆形。
- 系统禁用动画及已有动态偏好即时生效；没有额外持续播放的装饰动画。

## 预发布边界

App 为主题开发分支的独立包 `com.tito.titodex.themepreview`，版本 `0.9.6-motion.1` / code 193。它更新已有主题预览，不覆盖正式 `com.tito.titodex` v0.9.24；该实验分支尚未整合正式分支的所有后续功能，不应当作正式版升级。预览使用独立设置与示例数据，不复制正式 App 私有数据。

Launcher 为原生 Compose 包 `com.tito.titodex.launcher`，版本 `0.3.1-motion.1` / code 6；可保留数据升级本线程的既有 Launcher 预览。更换默认 HOME 仍由用户决定。

两个 APK 均使用本机开发预览证书，发布为 GitHub **Pre-release**，不会替换 Latest 正式版。仅上传检查通过的 APK、校验和及构建验证记录；私有壁纸、设备数据备份和含个人内容的截图不进入公开附件。

构建顺序：先 App 的分析/完整测试及 arm64 预览构建，再 Launcher 的单元测试及 debug/release 构建。16 GB 主机禁止两套构建并发。Launcher 真机前使用交接指定备份/恢复流程。

本轮 App 静态分析通过；完整回归 660 项通过、6 项按条件跳过，包含启动时读取已保存主题、一次性入场、快速连续按压、取消/失焦释放和减少动画验证。APK、真机验收、源提交与附件摘要以实际发布记录为准；代码测试不代表实体按键、持续功耗或全部设备验收。

## 已发布记录

- [App 三主题动效预览](https://github.com/Tito-XD/tito-dex/releases/tag/app-theme-v0.9.6-motion.1)：APK 源码 `78ede3caaa7c25352cf9a8d40505f154caff2c0c`，SHA-256 `b13159770bbebb7895e696c50b8e65b92ac0e829a35b58897a3e4623a92b4b3e`。
- [Launcher 跟手桌面与轻动效预览](https://github.com/Tito-XD/tito-dex/releases/tag/launcher-v0.3.1-motion.1)：APK 源码 `db779e51f30c89d5a5705904d013be547df6d04d`，SHA-256 `6404aa4184bb1eaca4b4dcaf11018b08fc8667f5ba3b544fde623a2d12ef3ced`。
- 两个预览均已保留数据安装到 RG Rotate。正式 App 仍为 v0.9.24 / code 216，安装更新时间未变；Launcher 原壁纸、设置与默认 HOME 保留，系统动画比例已恢复。
- 最终 App 包已录屏检查冷启动与三个入口进入/返回。Launcher 50 项回归通过，最终包真机验证包括编辑返回后的真实坐标点击、快速开合、拖动关闭、系统减少动画及模拟 D-pad/B 返回。实体按键手感与长时间性能尚未验收。

## RG 本地后续：固态塑料回调（2026-10-19）

- `0.9.6-motion.2` / code 194 恢复正式版的奶油白主面板、深蓝旅程卡、弱斜向渐变、细内边与轻投影；保留紧凑圆角和此前动效。
- 三主题 Trainer Card 及设置主题缩略预览统一移除日期。
- 分析无问题，56 项现有主题/首页/动效检查通过。截图测试延长取帧时间至入场结束后，更新后的 13 项首页/设置截图检查也通过。
- 提交同步前再次运行完整 Flutter 回归：660 项通过，6 项截图用例按条件跳过。产品代码与已装机 `motion.2` 包一致，无需重复构建。
- 独立预览包通过签名及完整性校验，并以保留数据方式更新 RG。设备 APK SHA-256 与本地一致：`cdc511226b516240fcdf3b60a1abe3400b2cd2c02a801933bfabdbf8da6672da`。
- RG 已逐一检查三主题首页无日期、塑料首页/图鉴材质，以及队伍、图鉴、搜索入口进入和返回。截图后恢复原来的扁平贴纸主题。
- 正式 App 仍为 v0.9.24 / code 216，安装时间未变化。本次未更新 Launcher，未创建新的线上发布。
- 本地证据：`flutter/build/theme-preview/validation/20261019-plastic-restore/`。APK：`flutter/build/theme-preview/TitoDex-0.9.6-motion.2-theme-preview-rg-arm64.apk`。
