# APK-bundled offline dex — experiment plan (`*-offline`)

> **Status:** Planning / side-branch experiment  
> **Branch:** `cursor/apk-bundled-offline-dex-feef`  
> **App version:** `0.4.94-offline+48` (mainline remains `0.4.94+47`)  
> **Audience:** Tito + Cloud Agents  
> **Goal:** Measure whether shipping the full offline dex payload inside the APK removes first-run CDN download friction and improves cold-load reliability on RG handhelds.

---

## 1. Hypothesis

Today TitoDex is **local-first after** the user downloads the CDN `bundle.tar.zst` into `dex_offline/`. Until that finishes (or if it fails on flaky Wi‑Fi), the app falls through to:

1. Live CDN JSON / sprites (`DexCdnDataSource`)
2. PokeAPI (last resort)

That creates the pain we feel: first-run prompt, Settings download, incremental l10n updates, and list/detail waiting on network when the offline cache is missing or incomplete.

**Hypothesis:** If the same content the CDN installer writes into `dex_offline/` is already present at install time (APK assets → seed into documents, or read directly from assets), then:

- Dex list / detail / search reference data work **immediately offline**
- First-run “download offline pack” prompt becomes unnecessary (or optional “check for updates”)
- Cache/loading UX improves because the hot path never waits on HTTP for core data

This branch exists to **prove or disprove** that trade-off before merging to mainline.

---

## 2. What “offline-needed” means (in scope)

Mirror the **CDN bundle v5** payload that `DexBundleInstaller` already extracts — not the optional PokeAPI mega-caches.

| Include in APK seed | Why |
| --- | --- |
| `manifest.json` + `summaries.json` | Grid + search index (1025) |
| `details/{1..1025}.json` | 4-tab detail |
| `moves.json`, `abilities.json`, `types.json` | Moves / abilities / type chart |
| Reference indices already in bundle (`items`, natures, weather, … if present) | Search hub |
| `sprites/{id}.png` + `type_icons/*` | List thumbs + type chips |
| `l10n/zh/*`, `maps/*`, `config/*`, `game_icons/*` | Zh labels, HGSS maps, Sleep config, edition icons |

| Explicitly **out** of APK seed (keep lazy) | Why |
| --- | --- |
| Full `artwork/{id}.png` (~80–120 MB) | Detail tap only; too large for APK |
| Showdown GIFs / multi-gen sprite mirrors | Optional Settings checkboxes; hundreds of MB |
| Runtime 52poke / PokeAPI scraping | Product guardrail |

**Known size signal (production manifest fixture):** compressed `bundle.tar.zst` ≈ **3.7 MB** (`archiveSizeBytes: 3749451` in tests). Unpacked on disk is larger (many small JSON/PNG files) but still far smaller than artwork.

**APK size forecast:** current RG APK ~21 MB → offline build ~**25–28 MB** if we ship one compressed archive asset (preferred). Still under `verify_release_apk.sh` WARN threshold (35 MB); script size band should be updated for this flavor.

---

## 3. Current architecture (baseline)

```
Load priority (DexRepository):
  Settings-installed dex_offline/  →  live CDN  →  PokeAPI

Bootstrap (app.dart):
  if !offlineReady → showOfflineDataPrompt → Settings download
  else → DexUpdateService CDN check (bundle / l10n)

Partial APK assets today:
  assets/l10n/zh/* , assets/config/app_config.json
  (zh_catalog / AppConfig already fall back: dex_offline → assets)
```

Pain points this experiment targets:

- Cold start without completed `manifest.complete`
- Download / decompress / extract UI on first use
- Dependency on CDN reachability for “should just work” companion use on the road

---

## 4. Design options (pick one primary path)

### Option A — **Ship `bundle.tar.zst` as APK asset + first-launch seed** (recommended)

