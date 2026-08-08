# Stack Decision: Flutter

**Status:** Approved and complete. Current implementation facts live in [AI_CONTEXT.md](./AI_CONTEXT.md).

TitoDex uses Flutter + Dart in `flutter/`. The earlier Capacitor/React mock was
removed in v0.6.5; only its historical GitHub releases remain.

Flutter was selected for native Android rendering, custom device-like UI,
single-file save access, emulator handoff, offline bundle installation and one
responsive codebase for phones, RG square handhelds and web preview. Jetpack
Compose would be a good Android-only choice, but TitoDex keeps a shared preview
surface and existing Flutter investment.

## Current boundaries

- Android arm64 is the shipping target; web is a supported preview.
- iOS source shares the codebase, but signing and distribution are separate.
- `DeviceShell`, Nunito and the custom sticker language remain product identity.
- Persistence is local; journey JSON is the portability mechanism.
- Save parsing stays partial-but-honest and fixture-gated.
- Do not introduce a second application framework.

The original migration rationale is preserved in Git history. It is not an
active repository-layout or feature-status reference.
