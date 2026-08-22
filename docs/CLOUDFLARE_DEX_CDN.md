# TitoDex 图鉴 CDN：v19 生产 / v14 Offline 紧凑种子

> **受众：** Cloudflare / R2 运维与发布维护者。不要把生产 CDN 直链复制到 App 文案或 GitHub Release 说明。

## 当前版本

| CDN 前缀 | bundleVersion | 物种 | 状态 |
| --- | ---: | ---: | --- |
| `/v5/` | **19** | 1025 | **当前生产**：逐形态媒体审计 + 2130/2130 道具说明与图标 |
| `/v5/` | 18 | 1025 | 历史：在线媒体目录元数据 |
| `/v5/` | 17 | 1025 | 历史：2130 项全量道具目录 |
| `/v5/` | 14 | 1025 | 历史且仍作 Offline APK 种子：紧凑 archive |
| `/v5/` | 13 | 1025 | 历史：各形态独立 `evolutionChain` |
| `/v4/` | 6 | 1025 | 保留不动，供旧客户端和回滚 |
| `/v3/` | 5 | 1025 | 更早回滚 |
| `/v2/` | 4 | 493 | 遗留客户端 |

> **bundleVersion 与 CDN 前缀是解耦的。** v7 之后的每一版（直至 v19）都是在
> **同一个 `/v5/` 前缀上原地增量**发布的，没有新开前缀。不可变约束针对的是
> **单个对象**：同一个 key 不得覆盖成不同内容，而新增 key、以及在两阶段流程里
> 最后切换根 manifest 是允许的。看到 `/v5/` 就以为 bundleVersion 是 7，会误判成
> 需要新开 `/v6/`。
>
> 客户端只在 `remote.bundleVersion > local.version` 时升级离线包，所以同版本号
> 下改内容不会推送给已安装用户——增量必须 bump 版本。

App 访问 JSON 时按 `v5 → v4 → v3 → v2` 回退。根 `bundle-manifest.json` 是短缓存的活跃指针。

```bash
TITODEX_DEX_CDN_BASE=https://dex.tito.cafe
TITODEX_DEX_BUNDLE_URL=https://dex.tito.cafe/v5/bundle.tar.zst
TITODEX_DEX_BUNDLE_VERSION=19
```

> `TITODEX_DEX_BUNDLE_VERSION` 只是 `DexCdnConfig` 里的编译期默认值；版本协商实际
> 比较的是**根 manifest 的 `bundleVersion`** 与本地 `manifest.version`
> （`dex_update_service.dart`），所以这个常量落后于线上版本不影响升级判定。

## 当前 bundle 契约

- 全国图鉴 1–1025，`complete=true`；多形态物种保留独立资料、媒体、招式、特性、进化与精确版本地点。
- `summaries.json`、`dex_catalog.json` 与 detail 内嵌 summary 的可检索字段必须一致；地点反向索引位于根级 `location_index.json`，不并入冷启动目录。
- encounter 条目保留物种／形态身份、等级、概率、方式、条件以及 Alpha、Titan、Totem、Raid、固定遭遇和太晶属性等标记；不能唯一确认的形态必须显式标记歧义。
- 现代地点来自 PokeAPI 与固定 PKHeX 提交的规范化 overlay；来源、许可和形态规则见 [DEX_FORMS.md](DEX_FORMS.md)。
- 默认图与有可靠来源的差异形态媒体进入 archive；缺少来源的世代或形态不伪造图片。当前媒体与道具完整性由 v19 审计文件记录。
- 根 manifest 必须包含版本、前缀、数量、完整性、schema feature、archive URL/SHA/大小与遭遇覆盖信息；客户端以根 manifest 协商升级。

## R2 结构

```text
titodex-dex/
├── bundle-manifest.json        # 最后更新的活跃指针
├── v2/ …                       # 不修改
├── v3/ …                       # 不覆盖、不删除
├── v4/ …                       # v6 回滚
└── v5/
    ├── manifest.json
    ├── summaries.json
    ├── dex_catalog.json
    ├── details/1.json … 1025.json
    ├── sprites/1.png … 1025.png
    ├── sprites/forms/*.png     # 选择性形态小图
    ├── artwork/1.png …         # 默认形态按需大图
    ├── moves.json / abilities.json / types.json / items.json …
    ├── l10n/zh/*.json
    ├── maps/hgss_map_list.json
    ├── config/app_config.json
    ├── game_icons/*.png
    ├── type_icons/*.png
    ├── bundle-v14.tar.zst      # Offline APK 仍复用的紧凑种子
    └── bundle-v19.tar.zst      # 当前生产 archive；旧 archive 保留作回滚
```

