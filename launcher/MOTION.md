# 动效预发布方向

参考 [Motion Prompt](https://github.com/showheyohtaki/motion-prompt)，Shohei Ohtaki，MIT，版本 `770eefb7091cc725ab0eb6d4ef5cbf28b28e282c`。借鉴 Pop-in、Stagger、Easing、Overshoot、Squash & stretch 的表达方式；使用原生 Compose 动画，不复制演示代码、图片或字体，不引入 WebView。

动效优先解释层级与操作：应用库从底部进入和返回；桌面编辑的进入、离开和落位；按钮按压、焦点、弹层与撤销提示。拖动跟手优先，不给手指位置额外延迟。不增加常驻装饰循环。

三主题共享短行程：手帐轻微落定，塑料带阻尼回弹，扁平快速收束。关闭动态效果或系统动画缩放为零时直接到最终状态。快速反向操作应从当前值转向新目标，返回后不能残留拦截点击的遮罩。

## 发布边界

`0.3.1-motion.1` / code 6，包名 `com.tito.titodex.launcher`。开发证书签名，仅作为 GitHub Pre-release；不是正式签名的生产发行。使用相同开发证书的既有设备预览可保留数据升级，不自动更换默认桌面。真机验证必须执行 HANDOFF / AGENTS 指定的备份、覆盖安装、恢复、逐文件核对流程。

公开附件只包含 APK、校验和和验证记录。设备备份、用户壁纸和带个人内容的截图保留在忽略的 build/validation 目录。自动化测试不能代替触屏与按键体验验收，已测范围在发布记录中逐项说明。
