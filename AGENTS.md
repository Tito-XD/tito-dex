# AGENTS.md

## Cursor Cloud specific instructions

This repo is a monorepo. The **active product** is the Flutter app in `flutter/`
(a personal Pokémon journey companion, Chinese UI). The root React/Vite app in
`src/` is a **frozen legacy design reference** — do not add features there. See
`README.md` / `docs/STACK_DECISION.md` for the full picture.

### Toolchain (already installed in the VM snapshot)

- **Flutter 3.44.6 stable** (Dart 3.9+) is installed at `~/flutter`. Its `bin/`
  is on `PATH` via `~/.bashrc` (sourced by `~/.profile` for login shells). In a
  bare non-interactive shell, invoke it directly as `~/flutter/bin/flutter`.
- Node (nvm) + npm, Python 3.12, Java 21, and Google Chrome are preinstalled.
- No Android SDK / emulator is installed, so **the Flutter dev target on this VM
  is web** (Chrome is present). Building a release APK is not possible here.

The startup update script runs `npm install` (root React mock) and
`flutter pub get` (in `flutter/`). Everything else below is run on demand.

### Flutter app (`flutter/`) — active

Standard commands (documented in `flutter/README.md`), run from `flutter/`:

- Lint: `flutter analyze` — note it currently reports **3 pre-existing issues**
  (unused imports + 1 info) and exits non-zero. That is the repo's baseline, not
  a regression from your changes.
- Test: `flutter test` — all suites pass (~50 tests) headlessly on the Dart VM.
- Run (web): `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`
  then open `http://localhost:8080`, or `flutter run -d chrome`. First web
  compile takes ~20s.

**Known web-only caveat (not an environment problem, do not "fix" as setup):**
The **Settings, Search, and Dex** screens throw a Flutter `No Material widget
found` error when run on **web**. `widgets/secondary_page_scaffold.dart` renders
a bare `ListView` with no `Scaffold`/`Material` ancestor, so descendant
`TextField`/`DropdownButton` widgets (present on those three screens) fail. The
app's real target is the Android RG handheld, where this path behaves
differently. On web, the **Home / Team / Journey** screens work fully and render
the live journey (trainer card, party roster, timeline) — use those for
web smoke testing.

The home screen loads a mock journey (`CurrentJourney.mock()`) on first launch
unless a saved journey exists in `shared_preferences` (localStorage on web).

### React/Vite reference mock (`src/`, root) — frozen legacy

Root `package.json` scripts: `npm run dev` (Vite at `http://localhost:5173`),
`npm run lint` (oxlint), `npm run build`. Journey data here is mock-only.

### Optional maintenance tooling (not needed for app dev)

- Python save-probe + CDN bundle scripts in `tools/`. A venv with the build
  deps lives at `~/.venv-titodex-tools` (from `tools/dex_bundle_requirements.txt`).
  `tools/probe_hgss_save.py` needs only the stdlib, e.g.
  `python3 tools/probe_hgss_save.py fixtures/PKMSS.sav`.
- Cloudflare R2-proxy Worker in `cloudflare/dex-cdn/` (deps installed via
  `npm install` there; `npx wrangler ...`). Deploying needs Cloudflare secrets.
