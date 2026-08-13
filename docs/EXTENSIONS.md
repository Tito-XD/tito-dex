# TitoDex Android 附加包

> 状态：v0.8.13 首次提供 Journey Assistant 1.0.0 可选扩展；v0.8.14 修复安装后的宿主发现与 UI 刷新。资料仍只覆盖三条 HGSS 试用链路。

TitoDex 的附加包是一个可单独安装和卸载的 Android APK。第一包是“旅程助手”，主 APK 保留下载、安装、启停与入口管理，审核资料放在附加 APK 中独立迭代。用户不需要时可以不安装。

## 第一包契约

- extension ID：`journey_assistant`
- package ID：`com.tito.titodex.extension.journeyassistant`
- ContentProvider：`com.tito.titodex.extension.journeyassistant.provider`
- signature permission：`com.tito.titodex.permission.READ_EXTENSION_PACK`
- manifest：`content://…provider/manifest`
- 资料：`content://…provider/files/progression_hints.json`

附加 APK 没有 Activity 或桌面图标，只提供只读 ContentProvider。主 APK 只接受与自身相同签名、固定 package/provider/permission、受支持 protocol/minHostVersion、合法 manifest、白名单文件路径及匹配 size/SHA-256 的包。文件每次读取都会再次核对 manifest 声明的大小与摘要。未知 URI、路径穿越、写模式和 insert/update/delete 全部拒绝。

canonical schema：

- [`extension_catalog.schema.json`](../data/extensions/extension_catalog.schema.json)：CDN catalog
- [`extension_pack_manifest.schema.json`](../data/extensions/extension_pack_manifest.schema.json)：已安装包 manifest

## 用户流程

1. Journey 未安装时显示“安装旅程助手”；设置页同时提供统一管理入口。
2. App 从构建时配置的 Journey Assistant Worker catalog 路径拉取版本信息，再从同一 Worker 流式下载 immutable APK；不直连 R2/CDN。
3. App 核对 catalog SHA-256/size，原生层再核对 APK package、provider 与 TitoDex 签名。
4. Android 系统安装器要求用户确认；未授权侧载时先进入“允许来自此来源”。
5. 安装后 Journey 可进入问答；Search 可在设置中选择“大入口 / 紧凑 / 隐藏”（默认紧凑）。
6. 设置页可检查/安装更高 `versionCode` 的同签名更新、关闭功能或打开系统卸载页；低版本和重复版本不会安装。在线 AI 是另一独立、默认关闭的开关。

Web 与非 Android 构建不会尝试安装 APK。`REQUEST_INSTALL_PACKAGES` 适用于当前 GitHub/RG 侧载发行；如果以后进入 Google Play，需要按 Play 政策采用对应的可选模块分发方案，不能直接沿用这条安装路径。

## 构建与 R2 staging

附加 APK 直接从 [`progression_hints.json`](../data/journey/progression_hints.json) 复制资料并生成 manifest，不维护第二份事实源：

```bash
cd flutter/android
./gradlew :journey-assistant-pack:check
./gradlew :journey-assistant-pack:assembleJourneyAssistantPack
```

release APK 必须与主 APK 使用同一 release keystore。产物默认在 `flutter/build/journey-assistant-pack/outputs/apk/release/`。发布前先用 `apksigner verify --verbose --print-certs` 核对 v2+ 签名与主 APK signer，再生成 immutable R2 staging 目录：

```bash
python3 tools/build_journey_extension_release.py \
  flutter/build/journey-assistant-pack/outputs/apk/release/journey-assistant-pack-release.apk \
  /tmp/titodex-extension-release \
  --version-name 1.0.0 --version-code 1 --min-host-version 0.8.13
```

后续获批上传时，把产物放到 `titodex-journey-content` 的 `extensions/journey-assistant/` 下：先传 `objects/*.apk`，确认经 Worker 返回字节的 SHA-256 后，最后传 `extension-catalog.json`。不要覆盖旧对象；更新只发布新 digest 文件并最后替换 catalog。App 构建只配置 Journey Assistant Worker 的完整 catalog URL：

```bash
flutter build apk \
  --dart-define=TITODEX_EXTENSION_CATALOG_URL=https://<private-worker-host>/v1/extensions/journey_assistant/catalog
```

源码和公开文档不得写入真实生产 CDN URL、账户 ID、密钥或签名材料。上传、部署和发布始终是单独审批动作。
