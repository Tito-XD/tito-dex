# TitoDex 数据来源、许可与权利说明

[English](#english)

TitoDex 会在构建阶段整理公开 API、社区资料与技术文档，并在 App 中以离线数据、检索结果或媒体候选形式呈现。以下列表是当前源码与 v19 数据管线的完整来源索引；具体记录若带有更细的来源字段，以记录内标注为准。

## 数据与文字

- [PokéAPI](https://pokeapi.co/) 与 [PokéAPI 数据仓库](https://github.com/PokeAPI/pokeapi)：物种、形态、属性、能力值、特性、招式、道具、进化、版本与基础地点资料。其代码／数据仓库以 BSD-3-Clause 发布；Pokémon 名称与角色商标不因此获得授权。
- [52Poké Wiki／神奇宝贝百科](https://wiki.52poke.com/)：部分中文图鉴描述、道具说明、携带道具、地点标签、体形标签及媒体补全；相关百科原创文字依站点标注的 CC BY-NC-SA 4.0 使用。
- [Bulbapedia](https://bulbapedia.bulbagarden.net/)：道具分组思路及少量地点语言链接；其原创百科内容依 CC BY-NC-SA 2.5 使用。
- [PKHeX](https://github.com/kwsch/PKHeX)：固定提交导出的现代作品遭遇表，经 TitoDex 规范化后作为版本补全数据；PKHeX 与对应衍生覆盖数据依 GPL-3.0-or-later，App 不嵌入或执行 PKHeX。固定提交与细节见 [PKHEX_LICENSE.md](data/encounters/PKHEX_LICENSE.md)。
- [Project Pokémon](https://projectpokemon.org/)：HGSS 存档结构、第四世代 Pokémon 数据结构与 HGSS 地图编号等技术参考。TitoDex 只读导入的偏移与解密实现依据这些公开技术文档交叉验证。

## 图像、动画与音频

- [PokéAPI/sprites](https://github.com/PokeAPI/sprites)：游戏精灵、HOME／官方绘图、道具图标、叫声链接及部分动画的上游索引。仓库同时注明部分第五世代风格与 Showdown 动画由 Smogon／Pokémon Showdown 社区贡献；TitoDex 保留这些上游 Credits。
- [Pokémon Showdown](https://pokemonshowdown.com/) 与 Smogon 社区创作者：由 PokéAPI/sprites 提供的部分社区动画与扩展精灵。
- [SteamGridDB](https://www.steamgriddb.com/) 社区投稿页：部分第一至第五世代游戏入口图标的来源页。各投稿与其中商标素材的权利仍归原作者或相应权利人，SteamGridDB 并不代表对 TitoDex 的认可。
- Pokémon HOME、各代游戏图标、角色绘图、游戏精灵与音频等官方素材：仅用于学习向资料检索与个人游玩辅助，其著作权与商标权归相应权利人所有。

数据包内还随附 `ITEMS_ATTRIBUTION.txt`、`FLAVOR_ATTRIBUTION.txt` 与 `HELD_ITEMS_ATTRIBUTION.txt`，用于把具体构建批次追溯到来源页面和许可。

## 非官方声明

TitoDex 是非官方、非商业、仅面向学习与个人游玩辅助的工具，与 Nintendo Co., Ltd.、Creatures Inc.、GAME FREAK inc.、The Pokémon Company 及其关联公司不存在隶属、授权、赞助或认可关系。

Pokémon、宝可梦、角色、游戏名称、图像、音频与商标归各自权利人所有。TitoDex 不提供游戏 ROM、密钥、付费内容或存档修改功能。列出第三方来源仅为履行署名与说明用途，不表示这些来源认可 TitoDex，也不改变各素材原有的许可或权利状态。

---

## English

TitoDex compiles public APIs, community references, and technical documentation into offline reference data and media candidates. Record-level provenance, when present, takes precedence over this summary.

- **PokéAPI / PokéAPI data repository** — species, forms, types, stats, abilities, moves, items, evolution, versions, and baseline locations; repository license: BSD-3-Clause.
- **52Poké Wiki** — selected Chinese text, held-item data, locations, body labels, and media gap filling; original wiki text is used under CC BY-NC-SA 4.0 as marked by the site.
- **Bulbapedia** — item grouping inspiration and selected location language links; original wiki content is licensed under CC BY-NC-SA 2.5.
- **PKHeX** — normalized modern-game encounter overlays from a pinned commit; GPL-3.0-or-later. TitoDex neither embeds nor executes PKHeX.
- **Project Pokémon** — HGSS save structure, Gen IV Pokémon structure, and HGSS map-index technical references.
- **PokéAPI/sprites, Pokémon Showdown / Smogon contributors, SteamGridDB community pages, and official Pokémon media** — upstream sprite, animation, cry, artwork, item-icon, and selected game-icon sources. Rights and upstream contributor credits remain with their respective owners.

TitoDex is an unofficial, non-commercial tool intended only for learning and personal gameplay assistance. It is not affiliated with, authorized by, sponsored by, or endorsed by Nintendo Co., Ltd., Creatures Inc., GAME FREAK inc., The Pokémon Company, or their affiliates. Pokémon names, characters, game titles, images, audio, and trademarks belong to their respective owners. TitoDex does not provide game ROMs, keys, paid content, or save editing.
