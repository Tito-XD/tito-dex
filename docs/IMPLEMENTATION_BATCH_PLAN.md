# TitoDex — Implementation batch plan (for Tito review)

> **Status:** Requirements consolidated; **no code changes yet**.  
> Tito reviews this list, then says「开始改」to implement.

---

## A. Release / packaging (partially done)

| # | Item | Status |
| --- | --- | --- |
| A1 | `docs/RELEASE_BUILD.md` + `tools/verify_release_apk.sh` | ✅ Doc + script on branch |
| A2 | Fix truncated `TitoDex-0.4.1-rg-arm64.apk` | ✅ On branch |
| A3 | Re-upload v0.4.1 asset to GitHub Release | ⏳ Manual after merge |

---

## B. Dex list

| # | Item | Detail |
| --- | --- | --- |
| B1 | **Remove game-edition chip bar** | `dex_page.dart` — `_DexGameEditionBar` gone |
| B2 | Browse by **regional pokedex only** | 全国 + 11 regions via bottom sheet (existing picker) |
| B3 | Stop `game tap → force _region`** | Decouple list from global game edition |
| B4 | Title | Prefer region or plain「图鉴」, not「图鉴 · {game}」 |

---

## C. Pokémon detail — 获取 tab

| # | Item | Detail |
| --- | --- | --- |
| C1 | **Encounter location names** | Map slugs/IDs → 中文地名 (HGSS first) |
| C2 | Extend `encounterAreaLabelsZh` / bundle `areaLabelZh` | Build time + app fallback |
| C3 | Wire or align `hgss_map_list` where IDs match | No bare `301` / `823` in UI |

---

## D. Pokémon detail — 招式 tab

| # | Item | Detail |
| --- | --- | --- |
| D1 | **Remove** top `_MoveGameEditionBar` (23-game scroll) | Save vertical space |
| D2 | **「以下招式范围：{game}」→ tappable** | Bottom sheet game picker |
| D3 | Keep method chips | 等级 / 学习器 / 蛋 / 教学 |

---

## E. Settings & trainer

| # | Item | Detail |
| --- | --- | --- |
| E1 | **Avatar in Settings** | Pick + crop; fix silent failures on RG |
| E2 | **Remove home avatar tap** | Trainer card display-only |
| E3 | Editable **trainer display name** | Keep |
| E4 | **Remove manual journey TextFields** | Location / badges / play time / reminder → read-only from save |
| E5 | Global game version picker | Keep; drives journey mode |

---

## F. Journey modes (`GameEdition.journeyCapability`)

| # | Item | Detail |
| --- | --- | --- |
| F1 | **`saveLinked`** | HGSS (only working parser today) |
| F2 | **`manual`** | NS: SM, USUM, SwSh, SV, PLA; mobile: LZA, Champions; retro without parser |
| F3 | Manual mode: **no save sync** | Skip `HgssParser` / save directory |
| F4 | Manual mode: **hide home journey card** | No continue/journey block |

---

## G. Home & navigation

| # | Item | Detail |
| --- | --- | --- |
| G1 | **Merge Journey tab into journey card** | One card on home; **▶** affordance; tap → journey detail |
| G2 | **Remove city / map illustrations** | Solid color block (square layout style); deprecate `CityIllustration` on home |
| G3 | **Remove Journey from bottom nav** | → Team \| Home \| Dex \| Search (4 items) |
| G4 | Quick actions **4 → 3** | Team, Dex, Search |
| G5 | Portrait quick grid **2×2 → 1×3 row** | Three equal tiles |
| G6 | Square quick bar **4 → 3** | Same three |
| G7 | Hand-drawn nav icons | **Later** — not this batch |

---

## H. Trainer card (home)

| # | Item | Detail |
| --- | --- | --- |
| H1 | **Larger avatar** | Not tappable |
| H2 | **Badges on the right** | Vertical / trailing column; not under name |
| H3 | **Time-based greeting** | 早上好/上午好/中午好/下午好/傍晚好/晚上好/深夜好 + 训练家 {name} |
| H4 | Remove standalone「当前游戏」line on card | Game context elsewhere |

---

## I. Journey detail page

| # | Item | Detail |
| --- | --- | --- |
| I1 | Content | Location, timeline, reminder, read-only stats (today's `JourneyPage`) |
| I2 | **Emulator prompt at top** |「从模拟器继续」+ pick/launch (not home primary CTA) |
| I3 | Opened from home journey card tap | Route push, not tab |

---

## J. Team page

| # | Item | Detail |
| --- | --- | --- |
| J1 | **Editable all modes** | Default from save; user can add/edit species, level, stats |
| J2 | **Re-sync: do not overwrite** user party | Banner:「与最新存档不同 · 点击同步」→ confirm → apply save party |
| J3 | **Team summary card** (full) | Avg Lv, BST sum/avg, type coverage, phys/special bias, **weakness summary**, **damage estimate hint**, HP totals |
| J4 | Tap slot → edit sheet | Expand `PartyMember` (IV/EV/nature/moves as needed) |

---

## K. Manual mode — dex markers

| # | Item | Detail |
| --- | --- | --- |
| K1 | **Long-press cycle** on dex card | 未见 → 已见 → 已捕 → 清除 |
| K2 | Separate storage | Not mixed with `.sav` bitfields |
| K3 | Filter chips still work | 已见/已捕/未见 on list |

---

## L. Pokémon Sleep

| # | Item | Detail |
| --- | --- | --- |
| L1 | **Tier A only** | Static tools / external calculator links; public game data |
| L2 | No account / sleep session sync | No Health Connect in this batch |
| L3 | Classify as `manual` journey mode | Same gating as LZA/Champions |

---

## Suggested implementation order

1. **F** journey capability + **G** nav/home gating (manual vs save-linked skeleton)
2. **E** Settings (avatar, read-only journey)
3. **H + I + G1–G2** trainer card + journey card merge + no illustrations
4. **J** team edit + summary + sync banner
5. **B + C + D** dex list + detail tabs
6. **K** manual dex long-press
7. **L** Sleep Tier A (small — links/tools section)
8. **A** merge release docs branch if not on main

---

## Doc index

| Doc | Contents |
| --- | --- |
| [JOURNEY_PROFILE_PLAN.md](./JOURNEY_PROFILE_PLAN.md) | Journey / trainer / team / Sleep / sync / manual dex |
| [RELEASE_BUILD.md](./RELEASE_BUILD.md) | APK packaging checklist |
| [ROADMAP.md](../ROADMAP.md) | Phase E + journey planned UX |
| [handoff/V040_CLOUD_AGENT_HANDOFF.md](./handoff/V040_CLOUD_AGENT_HANDOFF.md) | D1–D3, J1–J9 |

---

## Out of scope this batch

- Hand-drawn navigation icons
- Sleep Tier B (Health Connect sleep widget)
- New save parsers (Pt, BW, SV, …)
- CDN URL changes in public docs (already v0.4.2)
- AnimatedSize revert (unless Tito asks)
