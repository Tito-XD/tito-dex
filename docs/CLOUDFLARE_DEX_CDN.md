# TitoDex 图鉴 CDN 与 bundle v6

> **受众：** Cloudflare / R2 运维与发布维护者。不要把生产 CDN 直链复制到 App 文案或 GitHub Release 说明。

## 当前版本

| CDN 前缀 | bundleVersion | 物种 | 状态 |
| --- | ---: | ---: | --- |
| `/v4/` | 6 | 1025 | 当前生产：完整形态、精确版本地点、现代游戏 overlay |
| `/v3/` | 5 | 1025 | 保留不动，供旧客户端和 v6 回滚 |
| `/v2/` | 4 | 493 | 遗留客户端 |

0.7.0 App 访问 JSON 时按 `v4 → v3 → v2` 回退。根
`bundle-manifest.json` 是短缓存的活跃指针；所有版本前缀对象不可变。

```bash
TITODEX_DEX_CDN_BASE=https://dex.tito.cafe
TITODEX_DEX_BUNDLE_URL=https://dex.tito.cafe/v4/bundle.tar.zst
TITODEX_DEX_BUNDLE_VERSION=6
```

## v6 内容与 schema

- 全国图鉴 1–1025，`complete=true`。
- 每个多形态物种保存全部 form JSON：名称、分类、属性、种族值、特性、招式、身高体重、可用版本、出现地点和来源。
- 默认 1025 张小图继续保留。非外观且视觉不同的形态仅在可靠图片存在时额外保存一张小图；外观重复形态复用默认图；不批量复制形态高清 artwork。
- 出现地点同时保存版本组和精确版本，并保留 `speciesId / pokemonId / formKey / teraType / formAmbiguous / isAlpha / isTitan / isRaid / isFixedEncounter`。
- 现代地点来自 PokeAPI 加固定 PKHeX 提交的 GPL-3.0-or-later 规范化 overlay，详见 [DEX_FORMS.md](DEX_FORMS.md) 与 `data/encounters/PKHEX_LICENSE.md`。
- Champions 明确写入 `encounterCoverage.notApplicable`，不虚构野外地点。

根 manifest 的关键字段：

```json
{
  "bundleVersion": 6,
  "cdnPrefix": "v4",
  "pokemonCount": 1025,
  "formCount": 0,
  "formSpriteCount": 0,
  "complete": true,
  "exactVersionLocations": true,
  "schemaFeatures": {
    "pokemonForms": 2,
    "encounterFormIdentity": 3,
    "exactVersionLocations": 1
  },
  "archiveUrl": "https://dex.tito.cafe/v4/bundle.tar.zst",
  "archiveSha256": "<sha256>",
  "archiveSizeBytes": 0,
  "encounterSources": [],
  "encounterCoverage": {}
}
```

## R2 结构

```text
titodex-dex/
├── bundle-manifest.json        # 最后更新的活跃指针
├── v2/ …                       # 不修改
├── v3/ …                       # 不覆盖、不删除
└── v4/
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
    └── bundle.tar.zst
```

`bundle.tar.zst` 解压后的根直接对应 App 文档目录 `dex_offline/`，不包含 `v4/`
这一层。大图可以留在 CDN 上传树而不进入离线 archive；所有详情、摘要、默认小图、
选择性形态小图、l10n、maps、config 和引用索引必须进入 archive。

## 构建与审计

```bash
pip install -r tools/dex_bundle_requirements.txt

python3 tools/test_pokemon_forms.py
python3 tools/test_dex_bundle_v6.py

python3 tools/build_dex_bundle.py \
  --cdn-base https://dex.tito.cafe \
  --output dist/dex-v6 \
  --max-id 1025

python3 tools/audit_encounter_coverage.py dist/dex-v6/staging --strict
python3 tools/audit_form_coverage.py dist/dex-v6/staging --strict
python3 tools/audit_dex_golden_samples.py dist/dex-v6/staging --strict
python3 tools/verify_dex_upload_tree.py dist/dex-v6/upload
```

产物：

- `dist/dex-v6/staging/`：解压后目录。
- `dist/dex-v6/upload/v4/`：不可变对象上传树。
- `dist/dex-v6/upload/bundle-manifest.json`：最后切换的根指针。

PKHeX overlay 需要重新生成时：

```bash
python3 tools/generate_pkhex_encounter_overlays.py \
  --pkhex-root /path/to/PKHeX-at-pinned-commit
```

生成器会验证 PKHeX HEAD；不能唯一确认的 form 只保留物种并标记歧义。

## 两阶段发布与回滚

首选 GitHub Actions **Build and Publish Dex Bundle v6**。本地等价命令：

```bash
# 阶段一：上传并校验所有 /v4/ 对象
python3 tools/upload_dex_bundle_r2.py dist/dex-v6/upload \
  --cdn-prefix v4 --phase objects

# 阶段二：只有阶段一全部成功后才更新根 manifest
python3 tools/upload_dex_bundle_r2.py dist/dex-v6/upload \
  --cdn-prefix v4 --phase manifest
```

上传器优先使用 `R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY` 的 boto3 路径；没有时使用
Wrangler OAuth 或 `CLOUDFLARE_API_TOKEN`。两条路径都遵守 manifest-last。

切换后验证：

```bash
curl -fsS https://dex.tito.cafe/bundle-manifest.json | jq .
curl -fsS 'https://dex.tito.cafe/cdn-health?probe=1' | jq .
```

若 v6 发布异常，将预先备份的 v5 根 manifest 重新写到
`bundle-manifest.json`。不要删除 `/v4/`，也不要修改 `/v3/`；0.7.0 在线 JSON 仍可从
v4 自动回退 v3/v2。

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

`stage_l10n_upload.py` 与 `sync-l10n-catalog.yml` 只更新当前 `/v4/l10n`、maps 和 config；
不得覆写 `/v3/`。l10n 同步不改变 bundleVersion 或 archive SHA。若需要让根 manifest 的
`l10nVersion` 生效，必须读取当前根 manifest、只合并允许字段，并仍保持 archive 指针不变。

## 发布验收

- 根 manifest：v6、v4、1025、complete、archive SHA 正确。
- `/v4/manifest.json`、摘要、1025 详情、1025 默认小图、选择性形态小图、archive 可读。
- archive 与上传树资源审计通过；没有批量 `artwork/forms`。
- 现代精确版本覆盖和金样本通过；所有地点有可显示中文标签。
- 深度健康 `ok=true`，并实测合法 sprite 回退、v4 在线读取和 v3 回滚路径。
