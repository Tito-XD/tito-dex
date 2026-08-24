# TitoDex 旧 Android 附加包兼容

> 状态：Journey Assistant 1.0.0 曾作为可选 APK 扩展发布；当前 v0.9.1 179/180 已把助手、持久会话、状态入口、语义分块回答与等待动画集成进主 App，并以 Worker 提供的按游戏数据包替代新增 companion APK。本页只记录旧包读取兼容与维护协议。

旧附加包是一个无桌面入口的独立 Android APK。当前主 App 不要求它存在：有效的旧包仍可作为兼容数据源；包不存在、Provider 不可见或任何校验失败时，立即使用主 APK 内建审核资料。

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

## 当前用户流程

1. Journey 与 Search 直接使用主 App 内建助手，无安装确认和未知来源权限。
2. 设置页可关闭内建助手、单独开启在线 AI，并选择 Search 的“大入口 / 紧凑 / 隐藏”。
3. 已安装旧 1.0.0 包时，主 App 可继续按严格协议读取；用户可在 Android 系统设置自行卸载，不影响内建功能。
4. 未来资料扩充使用 App 私有数据包，不再发布可执行 APK。

当前 UI 不再触发 APK 安装。遗留 host/catalog 代码暂时保留一版兼容，后续确认迁移完成后可连同 `REQUEST_INSTALL_PACKAGES` 一并移除。

## 旧包构建与 R2 staging（仅兼容维护）

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

若仅为旧兼容包发布安全修复，把产物放到 `titodex-journey-content` 的 `extensions/journey-assistant/` 下：先传 `objects/*.apk`，确认经 Worker 返回字节的 SHA-256 后，最后传 `extension-catalog.json`。不要覆盖旧对象。当前内建助手不读取 catalog，也不需要下列构建参数：

```bash
flutter build apk \
  --dart-define=TITODEX_EXTENSION_CATALOG_URL=https://<private-worker-host>/v1/extensions/journey_assistant/catalog
```

源码和公开文档不得写入真实生产 CDN URL、账户 ID、密钥或签名材料。上传、部署和发布始终是单独审批动作。
