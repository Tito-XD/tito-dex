# TitoDex Architecture

> **Stack update (July 2026):** TitoDex is migrating from Capacitor + React to **Flutter + Dart**. See [Stack Decision](./STACK_DECISION.md) for rationale, migration phases, and contributor notes. The React tree under `src/` remains a design reference until Flutter reaches home-screen parity.

## Recommended Stack

Use **Flutter + Dart** for TitoDex going forward.

Why:

- Skia/Impeller rendering avoids WebView “webpage” feel on Android.
- One codebase targets Android, Linux (future handhelds), and web.
- Custom sticker/device UI maps cleanly to Flutter Widgets.
- Native needs (SAF file pick, app launcher, preferences, splash/icon) have mature plugins.
- Dart parser and fixture tests fit the local-first journey model.

### Previous stack (Phase 2 — reference only)

**Capacitor + React + TypeScript + Vite** delivered the Phase 2 mock app. It validated product shape and RG Rotate layouts but is no longer the implementation target.

## Target Devices

| Device | Notes |
| --- | --- |
| Android phones | Primary daily driver; system status bar + gesture nav |
| Anbernic RG Rotate | Unisoc, Android 12; 720×720 square dashboard |
| Linux handhelds (future) | e.g. RG DS–class; Flutter Linux desktop |
| Web (later) | Companion dashboard; not Phase 0 priority |

Constraints for all targets:

- keep the UI lightweight and dashboard-oriented;
- avoid heavy blur, excessive animation, and large unoptimized art assets;
- test square and phone layouts early;
- keep custom UI — no default Material look as the product identity;
- use Android Storage Access Framework for `.sav` files;
- **retain DeviceShell** as the signature device frame (tune margins per form factor).

### Alternatives considered

| Option | Verdict |
| --- | --- |
| Stay on Capacitor | Rejected — WebView ceiling + no Linux path |
| Jetpack Compose | Rejected for now — Android-only; Linux/web weaker than Flutter |
| React Native | Not chosen — UI is custom-drawn; Flutter better for Linux/web |

## Architecture Goals

- local first
- Android first (Linux + web follow)
- responsive UI across phone and square screens
- simple data model
- no premature all-generation abstraction
- parser modules are optional and game-scoped
- cloud sync is a later adapter, not a core dependency

## Project Shape

### Flutter (active target)

```txt
lib/
  app/
    app.dart
    router.dart
  theme/
    tokens.dart
    app_theme.dart
  widgets/
    device_shell.dart
    trainer_card.dart
    continue_journey_card.dart
    ...
  features/
    journey/
      journey_model.dart
      journey_repository.dart
    parser/
      hgss_parser.dart
      parser_types.dart
    launcher/
      emulator_launcher.dart
    settings/
      settings_page.dart
  platform/
    file_access.dart
test/
  parser/
    hgss_parser_test.dart
fixtures/
  saves/
    PKMSS.sav          # planned move from src/
pubspec.yaml
```

### React (Phase 2 reference — frozen)

```txt
src/
  app/          # routes, pages
  components/   # DeviceShell, cards, widgets
  features/     # journey, parser stubs, sync types
  styles/       # tokens.css — port values to Dart
  data/         # mockJourney.ts
android/        # Capacitor shell — legacy builds only
```

Keep Flutter modules small. Do not create a large plugin framework before the HGSS flow is validated.

## Data Layers

### 1. Mock Data Layer

First launch seeds from mock journey data (SoulSilver / Goldenrod City template). After that, read local store.

### 2. Local Journey Store

Persist user-editable journey state locally.

Flutter options:

- `shared_preferences` for small settings (e.g. chosen emulator package name)
- `drift` or `isar` for structured journey + timeline
- JSON file export/import for backup

The journey repository must not always return mock data — that was the Phase 2 `journeyStore.ts` limitation.

### 3. Save Parser Adapter

A parser reads save files and produces journey metadata. It does not own the whole app state.

```dart
class ParsedSaveSummary {
  final String game;
  final String? trainerName;
  final String? playTime;
  final int? badges;
  final String? location;
  final List<ParsedPartyMember>? party;
  final String saveHash;
  final DateTime parsedAt;
  final List<String> warnings;
}
```

Fixture: `src/PKMSS.sav` (524 288-byte SoulSilver save). See `PARSER_PROPOSAL.md`.

### 4. Cloud Sync Adapter

Cloud sync remains optional. The local app must stay useful without it. See `CLOUD_SYNC_PROPOSAL.md`.

## UI Routing

Initial screens (unchanged):

- Home / Continue
- Team
- Journey
- Dex
- Search
- Settings

The home route is the most important route.

**Continue button behavior:** first tap opens emulator app picker; choice is saved; subsequent taps launch the selected app.

## Responsive Strategy

Flutter layout guidelines (same intent as CSS Phase 2):

- mobile-first stacking on narrow portrait
- grid dashboard at wider or square viewports
- `LayoutBuilder` / `MediaQuery` instead of fixed 720×720
- `SafeArea` and display cutout insets
- `DeviceShell` on all form factors unless a future “kiosk” mode says otherwise

Avoid:

- phone-only assumptions
- Material Design as the default visual language

## Native Boundaries

Platform code lives behind adapters in `lib/platform/`:

- file picking (SAF)
- emulator / app launch by package name
- save backup export
- status bar and system UI mode

UI layers consume typed services, not raw platform channels.

## Testing Direction

- `flutter test` for parser fixtures and journey repository
- widget tests for home dashboard key widgets
- golden tests optional for DeviceShell
- manual checks: 360×780 phone, 720×720 square, tablet landscape

Parser tests must run against `PKMSS.sav` before HGSS support is claimed.

## Related Documents

- [Stack Decision](./STACK_DECISION.md) — why Flutter, migration phases, pitfalls
- [Parser Proposal](./PARSER_PROPOSAL.md) — HGSS scope and fixture
- [Design System](./DESIGN_SYSTEM.md) — visual tokens to port
