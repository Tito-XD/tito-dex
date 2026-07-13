# TitoDex Roadmap

> **Active code:** `flutter/`. **Current release:** v0.4.6. **Agent context:** [docs/AI_CONTEXT.md](docs/AI_CONTEXT.md).

## Version history (recent)

| Version | Summary |
| --- | --- |
| **v0.4.6** | Dex filter drill-down, reference detail UI, sprite fixes, collapsible type pickers, l10n sync workflow, offline update prompts |
| **v0.4.5** | CDN bundle decoupling — `l10n/`, `maps/`, `config/` in offline pack |
| **v0.4.4** | Master zh catalog; obtain location Chinese labels |
| **v0.4.3** | Batch UX — journey, dex, team, nav, manual mode |
| **v0.4.0** | 23 game editions, 11 regional dexes, search hub segments |
| **v0.3.0** | National 1025 + CDN bundle v5 foundation |
| **v0.2.28** | Dex detail UI, battle companion tools (partial) |

APK naming: `TitoDex-<ver>-rg-arm64.apk` under `releases/`.

## Phase status (condensed)

| Phase | Focus | Status |
| --- | --- | --- |
| 0–B | Flutter scaffold, persistence, settings, emulator | ✅ |
| C | HGSS parser + save directory sync | ✅ core |
| D | Dex 1–1025, CDN v5, offline bundle, artwork | ✅ |
| E | Regional & game edition scopes | ✅ (ongoing polish) |
| F | Reference encyclopedia + dex filters | ✅ v0.4.6 |
| G | Battle tools | ⚠️ partial |
| H | CDN l10n automation (52poke incremental) | ✅ workflow; content fills over time |
| — | Journey cloud sync | ❌ proposal only |

## Phase G — Battle tools (remaining)

| Item | Status |
| --- | --- |
| Type matchup, stat calc, quick damage | ✅ |
| Collapsible icon-grid type pickers | ✅ v0.4.6 |
| Offensive / defensive blind spots | ❌ |
| Full damage calculator | ❌ |
| IV calculator, usage rankings | ❌ |

## Phase — Infrastructure (v0.4.x)

| Item | Status |
| --- | --- |
| Bundle `l10n/` + `config/` on CDN | ✅ |
| Incremental l10n download in app | ✅ |
| First-run + update-available dialogs | ✅ |
| Weekly `sync-l10n-catalog` GitHub Action | ✅ |
| Hand-drawn nav icons in APK only | ✅ policy |

## Recommended next

1. **Blind-spot tools** — team coverage gaps (offense / defense)  
2. **Battle hub layout** — list-style entry like reference apps  
3. **Nav icon art** — replace bundled tab icons in APK assets  
4. **Full v3 CDN refresh** — rebuild bundle with latest l10n after 52poke sync fills gaps  
5. **Launcher icon / splash**  
6. **HeartGold detection**, single `.sav` file picker  

## Later generation packs

Add when the journey reaches each era — scoped dex/move data, not day-one encyclopedia imports. See [STACK_DECISION.md](docs/STACK_DECISION.md) for per-generation notes.

## Platform

| Platform | When |
| --- | --- |
| Android RG / phone | **Now** |
| Linux handheld | After Android loop solid |
| Web companion | After save sync without `dart:io` |