`bundle.tar.zst` 解压后的根直接对应 App 文档目录 `dex_offline/`，不包含 `v5/`
这一层。所有详情、摘要、默认清晰图、
选择性形态小图、l10n、maps、config 和引用索引必须进入 archive。
v14 起 `sprites/` 是离线默认图的唯一规范副本，archive 不再重复携带
`artwork/`；在线详情仍可读取 R2 中既有的 loose `artwork/` 对象。

## 构建与审计

当前生产 v19 已完成发布。未来版本必须以线上 v19 为只读基线，新建版本专用 patch、
审计与 workflow，并以精确生产版本作为上传前置条件。通用校验入口：

v20 的本地候选基础设施、overlay provenance、稳定实体索引和 manifest-last 隔离布局见
[DEX_BUNDLE_V20.md](DEX_BUNDLE_V20.md)。它只构建并验证候选，不包含上传或生产切换能力。

```bash
pip install -r tools/dex_bundle_requirements.txt
python3 tools/audit_encounter_coverage.py <staging> --strict
python3 tools/audit_form_coverage.py <staging> --strict
python3 tools/audit_dex_golden_samples.py <staging> --strict
python3 tools/verify_dex_upload_tree.py <upload-tree>
```

v19 的版本专用构建与审计脚本仍保留在 `tools/`；v7–v18 的演进细节可从脚本与
Git 历史追溯，不作为下一次发布说明。需要重建 PKHeX overlay 时使用
`tools/generate_pkhex_encounter_overlays.py` 并固定、验证上游 commit；不能唯一确认的
form 只保留物种并标记歧义。

### v20 基础参考资料候选

`patch_dex_bundle_v20_reference.py` 只读复制完整 v19 staging，并从
`data/dex/reference_v20_sources.json` 固定的 PokéAPI/api-data 提交补齐招式、特性、
道具与按世代机制资料，同时把 v19 APK 中已经审计的招式／道具版本矩阵纳入 bundle。
它不会调用 52Poké、不会上传，也不会切换根 manifest；输出的根 manifest 明确带有
`candidate=true`，文件名也保留 `.candidate.json`。

```bash
python3 -m unittest tools.test_patch_dex_bundle_v20_reference
python3 tools/patch_dex_bundle_v20_reference.py \
  --base-staging <immutable-v19-staging> \
  --base-root-manifest <immutable-v19-root-manifest> \
  --output dist/dex-v20-candidate
python3 tools/verify_dex_v20_reference.py \
  dist/dex-v20-candidate/staging
```

可用 `--api-data <checkout>` 复用已经下载的数据；脚本会验证 HEAD 与锁文件中的提交
完全一致。候选内的 `reference_v20_audit.json` 记录真实覆盖率和未解析条目，中文缺失
保留语言／fallback 标记，不自动翻译或编造。正式发布仍需独立的 v20 workflow、生产
版本前置检查、完整上传树审计和人工批准。

## Offline 紧凑种子 v14

v14 只改变 archive 的媒体布局，不改任何图鉴 JSON、进化链或图片内容。脚本逐文件
比较 `artwork/<path>` 与 `sprites/<path>` 的大小和 SHA-256；1,340 对必须全部字节一致，
否则立即拒绝构建。验证通过后只从 archive 删除 `artwork/`，R2 既有 loose artwork
不删除。archive 使用新的不可变 key `/v5/bundle-v14.tar.zst`，根 manifest 最后才切换。

```bash
python3 -m unittest tools/test_patch_dex_bundle_v14_compact_media.py
python3 tools/patch_dex_bundle_v14_compact_media.py
python3 tools/verify_dex_upload_tree.py dist/dex-v14-prerelease/upload
```

