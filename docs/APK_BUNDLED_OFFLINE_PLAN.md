# APK-bundled offline dex — experiment plan (`*-offline`)

> **Status:** Planning / side-branch experiment  
> **Branch:** `cursor/apk-bundled-offline-dex-feef`  
> **App version:** `0.4.94-offline+48` (mainline remains `0.4.94+47`)  
> **Audience:** Tito + Cloud Agents  
> **Product ask (confirmed):** Ship **exactly** what Settings “下载离线图鉴” installs today (`bundle.tar.zst` → `dex_offline/`) inside the APK, so install → open → use needs **no network** for that offline dataset.

---

## 1. Goal (plain language)

今天 App 要先从 CDN 拉离线包，解压进 `dex_offline/`，图鉴/搜索/中文对照才稳。

这个旁支要做的事很单纯：

> **把当前版本离线包里的全部内容，默认塞进 APK。**  
> 打开即用，不必再下图鉴包。

范围 **对齐现网 `bundle.tar.zst`（bundle v5 / CDN `/v3/`）**，不多不少：

- ✅ 图鉴 JSON、详情、招式/特性/属性、搜索参考索引  
- ✅ 中文名称映射（`l10n/zh`）、地图、配置、游戏图标  
- ✅ **一种**列表精灵图 `sprites/{id}.png`（全版本图鉴计划已取消，包里本来就没有）  
- ❌ 不额外塞 CDN 上按需的 `artwork/`（不在离线包里）  
- ❌ 不塞 `sprites/by-version/`、动图 GIF（不在离线包里）

---

## 2. What the current offline download actually contains

Source of truth: `tools/build_dex_bundle.py` staging → `bundle.tar.zst`  
(App: `DexBundleInstaller` extracts 1:1 into documents `dex_offline/`)

```txt
dex_offline/                         # = unpacked bundle.tar.zst
├── manifest.json
├── summaries.json                   # 1025 species index
├── types.json
├── moves.json
├── abilities.json
├── games.json
├── natures.json
├── egg_groups.json
├── status_conditions.json
├── weather.json
├── terrains.json
├── items.json
├── details/{1..1025}.json
├── sprites/{1..1025}.png            # single default sprite only
├── type_icons/{type}.png
├── game_icons/*.png
├── l10n/zh/*.json                   # species/moves/abilities/items/locations…
├── maps/hgss_map_list.json
└── config/app_config.json
```

### Explicitly **not** in the offline archive (CDN-only / optional)

| Path | Role today |
| --- | --- |
| `v3/artwork/{id}.png` | Built into `artwork_staging`, uploaded beside the archive; **lazy** via `DexArtworkService` |
| `sprites/by-version/…` | Cancelled plan — not part of offline tar (summaries may still carry URLs; files not shipped in pack) |
| `sprites/animated/…` | Same — not in offline tar |

**Size signal:** live fixture in tests uses `archiveSizeBytes: 3749451` (~**3.7 MB** compressed). Unpacked staging is larger (many small files) but still “one pack”, not hundred-MB artwork dumps.

**APK forecast:** ~21 MB → ~**25–28 MB** if we embed that one `bundle.tar.zst`.

---

## 3. Acceptance criteria (`*-offline` flavor)

On a fresh install, **airplane mode**:

1. No first-run “请下载离线图鉴” requirement  
2. Dex grid loads from local data (1025 + single sprite thumbs)  
3. Dex detail 4 tabs work from `details/*.json` + moves/abilities  
4. Search hub reference indices work from bundled JSON  
5. Chinese labels / HGSS maps / app config resolve without network  
6. CDN / PokeAPI are **not** on the critical path for the above

Still allowed to need network (unchanged product edges):

- Optional “检查更新” against CDN  
- Detail **large artwork** tap if user wants CDN artwork (not in offline pack today)  
- External Sleep links in config  
- Emulator / save folder access (local, not CDN)

---

## 4. Design — Option A (recommended)

**Ship the same archive the CDN already serves**, as an APK asset:

1. `flutter/assets/dex/bundle.tar.zst`  
   (+ sidecar `bundle-manifest.json` with `archiveSha256` / `bundleVersion` / size)  
2. First launch: if `dex_offline/` incomplete → seed from asset using existing zstd/tar path (`DexBundleInstaller` / `installFromBytes`)  
3. Mark `complete=true`, `preferOffline=true`  
4. Skip download prompt when seed OK  
5. Settings keep optional CDN re-download / update for newer bundle or l10n slice  

Why A: identical bytes to today’s offline install; one ~3.7 MB asset; no thousand-file AssetManifest; reuses extractor.

**Rejected for this experiment**

- Option B (unpack thousands of files into `assets/`) — build pain, little gain  
- Option C (JSON only, sprites still online) — fails “打开即用”  
- Expanding scope to artwork / by-version — **not** what current offline pull contains  

---