1. Add `assets/dex/bundle.tar.zst` (+ optional `assets/dex/bundle-manifest.json` with SHA-256).
2. On bootstrap, if `dex_offline/` incomplete → `DexAssetSeedInstaller` reads asset bytes → reuse existing zstd/tar extract path from `DexBundleInstaller` → write `dex_offline/` with `complete=true`, `preferOffline=true`.
3. CDN installer remains for **updates** only.
4. Skip first-run download prompt when seed succeeds.

**Pros:** One archive (~3.7 MB), reuses installer, AssetManifest stays tiny, same on-disk layout as today.  
**Cons:** One-time extract CPU/IO on first launch (show progress); duplicates disk (APK + documents) until we optionally delete seed after extract (APK still holds it).

### Option B — Unpacked tree under `assets/dex_offline/**`

Read via `rootBundle` / `AssetBundleImageProvider` with a new `DexAssetStore` parallel to `DexCacheStore`.

**Pros:** Zero extract step.  
**Cons:** Thousands of asset entries; slow builds; AssetManifest bloat; sprite path model today expects filesystem absolute paths — large refactor.

### Option C — Hybrid

Seed JSON indices from assets; keep sprites on CDN/lazy.

**Pros:** Smaller APK delta.  
**Cons:** Does **not** fully fix list loading / offline grid — weak experiment for the stated goal.

**Decision for this branch:** implement **Option A**.

---

## 5. Implementation roadmap

### Phase 0 — Version + docs (this PR)

- [x] Side branch `cursor/apk-bundled-offline-dex-feef`
- [x] Version `0.4.94-offline+48`
- [x] This plan document
- [ ] Link from `docs/AI_CONTEXT.md` human doc index

### Phase 1 — Build plumbing (no runtime change yet)

| Step | Work |
| --- | --- |
| 1.1 | Extend `tools/build_dex_bundle.py` (or thin wrapper) with `--apk-asset-out flutter/assets/dex/` copying `bundle.tar.zst` + sidecars |
| 1.2 | Document how maintainers refresh the asset when CDN bundle v bumps (do **not** commit CDN base URLs in public notes) |
| 1.3 | `pubspec.yaml` assets entry: `assets/dex/` |
| 1.4 | Relax / dual-band `tools/verify_release_apk.sh` for `*-offline` APKs (~25–32 MB OK) |
| 1.5 | Release naming: `releases/TitoDex-0.4.94-offline-rg-arm64.apk` |

> **Git note:** 3.7 MB binary may be OK in-repo for the experiment; if LFS/history pain appears, fetch asset in CI from R2 at build time instead of committing. Prefer **build-time fetch** for long-term; commit a stub + script for the first offline APK if secrets available.

### Phase 2 — Runtime seeder

| Step | Work |
| --- | --- |
| 2.1 | Add `DexAssetSeedInstaller` (or flag on `DexBundleInstaller.installFromBytes`) |
| 2.2 | Integrity: SHA-256 from bundled sidecar vs asset bytes |
| 2.3 | Progress stream → reuse Settings progress UI / splash-friendly dialog (“正在准备离线图鉴…”) |
| 2.4 | Idempotent: skip if local `manifest.complete` and `version >=` seeded version |
| 2.5 | Wire into `TitoDexApp._bootstrap` **before** offline prompt / update check |
| 2.6 | Disable or soft-change `showOfflineDataPrompt` when seed present |

### Phase 3 — Product behavior on offline flavor

| Step | Work |
| --- | --- |
| 3.1 | Settings: show “已随安装包内置” status; keep “检查更新 / 重新下载 CDN” |
| 3.2 | Keep `DexUpdateService` for newer CDN bundle / l10n slice |
| 3.3 | Chinese copy only in `app_zh.dart` for new strings |
| 3.4 | Artwork remains on-demand (`DexArtworkService`) |

### Phase 4 — Measure & decide

Build both APKs on the same commit baseline when possible:

