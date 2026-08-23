# Dex bundle v20 候选构建契约

v20 是以已验证的 v19 staging 为只读基底、只增加或修正数据的新候选版本。v19
不会被重写；候选构建也不会上传 R2、切换根 manifest 或触发 App 发布。

## 候选树

```text
dist/dex-v20-candidate/
├── staging/                                  # archive 内的最终运行目录
│   ├── manifest.json                         # version=20, releaseState=candidate
│   ├── entity_index.json                     # 最终运行实体的稳定索引
│   ├── provenance.json                       # 对象/字段来源、范围与新鲜度
│   └── …                                     # v19 全部数据 + 已声明 overlay
├── upload/v5/                                # 待上传 loose objects + archive
│   └── bundle-v20.tar.zst
├── release-manifest/
│   └── bundle-manifest.v20.candidate.json    # 待受保护发布任务补全的 manifest
└── build-report.json                         # v19 指纹、修复与审计摘要
```

候选目录故意不生成 `upload/bundle-manifest.json`，待发布 manifest 也不含生产 URL。
这能防止通用上传脚本误把尚未验收的数据切成线上版本。正式 release 目录只能由
`dex_v20_release_gate.py` 在三重验证通过后生成，并继续把 objects、待切换根 manifest
和 v19 rollback manifest 物理分开。

## 来源、范围和新鲜度

契约位于：

- `data/dex/bundle_provenance.schema.json`
- `data/dex/bundle_overlay.schema.json`
- `data/dex/entity_index.schema.json`

`provenance.json` 的每条 object rule 都有对象级 metadata，也可以通过 JSON Pointer
pattern 给字段单独覆写 metadata。metadata 同时记录：

- `sourceIds`、生成／规范化／审核方式和置信度；
- `exactGame`、`versionGroup`、`generation`、`franchiseStable` 或 `unscoped`；
- `sourceAsOf`、最后检查时间和新鲜度类别；
- 本地命中后的处理：`local-authoritative`、`local-evidence`、
  `online-verify` 或 `offline-warning`。

从 v19 原样继承但没有字段级范围的数据默认为 `online-verify`，不会再因为本地有一条
旧记录就阻止在线核验。名字、稳定 ID、属性等跨版本稳定事实可以标为
`local-authoritative`；招式数值／效果、特性、道具价格和可获得性等默认只能作为
`local-evidence`。离线时仍可回答，但调用方必须根据 metadata 显示范围或过期提示。

所有要求署名的 source 都必须引用候选 staging 内实际存在且非空的 notice 文件；验证器
会拒绝未知 source ID、缺失 notice 或没有 provenance rule 的 JSON 对象。

## 稳定实体索引

`entity_index.json` 只从候选的最终运行文件生成，不把宽泛 l10n 标签直接当作实体：

- Pokémon：`pokemon:<national-id>`；
- 招式：`move:<pokeapi-id>`；
- 特性：`ability:<pokeapi-id>`；
- 道具：`item:<slug>`。

道具使用 slug 是有意的：v19 全量道具目录中的补充记录与旧 l10n 目录不共享可靠的数值
ID。每条记录保留兼容 App 的 `kind`、`id`、`slug`、`nameZh`、`nameEn`、可选 aliases，
并附有指回运行 JSON 的 `ref`。

标签只负责补充 alias。未映射标签、没有标签的运行实体、同 ID 名称冲突以及重复中英文名
都进入 `audit`，不会生成无法打开的 phantom entity。验证器会重新从最终目录生成一次索引
并逐字节比较，因此任何 overlay 后忘记重建索引都会失败。

## Overlay 输入

每一批补充数据应输出独立目录，而不是修改 v19 staging：

```text
dist/overlays/moves-v2/
├── overlay-provenance.json
├── moves.json
└── MOVES_ATTRIBUTION.txt       # 仅在 source 要求署名时需要
```

`overlay-provenance.json` 必须声明 `overlayId`、`baseBundleVersion=19`、sources 和
object/field rules。优先级 `20..99` 用来覆盖 v19 的继承 metadata；优先级 100 留给构建器
生成的 manifest、entity index 与 provenance。overlay 不能替换这些生成文件、根 manifest
或 archive，也不能包含 symlink。任何 overlay 文件没有匹配的 provenance rule 时构建立即
失败。

## 本地构建与验证

先准备本地、已验证的 v19 staging 与它对应的根 manifest。路径由维护者环境提供，不写入
仓库或日志：

```bash
python3 tools/build_dex_v20_candidate.py \
  --base-staging "$TITODEX_V19_STAGING" \
  --base-root-manifest "$TITODEX_V19_MANIFEST" \
  --overlay dist/overlays/moves-v2 \
  --overlay dist/overlays/items-v2 \
  --output dist/dex-v20-candidate

python3 tools/verify_dex_v20_candidate.py dist/dex-v20-candidate
```