## 5. Implementation roadmap

### Phase 0 — Version + docs

- [x] Branch `cursor/apk-bundled-offline-dex-feef`  
- [x] Version `0.4.94-offline+48`  
- [x] This plan (scope = current offline tar, single sprite)  
- [x] Links from `AI_CONTEXT.md` / `ARCHITECTURE.md` / `AGENTS.md`

### Phase 1 — Build plumbing

| Step | Work |
| --- | --- |
| 1.1 | Script: copy current `v3/bundle.tar.zst` (+ manifest sidecar) → `flutter/assets/dex/` |
| 1.2 | Prefer **build-time fetch from R2/CDN** (or maintainer drop-in); avoid huge git history if possible |
| 1.3 | `pubspec.yaml`: `assets/dex/` |
| 1.4 | `verify_release_apk.sh`: allow `*-offline` ~25–32 MB |
| 1.5 | Artifact name: `TitoDex-0.4.94-offline-rg-arm64.apk` |

### Phase 2 — Runtime seeder

| Step | Work |
| --- | --- |
| 2.1 | `DexAssetSeedInstaller` / `installFromBytes` on existing installer |
| 2.2 | SHA-256 check vs sidecar |
| 2.3 | First-launch progress: “正在准备离线图鉴…” |
| 2.4 | Idempotent if local manifest complete & version ≥ seeded |
| 2.5 | Wire in `app.dart` bootstrap before offline prompt |
| 2.6 | Clear-cache → **re-seed from APK**, do not force network |

### Phase 3 — Product copy / Settings

| Step | Work |
| --- | --- |
| 3.1 | Status: “已随安装包内置（与 CDN 离线包同内容）” |
| 3.2 | Optional CDN update only |
| 3.3 | Chinese strings in `app_zh.dart` |
| 3.4 | Do **not** change artwork lazy path in this experiment (still CDN-on-tap) |

### Phase 4 — Measure

| Metric | Pass idea |
| --- | --- |
| Airplane-mode dex grid + detail (no artwork) | Works on first open after seed |
| APK size | ~25–28 MB acceptable on RG |
| Seed time once | Progress shown; no re-seed next launch |
| Parity | File tree matches a CDN-installed `dex_offline/` for same bundleVersion |

---

## 6. Code touch map

| Area | Files |
| --- | --- |
| Version | `flutter/pubspec.yaml` |
| Seed | `dex_bundle_installer.dart`, new `dex_asset_seed_installer.dart` |
| Bootstrap | `app.dart`, `offline_data_prompt.dart` |
| Settings / zh | `settings_page.dart`, `app_zh.dart` |
| Assets | `flutter/assets/dex/*` |
| Tools | `build_dex_bundle.py` helper / `sync_dex_apk_asset.sh`, `verify_release_apk.sh` |
| Tests | seed from bytes → temp `DexCachePaths`; bootstrap skip-prompt |

---

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| APK +4–7 MB | Expected; dual size band in verify script |
| First-launch extract jank | One-time progress UI |
| Stale vs CDN | Update check optional; seed version tracked |
| Clear cache breaks offline | Re-seed from APK asset |
| Summaries still list remote artwork / by-version URLs | Harmless offline; UI already falls back to local sprite / thumb |
| Cloud VM lacks CDN secrets | Maintainer drops archive into `assets/dex/` for first build |

---

## 8. Non-goals

- Replacing R2 Worker (still for updates + optional artwork + web)  
- Reintroducing multi-version sprite packs into the offline archive  
- Bundling `artwork/` unless we later change the **CDN offline pack** itself  
- Encyclopedia expansion / journey parser changes  

---

## 9. Suggested commits

1. `chore(offline): version 0.4.94-offline + plan doc` ← done  
2. `docs(offline): lock scope to current bundle.tar.zst contents` ← this update  
3. `build(dex): stage bundle.tar.zst into flutter/assets/dex`  
4. `feat(dex): seed dex_offline from APK asset on first launch`  
5. `feat(settings): bundled status + re-seed after clear`  
6. `test(dex): asset seed parity`  
7. `chore(release): TitoDex-0.4.94-offline-rg-arm64.apk`

---

## 10. Open questions (narrowed)

1. Asset delivery: **CI/R2 fetch at APK build** vs commit the ~3.7 MB archive in git?  
2. Mainline later: merge this as default, or keep `*-offline` as RG travel flavor only?  
3. Artwork: leave as CDN-on-tap (matches today’s offline pack), or expand the **CDN offline archive** in a separate change?

---

## Related

- [AI_CONTEXT.md](./AI_CONTEXT.md)  
- [CLOUDFLARE_DEX_CDN.md](./CLOUDFLARE_DEX_CDN.md) — offline dir layout  
- [ARCHITECTURE.md](./ARCHITECTURE.md)  
- [RELEASE_BUILD.md](./RELEASE_BUILD.md)  