发布时实测：删除 `53,285,462` raw duplicate bytes；v13 archive
`106,743,740` bytes → v14 `54,746,615` bytes，压缩包减少 `51,997,125` bytes
（48.7%）。解包后仍有 1,025 detail、1,340 sprite、421 道具图标，
`artwork/` 为 0。v14 已不再是线上根 manifest 指向的最新版，但其不可变 archive
继续由 Offline APK 复用；安装后的数据更新仍由线上 v19 manifest 决定。

## 两阶段发布与回滚

`.github/workflows/upload-dex-bundle.yml` 是已经完成使命的 v19 专用 workflow：它要求
线上 bundleVersion 仍为 v18，从已验证的 v18 archive 恢复只读基座，只 stage 变化
对象，最后切换根 manifest。生产现已为 v19，因此不得再次使用该 workflow 发布；
下一版需复制其安全结构并把输入、路径、测试和精确生产前置版本一起升级。
更早的一次性 workflow 已从工作树移除，可从 Git 历史追溯；本地底层工具
`tools/publish_dex_bundle_incremental.py` 仍须遵守相同前置检查。
v19 当时使用的底层两阶段命令（历史复现）：

```bash
# 阶段一：上传并校验所有 /v5/ 对象
python3 tools/upload_dex_bundle_r2.py dist/dex-v19-incremental \
  --cdn-prefix v5 --phase objects

# 阶段二：只有阶段一全部成功后才更新根 manifest
python3 tools/upload_dex_bundle_r2.py dist/dex-v19-incremental \
  --cdn-prefix v5 --phase manifest
```

上传器优先使用 `R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY` 的 boto3 路径；没有时使用
Wrangler OAuth 或 `CLOUDFLARE_API_TOKEN`。两条路径都遵守 manifest-last。

切换后验证：

```bash
curl -fsS https://dex.tito.cafe/bundle-manifest.json | jq .
curl -fsS 'https://dex.tito.cafe/cdn-health?probe=1' | jq .
```

发布异常时，把**发布前备份的上一版根 manifest** 重新写回
`bundle-manifest.json` 即可回退。因为增量发布只新增/更新 `/v5/`
下的 key，旧 archive 的 SHA 仍然有效。不要删除或修改 `/v4/`；在线 JSON
会从 v5 自动回退 v4/v3/v2。

## Worker

生产分支是 `deploy/dex-cdn`，根目录 `cloudflare/dex-cdn`。Worker：

- 对任意 `/vN/` 对象使用长期 immutable 缓存；根 manifest 使用短缓存。
- 从根 manifest 动态解析活跃前缀进行深度探活。
- 合法的版本 sprite 缺失可回退默认 sprite 或 artwork，并通过响应头说明。
- 每周触发 l10n，同步；每六小时运行深度探活并按配置告警。
- `/bundle/latest` 按 manifest 跳转 archive。

推送 Worker 前：

```bash
cd cloudflare/dex-cdn
npm ci
npm run dry-run
```

部署与绑定见 [cloudflare/dex-cdn/DEPLOY.md](../cloudflare/dex-cdn/DEPLOY.md)，权限见
[PERMISSIONS.md](PERMISSIONS.md)。

## 增量 l10n

`stage_l10n_upload.py` 与 `sync-l10n-catalog.yml` 只更新当前 `/v5/l10n`、maps 和 config；
不得覆写 `/v4/`。l10n 同步不改变 bundleVersion 或 archive SHA。若需要让根 manifest 的
`l10nVersion` 生效，必须读取当前根 manifest、只合并允许字段，并仍保持 archive 指针不变。
当前命令还必须显式传 `--expected-bundle-version 19`；线上版本不一致、SHA 缺失或拉取失败
都会中止上传。发布下一版 bundle 时同步更新 workflow 中的精确前置版本，不允许退回宽松的
`>=` 判断。

## 发布验收

- 根 manifest：v19、v5、1025、complete、archive SHA 正确。
- `/v5/manifest.json`、摘要、1025 详情、1025 默认清晰图、选择性形态小图、archive 可读。
- archive 与上传树资源审计通过；没有批量 `artwork/forms`。
- 现代精确版本覆盖和金样本通过；所有地点有可显示中文标签。
- 深度健康 `ok=true`，并实测合法 sprite 回退、v5 在线读取和 v4 回滚路径。
