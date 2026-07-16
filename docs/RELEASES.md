# Release History

This document is the public-copy reference for TitoDex GitHub Releases. Release titles and descriptions keep the product's voice and recognizable TitoDex details while avoiding private user data, internal discussion notes, and production CDN addresses.

## Distribution channels

| Channel | Current version | Purpose |
| --- | --- | --- |
| Lite APK | `v0.6.2.1` (`0.6.2.1+73`) | Recommended arm64-v8a download |
| Offline APK | `v0.6.2.1` (`0.6.2.1-offline+74`) | Larger package with the core dex bundle embedded |
| Source on `main` | `0.6.2+73` | Current default branch baseline |

Legacy `TitoDex-1.0.x-*` APKs and the `v1.0.0` tag belong to the deprecated pre-Flutter mock prototype. They remain available only as historical artifacts and do not represent the current product version.

## Release notes

| Tag | Standardized title | Product summary |
| --- | --- | --- |
| `v0.6.2.1` | TitoDex v0.6.2.1 · 自适应应用图标 | Replaces the inset circular launcher mark with full-bleed artwork so Android can apply each device's circle, squircle, rounded-square, or square adaptive mask naturally. |
| `v0.6.2` | TitoDex v0.6.2 · 同行大小与即时媒体 | Adds the companion size slider with raised height ceilings and pixel-crisp upscaling, bundles all starter GIFs and cries into the APK, and introduces a cancellable preload dialog when choosing any other companion. |
| `v0.6.1` | TitoDex v0.6.1 · 同行宝可梦与横屏布局 | Upgrades the standby companion to a frameless height-scaled animation with quotes, cries, and a toggle; bundles official Gen VI+ game icons into the header and pickers; adds a one-screen landscape home layout; and unifies secondary-page header sizing. (v0.6.0 was built but superseded before publication.) |
| `v0.5.51` | TitoDex v0.5.51 · Home 返回动画修正预发布 | Keeps Team and Search exit motion aligned with their entry edge and removes predictive-back progress from the three Home quick actions. |
| `v0.5.12` | TitoDex v0.5.12 预发布 · 首页动效拆分预览 | Splits the three Home actions into independent transitions: Dex keeps card expansion while Team and Search slide from their own screen edges. |
| `v0.5.11` | TitoDex v0.5.11 预发布 · 容器转场预览 | Fixes the solid-color overlay and Team/Search crashes during Home card expansion with a fade-through container transition. |
| `v0.5.5` | TitoDex v0.5.5 · 存档与同行体验更新 | Moves save sync to one explicitly selected file, adds native Android app selection, refines motion and the six-slot party card, and introduces standby companion interactions and the silhouette quiz. |
| `v0.5.2-rc.1` | TitoDex v0.5.2-rc.1 预发布 · 首页卡片展开修正 | Isolates the Hero surface from destination pages so Team, Dex, and Search stay interactive through the expansion. |
| `v0.5.1` | TitoDex v0.5.1 · Android 返回与转场 | Uses Android-standard navigation motion and predictive back, with Home quick-action cards expanding into Team, Dex, and Search. |
| `v0.5.0` | TitoDex v0.5.0 · 图鉴无感知加载 | Precomputed catalog keeps Dex lists, search, and reference filters responsive in both lite and offline packages. |
| `v0.4.99` | TitoDex v0.4.99 · Lite 与离线版本同步 | Aligns the full release source and provides matching lite and offline arm64 packages. |
| `v0.4.98` | TitoDex v0.4.98 · 图鉴版本标题修正 | Flavor-text cards now identify each game edition separately. |
| `v0.4.97-offline` | TitoDex v0.4.97-offline · 内置离线数据包 | Optional 61 MB build that seeds the core dex data without a first-run download. |
| `v0.4.97` | TitoDex v0.4.97 · 训练家卡文案调整 | Keeps the default “训练家 Tito” identity while simplifying punctuation. |
| `v0.4.96` | TitoDex v0.4.96 · 方屏训练家卡修正 | Aligns the square-screen trainer card with the dense portrait layout. |
| `v0.4.95` | TitoDex v0.4.95 · 首页与队伍体验更新 | Adds bootstrap loading, team editing, download progress controls, and Settings cleanup. |
| `v0.4.94` | TitoDex v0.4.94 · 设置与筛选性能优化 | Compacts Settings and paginates large Pokédex filter results. |
| `v0.4.93` | TitoDex v0.4.93 · 特性与出现地点增强 | Improves ability fallback, game labels, location coverage, and ability filtering. |
| `v0.4.92` | TitoDex v0.4.92 · 界面细节优化 | Combines the matchup card and lets the TitoDex dashboard title follow a custom trainer name. |
| `v0.4.91` | TitoDex v0.4.91 · 宝可梦与特性筛选 | Adds attacker Pokémon selection and limits abilities to valid choices. |
| `v0.4.85` | TitoDex v0.4.85 · 对战工具扩展 | Adds Terastal, held items, status effects, defensive abilities, and team shared weaknesses. |
| `v0.4.8` | TitoDex v0.4.8 · 世代与特性计算 | Adds generation-aware mechanics, ability modifiers, and blind-spot analysis. |
| `v0.4.7` | TitoDex v0.4.7 · 图鉴与首页更新 | Adds the generation sprite picker, corrects 1–1025 progress, and improves home/avatar layouts. |
| `v0.4.6` | TitoDex v0.4.6 · 资料筛选与离线同步 | Improves reference drill-down, sprite loading, type pickers, and offline update prompts. |
| `v0.4.5` | TitoDex v0.4.5 · 离线数据包拆分 | Moves labels, maps, and config into the independently updated offline bundle. |
| `v0.4.2` | TitoDex v0.4.2 · 公开文案与配置收整 | Removes infrastructure addresses from user-facing copy while preserving downloads. |
| `v0.4.1` | TitoDex v0.4.1 · 离线缓存与地区图鉴修正 | Fixes offline reference loading, game fallback, transitions, and regional selection. |
| `v0.4.0` | TitoDex v0.4.0 · 多游戏版本与地区图鉴 | Introduces 23 game editions, 11 regional scopes, 1–1025 data, and the segmented search hub. |
| `v0.3.0` | TitoDex v0.3.0 · 全国图鉴 1–1025 | Expands the national dex, multi-game scopes, structured details, and bundle v5. |
| `v0.2.28` | TitoDex v0.2.28 · 图鉴详情与对战工具 | Reworks dex details and adds matchup, stat, and damage estimate tools. |
| `v0.2.27` | TitoDex v0.2.27 · 方屏图鉴优化 | Improves square-screen dex layouts, controller focus, and seen filtering. |
| `v0.2.26` | TitoDex v0.2.26 · 存档图鉴进度 | Reads HGSS seen/caught flags and adds regional progress and encounter filters. |
| `v0.2.25` | TitoDex v0.2.25 · 图鉴界面与离线图包 | Adds the revised detail UI, one-tap bundle download, artwork viewer, and retry controls. |
| `v0.2.24` | TitoDex v0.2.24 · PNG 图鉴资源 | Migrates dex sprites and type icons to transparent PNG and adds lazy artwork support. |
| `v0.2.23` | TitoDex v0.2.23 · 图鉴详情重构 | Rebuilds details with unified scrolling, stats, obtain data, evolution, and move tiles. |
| `v0.2.22` | TitoDex v0.2.22 · 字号与图鉴下载 | Normalizes secondary-page typography and introduces verified offline bundle download. |
| `v0.2.21` | TitoDex v0.2.21 · 缩放与图鉴导航 | Aligns page scaling and simplifies national/regional dex navigation. |
| `v0.2.20` | TitoDex v0.2.20 · 掌机缩放修正 | Corrects the handheld UI scale to the intended 1.5× baseline. |
| `v0.2.19` | TitoDex v0.2.19 · 掌机布局密度调整 | Reduces oversized handheld UI and restores the arm64-only package. |
| `v0.2.18` | TitoDex v0.2.18 · 首页与头像更新 | Adds avatar crop, denser dashboard cards, and broader game selection. |
| `v0.2.17` | TitoDex v0.2.17 · 掌机界面优化 | Refines square home/dex layouts, fixed scaling, and status presentation. |
| `v0.2.16` | TitoDex v0.2.16 · 方屏布局与图鉴修正 | Fixes square quick actions and save-backed dex filters. |
| `v0.2.15` | TitoDex v0.2.15 · 方屏仪表盘布局 | Introduces aspect-aware dashboard layouts for square and compact handheld screens. |
| `v0.2.14` | TitoDex v0.2.14 预发布 · 动效规范 | Defines route, tab, loading, and dashboard motion behavior. |
| `v0.2.13` | TitoDex v0.2.13 预发布 · 贴纸界面与队伍状态 | Adds sticker-style dex cards, party HP bars, filters, and a text avatar fallback. |
| `v0.2.12` | TitoDex v0.2.12 预发布 · 路由过渡 | Adds page transitions, tab fades, skeleton loading, and opaque route backgrounds. |
| `v0.2.11` | TitoDex v0.2.11 预发布 · 返回导航修正 | Restores expected system-back navigation from secondary pages. |
| `v0.2.10` | TitoDex v0.2.10 预发布 · 紧凑首页与手柄导航 | Adds a one-screen dashboard, party sprites, controller focus, and startup save sync. |
| `v0.2.9` | TitoDex v0.2.9 预发布 · 字体渲染修正 | Fixes font artifacts, Chinese fallback, input decoration, and raw error presentation. |
| `v0.2.8` | TitoDex v0.2.8 预发布 · RG 体验修正 | Fixes Settings scrolling, dex parsing, emulator selection, and route presentation. |
| `v0.2.7` | TitoDex v0.2.7 预发布 · 离线图鉴下载 | Adds retry, resume, and partial-use behavior for offline dex downloads. |
| `v0.2.6` | TitoDex v0.2.6 预发布 · 模拟器与图鉴修正 | Fixes Android 11+ emulator selection and improves API retry/error handling. |
| `v0.2.5` | TitoDex v0.2.5 预发布 · 方屏首页 | Adds an aspect-aware one-screen dashboard for square displays. |
| `v0.2.4` | TitoDex v0.2.4 预发布 · 字体与排版统一 | Introduces semantic typography and bundled Nunito fonts. |
| `v0.2.3` | TitoDex v0.2.3 预发布 · 系统界面优化 | Adds immersive handheld chrome with battery and network status. |
| `v0.2.2` | TitoDex v0.2.2 预发布 · 方屏仪表盘 | Adds square/compact handheld detection, fullscreen layout, and offline fonts. |
| `v0.2.1` | TitoDex v0.2.1 预发布 · RG 全屏修正 | Removes the mock phone frame and improves edge-to-edge compact layouts. |
| `v0.2.0` | TitoDex v0.2.0 预发布 · RG Android 初始版 | First Flutter Android packages for RG-class handhelds. |
| `v0.1.0-phase2-debug` | TitoDex v0.1.0 · Android 原型验证 | Historical Capacitor debug prototype with dashboard navigation and mock data. |

## Copy rules

- Write every GitHub Release title and body in Simplified Chinese, titled `TitoDex vX.Y.Z · 主题` (pre-releases: `TitoDex vX.Y.Z 预发布 · 主题`). If an English channel is ever added, append a bilingual section under the Chinese copy instead of replacing it.
- Use the version and one clear outcome in the title.
- Describe user-visible changes before implementation details.
- Name the attached package and supported ABI when applicable.
- Mark pre-releases and infrastructure-only releases explicitly.
- Never include production CDN addresses, credentials, or private operational instructions.
- Brand-owned examples such as TitoDex and the default trainer identity are allowed; real save names, identifiable user data, and private contributor context are not.
