# AGENTS.md

## Cursor Cloud specific instructions

### Repository state

TitoDex is now a **Phase 2 app**: a **Capacitor + React + TypeScript + Vite** web UI
(Android shell under `android/`). It is a local-first Pokémon journey companion using
hard-coded mock data (`src/data/mockJourney.ts`) — no backend, no database, no auth.
See `README.md` and `docs/ARCHITECTURE.md` for product/architecture direction and
`docs/AI_READFIRST.md` for guardrails (still mock-data only; no real save parsing or
cloud sync yet).

### Communication

Per `docs/AI_READFIRST.md`: default chat replies to Tito in **Chinese**; keep GitHub
artifacts (PR/issue/commit messages) in **English**.

### Commands (scripts live in `package.json`)

- `npm run dev` — Vite dev server on port **5173** (main development workflow).
- `npm run lint` — `oxlint` (fast; used instead of ESLint).
- `npm run build` — `tsc -b` typecheck + `vite build` to `dist/`.
- `npm run preview` — serve the production build.
- `npm run cap:sync` / `npm run cap:android` — build + sync/open the Android project.

Package manager is **npm** (`package-lock.json` is committed). The startup update script
runs `npm ci` automatically when the lockfile is present.

### Non-obvious notes

- **Web-first dev**: Do all UI iteration in the browser via `npm run dev`. The `android/`
  Capacitor project requires the Android SDK / Android Studio, which is **not** installed
  on the cloud VM — do not expect `cap:android` to work here; use it only as reference.
- Lint is `oxlint`, not ESLint — there is no `.eslintrc`.
- Fonts are bundled locally via `@fontsource/nunito` (no network font fetch at runtime).
- All journey/party/Dex/search data is mock data; there is no persistence yet (Phase 3).

### Toolchain available on the VM

Node 22, npm 10, pnpm 10, Python 3.12, git preinstalled. No Android SDK.
