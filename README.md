# TitoDex

TitoDex is a personal Pokémon journey companion app: **Tito + Pokédex**, but not a Pokémon encyclopedia.

It is designed as a warm companion device for Tito's own Pokémon playthroughs, starting with **Pokémon SoulSilver / HeartGold-SoulSilver context** and expanding only when the journey reaches later games.

## Product North Star

**Continue First.**

When Tito opens TitoDex, the first thing should be the current journey:

- current game
- current location
- badges
- play time
- party snapshot
- recent journey notes
- quick access to useful local references

TitoDex should feel less like a wiki and more like a small trainer device that says: “Welcome back. Here is where we were.”

## Core Principles

1. **Continue First** — the home screen prioritizes continuing the current journey.
2. **Game Context First** — show information relevant to the currently played game.
3. **Local First** — offline-first and local data first.
4. **Companion, not Encyclopedia** — focus on play assistance, not replacing 52Poké, Bulbapedia, or Serebii.
5. **Iterative** — begin with HGSS, then adapt for Pt, BW, B2W2, XY, ORAS, USUM as Tito reaches them.
6. **Do not over-engineer** — first make a delightful companion, not a universal platform.

## Suggested Stack

The recommended initial stack is:

- **Capacitor** for Android-first native packaging and future local file access.
- **React + TypeScript** for a fast, component-driven UI.
- **Vite** for simple frontend tooling.
- **Local-first storage** before cloud sync.

Future native needs include local save-file access, save parsing, optional cloud backup, and Android device adaptation across phones, tablets, foldables, and square handheld screens such as RG Rotate.

## Phase 1 Scope

Phase 1 creates the project documentation and initial architecture direction. It intentionally avoids complex functionality.

Allowed mock data:

- current game: SoulSilver
- current location: Goldenrod City
- badge count: 3
- party summary
- journey timeline entries
- Pokédex search mock entries

Not in Phase 1:

- all-generation save parsers
- cloud sync implementation
- complete encyclopedia data
- emulator automation
- OCR
- complex account systems

## Documentation

Start here:

- [Vision](./VISION.md)
- [Product](./PRODUCT.md)
- [Roadmap](./ROADMAP.md)
- [AI read-first guide](./docs/AI_READFIRST.md)
- [Design system](./docs/DESIGN_SYSTEM.md)
- [UI reference notes](./docs/UI_REFERENCE.md)
- [Architecture](./docs/ARCHITECTURE.md)
- [Parser proposal](./docs/PARSER_PROPOSAL.md)
- [Cloud sync proposal](./docs/CLOUD_SYNC_PROPOSAL.md)

## Development

Stack: **Capacitor + React + TypeScript + Vite** (Phase 2 mock app).

### Prerequisites

- Node.js 20+
- npm
- Android Studio (for building/running the Android shell)

### Setup

```bash
npm install
npm run dev
```

Open the local dev server URL (default `http://localhost:5173`) to preview the responsive mock UI in a browser.

### Build & Android

```bash
npm run build          # typecheck + web production build
npm run cap:sync       # build and sync web assets into android/
npm run cap:android    # open Android Studio (after sync)
```

In Android Studio:

1. Open the `android/` folder.
2. Create/start an AVD (Pixel 5 or similar; API 34+ recommended).
3. Run the `app` configuration on the emulator or a connected device.

Command-line debug build (requires Android SDK + `android/local.properties`):

```bash
echo "sdk.dir=$ANDROID_HOME" > android/local.properties
cd android && ./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.tito.titodex/.MainActivity
```

Fonts are bundled locally (`@fontsource/nunito`) so the WebView does not depend on Google Fonts at runtime.

Mock data is hard-coded for SoulSilver / Goldenrod City (3 badges) per Phase 2 scope.