构建器在复制前后计算完整 v19 tree SHA-256；不一致就中止。它会把 summaries 回写到候选
`dex_catalog.json`，消除旧派生索引漂移，然后在所有 overlay 落地后生成 entity index、
provenance 和 archive。

验证器检查：

- summaries、1025 details、dex catalog 三份 summary 完全一致；
- catalog 中的 moves／abilities 与运行文件一致；
- detail、move learner、ability reverse index、held item、evolution 和可选版本矩阵引用；
- 每个 JSON 的 provenance、source、notice、scope、freshness 与 fallback policy；
- loose `/v5/` 树和 archive 与 staging 文件逐项 SHA-256 一致；
- 候选目录没有可直接发布的根 manifest。

仅需快速检查脚本或 fixture 时可加 `--no-archive`；该输出不能通过完整候选验证，也不能
用于发布。

## 受保护发布闸门（默认只演练）

`.github/workflows/release-dex-bundle-v20.yml` 是 v20 专用入口。所有布尔输入默认
`false`；默认运行只下载、构建、验证和保存候选，不上传对象、不部署 Worker，也不切换
根 manifest。开始运行前，维护者从本地批准的 v19 根 manifest 计算 SHA-256，并把该
摘要填入 dispatch 输入：

```bash
shasum -a 256 "$TITODEX_V19_MANIFEST"
```

闸门不只判断 `bundleVersion=19`，还会执行以下绑定：

1. 线上根 manifest 的原始 SHA-256 必须等于上述批准摘要；
2. 线上与本地批准 manifest 的 archive SHA-256／大小必须完全一致；
3. 下载 archive 的字节摘要／大小必须匹配，并与解包后的 v19 staging tree 逐文件绑定；
4. v20 `build-report.json` 的 base root SHA 和 base tree SHA 必须指向同一份 v19；
5. foundation、reference、gameplay 三个完整 verifier 全部通过后，才生成 release 目录。

生产地址仅从运行时 secret `TITODEX_DEX_CDN_BASE` 读取；Cloudflare 凭据继续使用现有
`CLOUDFLARE_API_TOKEN`、`CLOUDFLARE_ACCOUNT_ID`，或现有 R2 access-key secret。
bucket 从 `cloudflare/dex-cdn/wrangler.toml` 的既有 `DEX_BUCKET` binding 解析。任何
secret、Account ID、生产地址或 bucket URL 都不写入源码、文档或命令输出。

发布分成两个独立批准动作：

- `upload_objects=true`：进入受保护的 `dex-production` environment，只上传 release
  plan 列出的 `/v5/` objects；逐对象确认上传成功，S3 路径逐对象 HEAD，所有路径再对
  archive、manifest、索引、审计文件和至少 64 个确定性样本做直接内容回读与 SHA-256
  比较，输出绑定 release-plan SHA 的 object receipt。根 manifest 此时仍不会上传。
  上传任务支持安全断点续传：并发回读每个远端对象并比较完整 SHA-256，已匹配对象直接
  计入 receipt，缺失或不一致对象才重新上传并立即完整回读。任务被取消或超时后可以用
  同一份 V19 指纹重新触发，不会从头重传已确认对象；上传 job 的超时只作为 180 分钟
  的异常兜底，不能代替逐对象校验。同一源码提交的候选时间戳固定为提交时间，因此重跑
  会生成逐字节相同的 archive；大对象覆盖后若第一次回读仍短暂看到旧字节，上传器会以
  有界退避重试完整 SHA-256，最终不一致仍会拒绝发布。
  使用仓库 API Token 时，它通过与 Wrangler 相同的 Cloudflare R2 对象 API 工作，但在
  单个 Python 进程中为各并发 worker 复用持久 HTTPS 会话；不新增凭据，也不降低完整
  SHA-256 核验要求。
- `publish_manifest=true`：必须与前项同时显式开启，并再次通过受保护 environment。
  切换前重新读取线上根 manifest，要求它仍是完全相同的已批准 v19；只有 object
  receipt 完整时，才单独写入根 `bundle-manifest.json`，随后验证线上返回的整份文件
  SHA 与批准的 v20 manifest 完全一致。

本地上传器 `upload_dex_v20_release.py` 同样默认 dry-run。即使传入 `--execute`，objects、
manifest 与 rollback 仍是三个互斥 phase；manifest 额外要求 `--publish-manifest` 和有效
receipt，rollback 额外要求 `--restore-v19`。没有 `all` 模式。

每次准备任务会把精确的 v19 根 manifest 另存为 90 天 rollback artifact。切换失败时，
使用 `.github/workflows/rollback-dex-bundle-v20.yml`，填写原 release run ID 与同一份 v19
manifest SHA，并显式设置 `restore_v19=true`。它只恢复根 manifest、执行内容回读和线上
确认；不会删除已上传的 v20 objects，不会删除、覆盖或访问 `/v4/`。
