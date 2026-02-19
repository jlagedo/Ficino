# App — CLAUDE.md

macOS menu bar app that listens to Apple Music track changes and delivers AI-powered commentary via Apple Intelligence. Runs as a menu bar utility (LSUIElement=true, no dock icon). Zero external dependencies — pure Apple frameworks.

## Build & Run

Open `Ficino.xcodeproj` in Xcode, or build from CLI (run from repo root):

```sh
xcodebuild -project app/Ficino.xcodeproj -scheme Ficino -derivedDataPath ./build build
```

Build output: `./build/Build/Products/Debug/Ficino.app`

Second scheme **MusicContextGenerator** for the metadata testing tool:
```sh
xcodebuild -project app/Ficino.xcodeproj -scheme MusicContextGenerator -derivedDataPath ./build build
```

**Requirements:** macOS 26+, Xcode 16+, Apple Music.

**No test suite exists.** MusicModel and MusicContext have test targets but only stubs. Testing is manual via build and run.

## Source Layout

```
Ficino/                  App target (menu bar UI)
├── Models/                AppState, TrackInfo, CommentEntry
├── Services/              MusicListener, NotificationService
└── Views/                 MenuBarView, NowPlayingView, HistoryView, SettingsView

FicinoCore/              Orchestration package
├── FicinoCore.swift       Actor: process(TrackRequest) → String
└── Models/                TrackRequest

MusicModel/              AI layer package
├── Protocols/             CommentaryService protocol
├── Providers/             AppleIntelligenceService (FoundationModels wrapper)
└── Models/                TrackInput

MusicContext/            Metadata providers package
├── MusicContextService    Coordinates MusicKit + Genius lookups (parallel, both non-fatal)
├── PromptBuilder          Assembles metadata into [Section]...[End Section] blocks
├── Providers/             MusicKitProvider, GeniusProvider
├── Models/                API response types, error types (MusicBrains.swift)
└── Networking/            RateLimiter

MusicContextGenerator/   Standalone testing app (GUI + CLI mode)

FMPromptRunner/          CLI tool for ML eval pipeline (reads JSON prompts on stdin, runs FoundationModels)

ficino_music.fmadapter/  LoRA adapter metadata (rank 32, speculative decoding: 5 tokens)
```

## Architecture

**Pattern:** MVVM with a single `AppState` observable object coordinating services. Views bind to `@StateObject AppState`.

**Key flow:** MusicListener detects track change via `DistributedNotificationCenter` → `AppState.handleTrackChange()` → `FicinoCore.process()` (MusicContextService fetches MusicKit + Genius in parallel → PromptBuilder formats into section blocks → CommentaryService generates commentary) → artwork loaded from URL → result saved to history → floating NSPanel notification shown.

### FicinoCore

The `FicinoCore` actor is the single entry point for the app:
- Takes a `TrackRequest` (notification data) and returns a `String` (commentary)
- Internally: MusicContextService fetches metadata → `CommentaryService` generates commentary
- `CommentaryService` is dependency-injected — app passes in `AppleIntelligenceService`
- Both MusicKit and Genius lookups are non-fatal — commentary still generates with basic track info

### MusicModel

- `CommentaryService` protocol — interface for AI backends
- `AppleIntelligenceService` — `FoundationModels` wrapper (`LanguageModelSession`)
- `TrackInput` — normalized track data passed to the LLM (includes optional `context` for enriched metadata)

### MusicContext

Two metadata providers coordinated by `MusicContextService`:
- **MusicKitProvider** — Apple MusicKit catalog search with smart matching (exact → fuzzy → fallback). Full relationships (albums, artists, composers, genres, audio variants).
- **GeniusProvider** — Genius API with rate limiting (5 req/sec). Songwriting credits, producer info, song descriptions, relationship data (samples, covers, interpolates).

`PromptBuilder` formats fetched metadata into `[Section]...[End Section]` blocks consumed by the model's dual-stage pipeline (extract facts → write commentary).

**MusicContextGenerator** can run as GUI or CLI: `-p mk|g <Artist> <Album> <Track> [DurationMs]` or `-p mk --id <CatalogID>`.

### FMPromptRunner

CLI tool used by the ML eval pipeline (`ml/eval/run_model.sh`). Reads JSON prompts from stdin, runs each through the on-device `FoundationModels` framework, and writes JSON results to stdout. Part of the Xcode project (not a Swift package).

### Notifications

Custom floating `NSPanel` windows (not system UNUserNotificationCenter), hosted with SwiftUI content, drag-to-dismiss, and auto-dismissed after a configurable duration. Avoids system permission prompts, full control over styling/positioning.

## Xcode Project Rules

- **NEVER modify `.pbxproj` or any file inside `.xcodeproj`** — the project uses Xcode 16+ synchronized folders (`PBXFileSystemSynchronizedRootGroup`), so creating/editing/deleting Swift files on disk is automatically picked up by Xcode.
- For structural changes (new targets, build settings, frameworks, build phases), instruct the user to do it manually in Xcode.

## Platform

**macOS-only.** Before using any Apple framework API, verify it is available on macOS — do not assume iOS availability implies macOS availability. Notable example: `SystemMusicPlayer` (MusicKit) is explicitly unavailable on macOS.

## Secrets

Genius API requires a token. Copy `Secrets.xcconfig.template` to `Secrets.xcconfig` and fill in `GENIUS_ACCESS_TOKEN`. This file is gitignored.

## Key Details

- App sandbox **enabled** with `com.apple.security.network.client` and `foundation-model-adapter` entitlements
- `FicinoApp.swift` is the `@main` entry using `MenuBarExtra` scene API
- MusicKit authorization requested at startup for catalog search
- Album artwork from MusicKit catalog search (URL-based, loaded via URLSession)
- History capped at 50 entries with JPEG-compressed thumbnails (48pt, 0.7 quality)
- System prompt and personality are defined in the ML workspace instruction files (`ml/prompts/fm_instruction_v*.json`), shipped via the LoRA adapter
- **Preferences** via `UserDefaults`: skip threshold, notification duration
- Skip threshold: only generates commentary for tracks played longer than threshold
- All services use **actor isolation** for thread safety
- `AppState` and `NotificationService` are `@MainActor`-isolated