| Metric | How |
| --- | --- |
| APK size | `verify_release_apk.sh` + `unzip -lv` |
| First launch to usable dex grid | Stopwatch on RG (airplane mode) |
| Dex detail open (no artwork) | Airplane mode |
| First launch extract time | Seed progress duration |
| Storage after extract | `DexCacheStore.directorySizeBytes()` |
| Subsequent launches | Confirm no re-extract |

**Ship decision:**

- **Adopt on mainline** if airplane-mode dex is instant and APK ≤ ~30 MB feels acceptable on RG.
- **Keep as optional flavor** if size hurts sideload / storage but offline UX wins for travel builds.
- **Abandon** if extract latency ≈ CDN download on typical Wi‑Fi, or Asset/APK packaging friction dominates.

---

## 6. Code touch map

| Area | Files |
| --- | --- |
| Version | `flutter/pubspec.yaml` |
| Seed installer | `flutter/lib/features/dex/dex_bundle_installer.dart` (+ new `dex_asset_seed_installer.dart`) |
| Bootstrap | `flutter/lib/app.dart`, `widgets/offline_data_prompt.dart` |
| Settings UX | `flutter/lib/pages/settings_page.dart`, `l10n/app_zh.dart` |
| Assets | `flutter/assets/dex/*`, `pubspec.yaml` `flutter.assets` |
| Tools | `tools/build_dex_bundle.py`, `tools/verify_release_apk.sh`, optional `tools/sync_dex_apk_asset.sh` |
| Tests | seed unit tests (fake asset bytes → temp `DexCachePaths`); bootstrap skip-prompt test |
| Docs | this file, short note in `AI_CONTEXT.md` / `ARCHITECTURE.md` when behavior lands |

**Do not** change `src/` React mock. **Do not** put CDN URLs in README/release notes.

---

## 7. Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| APK grows past comfort | Prefer compressed single asset (A); never ship artwork |
| First-launch jank on extract | Background isolate / yield progress; only once |
| Stale data vs CDN | Keep update check; seed version ≤ CDN `bundleVersion` |
| Dual storage (APK + documents) | Accept for v1; optional “extract once” is still simpler than Option B |
| Cloud VM lacks R2 secrets | Plan + code first; binary asset via CI or maintainer drop |
| `verify_release_apk.sh` false WARN | Offline size band in script |
| Web target | Seeding skipped on `kIsWeb` (same as current offline cache) |

---

## 8. Non-goals

- Replacing Cloudflare R2 / Worker (still used for updates + artwork + web)
- Bundling multi-generation sprite packs or GIFs
- Turning TitoDex into a full wiki dump
- Changing journey/save parsing

---

## 9. Suggested commit sequence (after this plan)

1. `chore(offline): version 0.4.94-offline + plan doc` ← **this commit**
2. `build(dex): script to stage bundle.tar.zst into flutter/assets/dex`
3. `feat(dex): seed dex_offline from APK asset on first launch`
4. `feat(settings): offline-bundled status + update-only CDN path`
5. `test(dex): asset seed installer + bootstrap behavior`
6. `chore(release): TitoDex-0.4.94-offline-rg-arm64.apk` (when build env ready)

---

## 10. Open questions for Tito

1. **Accept ~+4–7 MB APK** for always-offline core dex? (Recommended yes for this flavor.)
2. Prefer **committed asset** in git vs **CI fetch from R2** at APK build time?
3. After seed extract, should Settings still offer “清除离线缓存”? (If yes, must re-seed from APK asset instead of forcing CDN.)
4. Keep mainline as download-on-demand and only ship `*-offline` APKs for RG travel, or eventually merge Option A into default?

---

## Related

- [AI_CONTEXT.md](./AI_CONTEXT.md) — current release + architecture
- [CLOUDFLARE_DEX_CDN.md](./CLOUDFLARE_DEX_CDN.md) — bundle layout /v3/
- [ARCHITECTURE.md](./ARCHITECTURE.md) — dex offline flow
- [RELEASE_BUILD.md](./RELEASE_BUILD.md) — APK checklist
