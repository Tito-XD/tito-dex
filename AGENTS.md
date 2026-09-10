# AGENTS.md

**Canonical project context for AI agents:** [`docs/AI_CONTEXT.md`](docs/AI_CONTEXT.md) — read it first (current release, architecture, guardrails, build steps).

## Quick facts

- **Active code:** `flutter/` (Flutter + Dart; Simplified Chinese default, English follows system / Android per-app language)
- **Removed:** the pre-Flutter React mock (`src/`) was deleted in the 0.6.5 cleanup; root `tsconfig*.json` / `vite.config.ts` are dead relics — ignore; releases stay on GitHub as historical artifacts
- **Latest release:** v0.9.18 · Lite `0.9.18+204`; Offline `0.9.18-offline+205`
- **Offline data:** CDN bundle v20 live; Offline APK embeds the complete verified v20 reference/gameplay archive (`/v5/`; `/v4/` rollback)
- **Tests:** `cd flutter && flutter test`

## Cloud VM

- Flutter at `~/flutter/bin`; web dev via `flutter run -d chrome`
- APK build needs Android SDK + signing (see [RELEASE_BUILD.md](docs/RELEASE_BUILD.md))
- Dex CDN secrets: [PERMISSIONS.md](docs/PERMISSIONS.md) — never publish CDN URLs in public copy

Everything else (feature status, file map, CDN build, contributor rules) lives in **AI_CONTEXT.md**.

## Commit attribution

- Use the maintainer's configured Git identity for agent-assisted work. Never set an AI tool as author/committer or add AI `Co-authored-by`, `Made-with`, generated-by or session trailers. Preserve real human contributors.
- Claude attribution is disabled in `.claude/settings.json`. Repository hooks and the `Commit authorship` check enforce this rule.
- For a new checkout, enable hooks with `git config core.hooksPath .githooks`. If Python is not on PATH, set `git config titodex.python /absolute/path/to/python`.
- Push a `code/` branch first, wait for `Commit authorship` to pass, then update `main`. Main requires this check; do not bypass it.
- Main history was cleaned on 2026-09-10. Rebase/cherry-pick unfinished work onto current `origin/main`; never merge the old history back. Existing release tags are intentionally unchanged.
