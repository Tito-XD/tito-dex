# TitoDex 中文对照表（Master zh-Hans catalog）

PokeAPI 的 **`zh-Hans`** 字段覆盖宝可梦、招式、特性、道具、性格等名称，但 **地点（location-area）没有官方中文**。TitoDex 在此维护一份可版本化的对照表，供 App 运行时与 CDN bundle 构建共用。

地点条目中的 `source` 会记录解析来源。`source: 52poke_wiki` 的中文地点名来自[神奇宝贝百科](https://wiki.52poke.com/)（CC BY-NC-SA 3.0）；`source: bulbapedia_langlink` 来自 [Bulbapedia](https://bulbapedia.bulbagarden.net/wiki/Bulbapedia:Copyrights) 的中文跨语言标题（CC BY-NC-SA 2.5）。两者均通过 OpenCC 转为项目统一的简体中文；复用或发布这些条目时须保留署名、非商业与相同方式共享条件。

## 目录结构

```
data/l10n/zh/
  manifest.json              # 生成时间、条目数量
  species.json               # 全国图鉴 1–1025：nameEn / nameZh / genusZh
  moves.json                 # 招式 + categoryZh / typeZh
  abilities.json             # 特性 + descriptionZh
  items.json                 # 道具 + categoryZh
  natures.json               # 性格 + 升降能力中文
  egg_groups.json
  types.json
  move_categories.json
  stats.json
  location_areas.json        # PokeAPI location-area slug → labelZh ★
  location_areas_unresolved.json  # 仍缺中文、暂用英文名的 slug 列表
  hgss_map_ids.json          # HGSS 存档 map index → labelZh
  seeds/
    location_names_en_zh.json      # 手动补充：英文地名 → 中文
    location_area_slugs.json       # 手动补充：slug → 中文
```

运行时精简版（仅 slug→中文）由 `tools/generate_zh_catalog_assets.py` 写入：

```
flutter/assets/l10n/zh/
  location_area_labels.json
  hgss_map_labels.json
```

## 拉取 / 更新

```bash
# 从 PokeAPI 拉全量对照（地点约需数分钟）
python3 tools/fetch_zh_catalog.py

# 尝试用 52PokéWiki 补全仍为英文的地点名
python3 tools/fetch_52poke_location_zh.py --limit 50

# 生成 Flutter assets
python3 tools/generate_zh_catalog_assets.py

# 可选：重建 CDN bundle 时自动读 location_areas.json
python3 tools/build_dex_bundle.py ...
```

## 地点中文解析优先级

1. `seeds/location_area_slugs.json` + 内置 slug 表  
2. `route-N-*` → `N号道路`  
3. `seeds/location_names_en_zh.json` + 内置英文地名表（按 PokeAPI 英文地名匹配）  
4. 子区域后缀（`-1f` / `-b1f`）拼到父地点中文后  
5. 52PokéWiki 英文重定向页对应的中文标题（OpenCC 转为 `zh-Hans`）
6. Bulbapedia 对应页面的中文跨语言标题（同样转为 `zh-Hans`）
7. 仍无中文 → 使用 PokeAPI **英文地名**（不再显示裸 slug 或数字）

HGSS 存档 **map id**（纯数字 slug）走 `hgss_map_ids.json`。

## 覆盖率（参考）

运行 `python3 tools/fetch_zh_catalog.py` 后查看 `manifest.json`。

- **物种/招式/特性**：优先 PokeAPI `zh-Hans`，无则 `zh-Hant`，再无则 `nameZh = nameEn`
- **地点**：PokeAPI 无中文；靠 `location_names_en_zh` + slug 表 + 英文复合规则（如「随意镇」+「遗迹」）
- **存档 map id**：`hgss_map_ids.json`
- **数字 location-area id**：encounter URL 用 id 作 slug 时，assets 里同时写入 id→中文

仍显示英文的地点见 `location_areas_unresolved.json`，可补 `seeds/` 后重拉。

编辑 `data/l10n/zh/seeds/location_names_en_zh.json`：

```json
{
  "Some Cave": "某洞窟"
}
```

然后重新运行 `fetch_zh_catalog.py`（或只改 seeds 后跑 `generate_zh_catalog_assets.py` 若只改 override）。

## 与 App 的关系

- **图鉴详情 · 获取**：`resolveObtainAreaLabelZh()` → 先读 bundled `location_area_labels.json`
- **在线 PokeAPI 兜底**：同样走 `resolveObtainAreaLabelZh`（已统一）
- **CDN 离线 bundle**：`build_dex_bundle.py` 写入 `areaLabelZh` 时使用同一份 `location_areas.json`
