# Repository contribution workflow

Read [AI_CONTEXT.md](AI_CONTEXT.md) for the current product and [RELEASE_BUILD.md](RELEASE_BUILD.md) before packaging an APK. Documentation-only updates do not change the App version or recreate release artifacts.

## New checkout

```bash
git config core.hooksPath .githooks
# Only if Python is not available on PATH:
git config titodex.python /absolute/path/to/python
```

Use the maintainer's configured human Git identity for agent-assisted work. Preserve other human authors and co-authors. Do not add AI author/committer identities, AI co-author credits, generated-by markers or agent session trailers. The commit-message and pre-push hooks run `tools/check_commit_attribution.py`; pre-push checks the entire pushed branch history. Claude attribution is disabled in `.claude/settings.json`; Cursor has an always-applied repository rule.

## Publish a change

1. Fetch `origin`, inspect local changes and divergence, and preserve unrelated edits and untracked files. Start a `code/` branch from current `origin/main`.
2. Make a focused change. Run checks appropriate to it: documentation consistency and links for docs; affected tests and analysis for code; the full release gates before shipping APKs. Stage explicit files.
3. Commit and push the `code/` branch. The **Commit attribution** workflow runs the **Commit authorship** job, including policy tests and a complete history scan.
4. Wait for that exact commit's `Commit authorship` check to succeed. The active `Human commit attribution` ruleset requires it on `main`, with no bypass actors. Then update `main` by ordinary fast-forward (`git push origin HEAD:main`) if it has not advanced; otherwise integrate current `main`, recheck and push the new commit on the branch first.
5. Verify remote parity and relevant CI results. A passing authorship check does not imply that App tests or release validation passed.

Never disable the hooks or bypass the required check to get a rejected commit through.

## History cleanup: 2026-09-10

Main's AI attribution metadata was cleaned with an approved history rewrite. The original 433 commits retain their file trees, order and human contributions; 161 AI author identities, 50 AI co-author trailers and seven session trailers were corrected. Rewritten commit IDs and signatures differ. Separate commits that became metadata-identical retain `Original-Commit:` provenance instead of being squashed.

Existing release tags, release assets and their build/source evidence were intentionally left unchanged. In particular, v0.9.18 still points to its original verified source `124c82aca6f4e6034989b394a5cb4f916ba45b82`; do not substitute the rewritten main commit in an old artifact's provenance. Real collaborator access was not changed. GitHub's contributor display may lag behind the rewritten branch because it is cached.

For unfinished work based on old history, create a fresh branch from current `origin/main` and transfer only the unpublished changes. Cherry-picking retains authorship: preserve real human authors, and correct an AI author under the maintainer's identity before publishing. Do not merge the entire old history back into main or use an unrestricted rebase that replays it. Old deployment branches need their own explicit migration; the main cleanup did not rewrite them.

The maintainer's local, ignored `.history-backups/2026-09-10-attribution/` contains the verified pre-cleanup Git bundle and old-to-new map. It is recovery material, not an App asset or a file to commit. Existing signed release tags remain the artifact reference for historical builds.
