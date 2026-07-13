# TitoDex

**TitoDex** is a personal Pokémon **journey companion** — a warm, device-like app for picking up where you left off in a playthrough. It combines a trainer dashboard, HGSS save sync, and a lightweight offline Pokédex with Chinese UI.

It is **not** a full encyclopedia replacement (52Poké, Bulbapedia, etc.). Reference data exists to support the current game, not to catalog everything.

**Current release:** [v0.4.7](https://github.com/Tito-XD/tito-dex/releases/tag/v0.4.7) · App `0.4.7+39` · Offline dex bundle **v5** (1025 species, 23 game editions)

## Highlights (v0.4.7)

- **Sprite 策略** — 列表默认 CDN 小图；详情页点图按 Gen I–IX 切换各代 sprite（按需加载）
- **图鉴 1025** — 全国图鉴进度分母修正为 1025
- **首页布局** — 竖屏/Pad 居中；Trainer 卡片加高、头像放大、两行问候、移除右侧徽章
- **头像裁切** — 修复 UCrop 与状态栏重叠导致无法点确认
- **RG APK** — arm64-v8a, ~21 MB, [releases/](releases/)

## Principles

1. **Continue first** — the home screen answers “where was I?”  
2. **Game context first** — HGSS-default; expand with the journey  
3. **Local first** — offline bundle, save parsing, no runtime wiki scraping  
4. **Companion, not encyclopedia** — depth where it helps play  
5. **Iterate** — ship useful slices; avoid platform over-design  

## Stack

| Layer | Choice |
| --- | --- |
| App | **Flutter + Dart** (`flutter/`) |
| Reference mock | Capacitor + React (`src/` — frozen) |
| Routing | `go_router` — Home, Team, Journey, Dex, Search, Settings |
| Persistence | `shared_preferences` + offline `dex_offline/` |
| Save | HGSS 512 KB `.sav` parser + directory auto-sync |
| Dex data | Pre-built CDN bundle v5 (+ APK asset fallbacks) |
| UI language | Simplified Chinese |

Details: [Architecture](docs/ARCHITECTURE.md) · [Stack decision](docs/STACK_DECISION.md)

## Install (RG handheld)

Download **`TitoDex-0.4.7-rg-arm64.apk`** from [GitHub Releases](https://github.com/Tito-XD/tito-dex/releases). Uninstall any locally-built debug APK first (signing key differs).

First launch may prompt you to open **Settings → 下载预打包数据包** for the full offline pack.

## Development

```bash
cd flutter
flutter pub get
flutter test
flutter run              # device / emulator
flutter run -d chrome    # web preview (limited)
```

Build release APK: [docs/RELEASE_BUILD.md](docs/RELEASE_BUILD.md)

Maintainers — dex bundle build & R2 upload: [docs/CLOUDFLARE_DEX_CDN.md](docs/CLOUDFLARE_DEX_CDN.md) · secrets: [docs/PERMISSIONS.md](docs/PERMISSIONS.md)

## Documentation

| Doc | Contents |
| --- | --- |
| [**AI context**](docs/AI_CONTEXT.md) | **Single doc for agents** — status, architecture, guardrails |
| [Vision](VISION.md) | Product feeling |
| [Product](PRODUCT.md) | Positioning & priorities |
| [Roadmap](ROADMAP.md) | Phases & version history |
| [Flutter app](flutter/README.md) | App-specific dev notes |
| [Design system](docs/DESIGN_SYSTEM.md) | Visual tokens |
| [Release build](docs/RELEASE_BUILD.md) | APK checklist |

## HGSS test save

Bundled fixture `PKMSS.sav` — import via Settings. Expect trainer ETeZ, 3 badges, Goldenrod City, party with Quilava / Togepi.

```bash
python3 tools/probe_hgss_save.py fixtures/PKMSS.sav
```
