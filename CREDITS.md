# TitoDex 数据来源、许可与权利说明

[English](#english)

TitoDex 会在构建阶段整理公开 API、社区资料与技术文档，并在 App 中以离线数据、检索结果或媒体候选形式呈现。以下列表是当前源码与 v19 数据管线的来源索引；具体记录若带有更细的来源字段，以记录内标注为准。开放许可只覆盖相应来源明确授权的内容，不自动覆盖 Pokémon 官方媒体或商标。

## 数据与文字

- [PokéAPI](https://pokeapi.co/) 与 [PokéAPI 数据仓库](https://github.com/PokeAPI/pokeapi)：物种、形态、属性、能力值、特性、招式、道具、进化、版本与基础地点资料。其代码／数据仓库以 BSD-3-Clause 发布；Pokémon 名称与角色商标不因此获得授权。
- [52Poké Wiki／神奇宝贝百科](https://wiki.52poke.com/)：部分中文图鉴描述、道具说明、携带道具、地点标签与体形标签；相关百科原创内容依站点标注的 [CC BY-NC-SA 3.0](https://creativecommons.org/licenses/by-nc-sa/3.0/) 使用。经其文件页定位的官方游戏图像只把文件页作为来源记录，不宣称由百科的开放许可重新授权。
- [Bulbapedia](https://bulbapedia.bulbagarden.net/)：道具分组思路及少量地点语言链接；其原创百科内容依 CC BY-NC-SA 2.5 使用。
- [PKHeX](https://github.com/kwsch/PKHeX)：固定提交导出的现代作品遭遇表，经 TitoDex 规范化后作为版本补全数据；PKHeX 与对应衍生覆盖数据依 GPL-3.0-or-later，App 不嵌入或执行 PKHeX。固定提交与细节见 [PKHEX_LICENSE.md](data/encounters/PKHEX_LICENSE.md)。
- [Project Pokémon](https://projectpokemon.org/)：HGSS 存档结构、第四世代 Pokémon 数据结构与 HGSS 地图编号等技术参考。TitoDex 只读导入的偏移与解密实现依据这些公开技术文档交叉验证。

## 图像、动画与音频

- [PokéAPI/sprites](https://github.com/PokeAPI/sprites)：游戏精灵、HOME／官方绘图、道具图标、叫声链接及部分动画的上游索引。仓库同时注明部分第五世代风格与 Showdown 动画由 Smogon／Pokémon Showdown 社区贡献；TitoDex 保留这些上游 Credits。
- [Pokémon Showdown](https://pokemonshowdown.com/) 与 Smogon 社区创作者：由 PokéAPI/sprites 提供的部分社区动画与扩展精灵。
- [PokéSprite](https://github.com/msikma/pokesprite) `c5aaa610ff2acdf7fd8e2dccd181bca8be9fcb3e`：18 个属性图标的 Gen 8 图标集，项目代码／整理以 MIT 发布；随包许可证见 [`pokesprite-MIT.txt`](flutter/assets/licenses/pokesprite-MIT.txt)。MIT 不改变底层 Pokémon 素材的权利状态。
- [SteamGridDB](https://www.steamgriddb.com/) 社区来源：部分第一至第五世代游戏入口图标。原下载管线没有保留投稿者身份，因此不猜测作者；现已在 [`SOURCES.json`](flutter/assets/game_icons/SOURCES.json) 逐文件保留 CDN key、来源 URL 与这一限制。各素材权利仍归相应权利人，SteamGridDB 并不代表对 TitoDex 的认可。
- Pokémon HOME、各代游戏图标、角色绘图、游戏精灵与音频等官方素材：仅用于学习向资料检索与个人游玩辅助，其著作权与商标权归相应权利人所有。

## 字体、依赖与外部工具

- [Nunito](https://github.com/googlefonts/nunito)：TitoDex 随 APK 内置的 UI 字体；Copyright 2014 The Nunito Project Authors，依 [SIL Open Font License 1.1](flutter/assets/licenses/nunito-OFL.txt) 分发。
- Flutter／Dart 与各 pub package：构建时由 Flutter 生成 package notices；App 设置页提供“查看开源许可证”入口。直接随 APK vendored 的 Nunito、PokéSprite 与 Neroli’s Lab 公式移植许可证／NOTICE 由 TitoDex 额外注册。
- [Neroli’s Lab](https://github.com/nerolis-lab/nerolis-lab) `cb533f240a0551da315151c310b4dbd165091672`：TitoDex 的 Pokémon Sleep 二级工具页移植其睡眠分数、跨午夜时长、19 种食材基础能量、1–70 级食谱倍率与料理能量公式；依 Apache-2.0 使用。完整许可证与上游 NOTICE 随 App 打包，见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。TitoDex 未复制其账号、API、完整食谱库、队伍生产或长期模拟服务，完整能力仍指向 Neroli’s Lab。

许可证正文与打包方式汇总见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

数据包内还随附 `ITEMS_ATTRIBUTION.txt`、`FLAVOR_ATTRIBUTION.txt` 与 `HELD_ITEMS_ATTRIBUTION.txt`，用于把具体构建批次追溯到来源页面和许可。

## 非官方声明

TitoDex 是非官方、非商业、仅面向学习与个人游玩辅助的工具，与 Nintendo Co., Ltd.、Creatures Inc.、GAME FREAK inc.、The Pokémon Company 及其关联公司不存在隶属、授权、赞助或认可关系。

Pokémon、宝可梦、角色、游戏名称、图像、音频与商标归各自权利人所有。TitoDex 不提供游戏 ROM、密钥、付费内容或存档修改功能。列出第三方来源仅为履行署名与说明用途，不表示这些来源认可 TitoDex，也不改变各素材原有的许可或权利状态。

---

## English

TitoDex compiles public APIs, community references, and technical documentation into offline reference data and media candidates. Record-level provenance, when present, takes precedence over this summary. An open license only covers material expressly released under it; it does not automatically relicense official Pokémon media or trademarks.

- **PokéAPI / PokéAPI data repository** — species, forms, types, stats, abilities, moves, items, evolution, versions, and baseline locations; repository license: BSD-3-Clause.
- **52Poké Wiki** — selected Chinese text, held-item data, locations, and body labels; original wiki content is used under CC BY-NC-SA 3.0. Wiki file pages used to locate official game media are recorded as provenance and are not treated as relicensing those files.
- **Bulbapedia** — item grouping inspiration and selected location language links; original wiki content is licensed under CC BY-NC-SA 2.5.
- **PKHeX** — normalized modern-game encounter overlays from a pinned commit; GPL-3.0-or-later. TitoDex neither embeds nor executes PKHeX.
- **Project Pokémon** — HGSS save structure, Gen IV Pokémon structure, and HGSS map-index technical references.
- **PokéAPI/sprites and Pokémon Showdown / Smogon contributors** — upstream sprite, animation, cry, artwork, and item-icon sources. Rights and upstream contributor credits remain with their respective owners.
- **PokéSprite** — the vendored Gen 8 type-icon set, pinned at `c5aaa610ff2acdf7fd8e2dccd181bca8be9fcb3e`; MIT project license, with underlying Pokémon-media rights unchanged.
- **SteamGridDB community sources and official Pokémon media** — selected game-icon sources. Exact retained source keys and URLs are in `flutter/assets/game_icons/SOURCES.json`; the original pipeline did not retain SteamGridDB uploader identities.
- **Nunito** — bundled UI font, Copyright 2014 The Nunito Project Authors, SIL OFL 1.1.
- **Neroli’s Lab** — sleep-score, overnight-duration, 19 ingredient-value, recipe-level, and cooking-strength helpers are ported from pinned commit `cb533f240a0551da315151c310b4dbd165091672` under Apache-2.0. TitoDex bundles the upstream license and NOTICE, while account/API access, the full recipe catalog, team production, and long-term simulation remain external links.

Flutter package notices plus the vendored Nunito, PokéSprite, and Neroli’s Lab formula-port licenses/notices are available from Settings → Open-source licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the repository paths.

TitoDex is an unofficial, non-commercial tool intended only for learning and personal gameplay assistance. It is not affiliated with, authorized by, sponsored by, or endorsed by Nintendo Co., Ltd., Creatures Inc., GAME FREAK inc., The Pokémon Company, or their affiliates. Pokémon names, characters, game titles, images, audio, and trademarks belong to their respective owners. TitoDex does not provide game ROMs, keys, paid content, or save editing.
