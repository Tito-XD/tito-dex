# TitoDex Architecture

## Recommended Initial Stack

Use **Capacitor + React + TypeScript** for an Android-first application with a web-based UI layer.

Why:

- Android packaging is first-class through Capacitor.
- React is productive for componentized dashboard UI.
- TypeScript keeps local data and parser boundaries explicit.
- Capacitor can later support local file access and platform plugins.
- The app can still be tested as a responsive web UI during early iteration.


## Stack Decision for RG Rotate

The default Phase 2 stack is **Capacitor + React + TypeScript + Vite**. This remains the recommended path for TitoDex because the product is primarily a local-first companion dashboard rather than a performance-heavy native application.

The first target handheld is **Anbernic RG Rotate**, with a Unisoc chipset and Android 12 ceiling. That target reinforces a few constraints:

- keep the UI lightweight and dashboard-oriented;
- avoid heavy blur, excessive animation, and large unoptimized art assets;
- test square and landscape-like layouts early instead of assuming phone portrait;
- use Capacitor for the Android shell and bridge only where needed;
- isolate native file access behind platform adapters;
- prefer Android Storage Access Framework style file picking for `.sav` files instead of assuming unrestricted filesystem paths;
- keep React/CSS components custom rather than adopting a default Material or Ionic UI look.

Fallback options are intentionally secondary:

- **React Native** if WebView performance or input handling becomes a real RG Rotate problem.
- **Flutter** if a future rewrite needs stronger custom-rendered cross-platform UI.
- **Kotlin + Jetpack Compose** if TitoDex becomes Android-only and needs deep native integration.

Do not switch stacks preemptively. Validate the Capacitor build on the target device first.

## Architecture Goals

- local first
- Android first
- responsive UI
- simple data model
- no premature all-generation abstraction
- parser modules are optional and game-scoped
- cloud sync is a later adapter, not a core dependency

## Proposed Project Shape

When implementation begins:

```txt
src/
  app/
    App.tsx
    routes.tsx
  components/
    TrainerCard.tsx
    ContinueJourneyCard.tsx
    QuickWidget.tsx
    PartySummary.tsx
    JourneyTimeline.tsx
  data/
    mockJourney.ts
  features/
    journey/
      journeyTypes.ts
      journeyStore.ts
    dex/
      dexMockData.ts
    parser/
      hgssParser.ts
      parserTypes.ts
    sync/
      syncTypes.ts
  styles/
    tokens.css
    global.css
    layouts.css
  platform/
    fileAccess.ts
    capacitor.ts
```

Keep early modules small. Do not create a large plugin framework before the HGSS flow is validated.

## Data Layers

### 1. Mock Data Layer

Phase 1 / Phase 2 can use hard-coded data:

- SoulSilver
- Goldenrod City
- 3 badges
- play time
- party
- journey timeline
- Dex search mock

### 2. Local Journey Store

The first real persistence layer should store user-editable journey state locally.

Possible storage choices:

- simple local storage for early mock app
- IndexedDB for richer local data
- Capacitor Preferences for small settings
- file-backed export/import later

### 3. Save Parser Adapter

A parser should read save files and produce journey metadata. It should not own the whole app state.

Suggested output:

```ts
export type ParsedSaveSummary = {
  game: 'SoulSilver' | 'HeartGold';
  trainerName?: string;
  playTime?: string;
  badges?: number;
  location?: string;
  party?: Array<{
    species: string;
    level?: number;
  }>;
  saveHash: string;
  parsedAt: string;
};
```

### 4. Cloud Sync Adapter

Cloud sync should be optional. The local app should remain useful without it.

Cloud sync can later send:

- current game
- play time
- badges
- location
- party
- save hash
- updated time
- optional `.sav` backup to R2

## UI Routing

Initial screens:

- Home / Continue
- Team
- Journey
- Dex
- Search
- Settings later

The home route is the most important route.

## Responsive Strategy

Use CSS rather than device-specific assumptions:

- mobile-first stacking
- grid dashboard at wider or square-ish viewports
- `repeat(auto-fit, minmax(...))`
- `clamp()` for spacing and type
- `dvh` / `dvw`
- safe-area insets

Avoid:

- fixed `720×720`
- phone-only assumptions
- Material Design default-heavy layout

## Native Boundaries

Capacitor-related code should be isolated under `platform/` or specific adapters.

Examples:

- file picking
- local file permission handling
- save backup export
- Android storage APIs

The React UI should consume typed services, not direct native calls everywhere.

## Testing Direction

Early checks:

- TypeScript type check
- unit tests for data transforms
- responsive visual checks at several viewport sizes
- parser fixture tests only after save parser work begins

Target viewport checks:

- 360 × 780 phone portrait
- 720 × 720 square
- 800 × 1280 tablet portrait
- 1280 × 800 tablet landscape
- foldable-like wide layout
