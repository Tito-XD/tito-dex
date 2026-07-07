# AGENTS.md

## Cursor Cloud specific instructions

### Repository state (read this first)

This repository is currently **documentation-only (Phase 1)**. There is intentionally
**no application code, no `package.json`, no build system, and no test/lint tooling**.
The deliverables are the Markdown files at the repo root (`README.md`, `VISION.md`,
`PRODUCT.md`, `ROADMAP.md`) and under `docs/`. Building the app is explicitly deferred —
see the Phase 1 guardrails in `docs/AI_READFIRST.md` and `README.md`.

Because there is nothing to install, the startup update script is a no-op guard that will
only run a package manager once a `package.json` actually exists (see below). Do **not**
scaffold the app or add dependencies just to make setup "look" complete.

### Planned stack (for when implementation begins)

Per `docs/ARCHITECTURE.md` / `ROADMAP.md`, Phase 2 will scaffold **Capacitor + React +
TypeScript + Vite**. When that happens:

- A `package.json` will appear; the startup update script (`pnpm install` when a lockfile/
  manifest exists) will begin installing dependencies automatically.
- The dev server will be `vite` (typically `npm run dev` / `pnpm dev`, default port `5173`).
- Update this file with the real lint/test/build/run commands once they exist.

### Previewing the docs (current "dev" workflow)

The only meaningful thing to run today is a Markdown preview of the docs. There is no
committed tooling for this. A lightweight, non-committed way to preview locally:

```bash
mkdir -p /tmp/titodex-preview && cd /tmp/titodex-preview
npm install markdown-it@14
# then serve the /workspace *.md and docs/*.md files, rendered to HTML, on a local port
```

Keep any such preview tooling **out of the repo** — committing a preview server or its
dependencies would violate the Phase 1 "documentation only" guardrail.

### Toolchain available on the VM

Node 22, npm 10, pnpm 10, yarn 1.22, Python 3.12, and git are preinstalled. No language
runtime installation is needed for the current repo state.
