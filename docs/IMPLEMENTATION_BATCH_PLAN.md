# TitoDex — Master implementation checklist (Tito review)

> **Status:** Living doc. Code changes start when Tito says「开始改」.  
> **Implemented on branch `cursor/home-game-picker-display-947b`:** display layout split + home game grid picker fix (partial batch).

---

## ✅ Done / in PR (this branch)

| ID | Item |
| --- | --- |
| M1 | **Display split:** 1:1 / 3:4 / 4:3 → handheld immersive + custom Wi‑Fi/battery; other sizes → system bars, SafeArea, no custom status icons |
| M2 | **`SystemUiCoordinator`** — not global immersive on all Android |
| M3 | **Home game picker fix** — correct `BuildContext` for bottom sheet; **`showGameEditionGridPicker`** (3–4 col, name cells); badge updates via `ListenableBuilder` |
| M4 | Sync `dexSettingsRepository` when picking game on home |
| M5 | Docs: [`DISPLAY_LAYOUT.md`](./DISPLAY_LAYOUT.md) |

**Pending:** game **icon assets** in grid (Tito to supply); wire icon slot when ready.

---

## A. Release / packaging

| ID | Item | Status |
| --- | --- | --- |
| A1 | `RELEASE_BUILD.md` + `verify_release_apk.sh` | On doc branch |
| A2 | Fix v0.4.1 truncated APK | On doc branch |

---

## B. Dex list

| B1 | Remove `_DexGameEditionBar` |
| B2 | Regional pokedex only (11 regions) |
| B3 | Decouple game tap from `_region` |
| B4 | Title: region or plain「图鉴」 |

---

## C. Detail — 获取 tab

| C1 | Encounter location → 中文地名 |
| C2 | Extend mapping + bundle `areaLabelZh` |
| C3 | No bare numeric IDs in UI |

---

## D. Detail — 招式 tab

| D1 | Remove top 23-game chip bar |
| D2 | Tappable「以下招式范围：{game}」→ picker |
| D3 | Keep method filter chips |

---

## E. Settings & trainer

| E1 | Avatar in Settings only; fix crop on RG |
| E2 | **Remove home avatar tap** |
| E3 | Trainer name editable |
| E4 | Journey fields read-only (remove manual TextFields) |
| E5 | Global game version picker |

---

## F. Journey modes

| F1 | `saveLinked` — HGSS (+ future parsers) |
| F2 | `manual` — NS / mobile / no parser |
| F3 | Manual: no save sync |
| F4 | Manual: hide journey card |

---

## G. Home & navigation

| G1 | **Merge Journey tab → journey card** + ▶ → detail |
| G2 | Remove `CityIllustration` / map art — solid blocks |
| G3 | Bottom nav: Team \| Home \| Dex \| Search (4) |
| G4 | Quick tiles: Team, Dex, Search (3) |
| G5 | Portrait: 1×3 row; square: 3-in-a-row |
| G6 | Hand-drawn nav icons — **later** |
| G7 | Journey detail top: **emulator prompt** |

---

## H. Trainer card

| H1 | Larger avatar, not tappable |
| H2 | Badges on **right** |
| H3 | Time greeting + 训练家 {name} |
| H4 | Drop「当前游戏」line on card |

---

## I. Team

| I1 | Editable **all modes**; default from save |
| I2 | Re-sync: **don't overwrite** party; banner「与最新存档不同 · 点击同步」 |
| I3 | **Full summary card:** avg Lv, BST, type coverage, phys/sp bias, **weakness summary**, **damage hint**, HP totals |
| I4 | Slot edit sheet |

---

## J. Manual mode dex

| J1 | Long-press: 未见 → 已见 → 已捕 → 清除 |
| J2 | Separate storage from save bitfields |

---

## K. Pokémon Sleep

| K1 | **Tier A only** — static tools / links |
| K2 | No account sync this batch |

---

## L. Display & system UI

| L1 | Handheld panel (1:1, 3:4, 4:3): keep current RG layout | ✅ |
| L2 | Other devices: normal status + nav bars, not fullscreen | ✅ |
| L3 | No custom Wi‑Fi/battery except handheld panel | ✅ |
| L4 | Game grid picker with icon slots when assets ready | partial |

---

## Doc index

- [JOURNEY_PROFILE_PLAN.md](./JOURNEY_PROFILE_PLAN.md) — journey/trainer/team (on doc branch; merge to main)
- [DISPLAY_LAYOUT.md](./DISPLAY_LAYOUT.md)
- [RELEASE_BUILD.md](./RELEASE_BUILD.md) (doc branch)

---

## Out of scope this batch

- Hand-drawn icons
- Sleep Tier B (Health Connect)
- New save parsers beyond HGSS
- AnimatedSize revert unless asked
