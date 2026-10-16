# 工作区同步记录 — 2026-10-16

用户明确要求同步整个工作区，包括 Launcher、Journey Assistant / Exa 搜索、属性选择器和相关文档。

## 分支与历史

- 原仓库仍是 `Tito-XD/tito-dex`，没有新建仓库。
- 同步开始时，原本地 `main` 为 `55c7fc3`，最新 `origin/main` 为 `33dbb4b`。二者已分叉：本地独有 423 个提交，远端独有 467 个提交。
- `codex/workspace-sync-20261016` 从原本地 HEAD 建立，完整保存原工作区历史与所有待同步源代码。原 `main` 指针和远端 `main` 保持不变。
- `codex/titodex-launcher` 从最新 `origin/main` 建立，只新增 `launcher/`，供下一位 agent 继续桌面框架与触屏体验设计。先读该目录的 `HANDOFF.md`。

工作区快照尚未与最新远端主线进行语义整合，不应直接当作生产发布分支。后续整合需要对比已发布版本与这批改动，避免把已修复的主线行为覆盖回旧版本。

## 保存范围

- Launcher 0.2.0 独立 Flutter / Android 工程、测试、说明和下一轮设计交接。
- Journey Assistant 的 Exa-primary / Tavily-backup 搜索实现、公共搜索边界、Provider 状态、测试与配置说明。
- 主 App 的 Ask TitoDex 来源 / 搜索展示改动、属性选择器改动及其测试。
- `.gitignore` 对 `.dev.vars` 的忽略规则与相关项目文档。

本地密钥、私有设备偏好 / 照片备份、APK、构建缓存等被忽略的文件保留在本机，不属于 Git 同步内容。

## 本次验证

- 干净 Launcher 分支：依赖安装后 `flutter analyze` 无问题；20 项测试通过。
- Journey Assistant：`exa_search`、`web_search`、`curated_web`、`worker` 四个测试文件，共 137 项通过。
- 主 App：`ask_titodex_test.dart` 与 `companion_type_picker_test.dart`，共 39 项通过。
- 待同步文本格式检查通过；常见凭据模式筛查未发现需要排除的密钥；原工作区变更经过文件哈希核对。

以上为本地定向验证。本次没有进行生产部署、APK 正式发布或完整主线整合，也没有把这些检查等同于用户对 Launcher 体验的认可。最后安装的 Launcher 仍是 0.2.0，新设计尚未实现。
