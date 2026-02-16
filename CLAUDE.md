# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Ficino

A macOS menu bar app that listens to Apple Music track changes and delivers AI-powered commentary via Apple Intelligence. Runs as a menu bar utility (LSUIElement=true, no dock icon). Zero external dependencies — pure Apple frameworks.

## Build & Run

Open `Ficino.xcodeproj` in Xcode, or build from CLI:

```sh
xcodebuild -project Ficino.xcodeproj -scheme Ficino -derivedDataPath ./build build
```

Build output: `./build/Build/Products/Debug/Ficino.app`

There's a second scheme **MusicContextGenerator** for the metadata testing tool:
```sh
xcodebuild -project Ficino.xcodeproj -scheme MusicContextGenerator -derivedDataPath ./build build
```

**Requirements:** macOS 26+, Apple Music.

**No test suite exists.** Testing is manual via build and run.

## Architecture

**Pattern:** MVVM with a single `AppState` observable object coordinating services. Views bind to `@StateObject AppState`.

**Source layout:**
- `Ficino/Models/` — Data types and state (`AppState`, `TrackInfo`, `CommentEntry`)
- `Ficino/Services/` — Business logic (`MusicListener`, `NotificationService`)
- `Ficino/Views/` — SwiftUI components (`MenuBarView`, `NowPlayingView`, `HistoryView`, `SettingsView`)
- `FicinoCore/` — Facade actor orchestrating MusicKit lookup + prompt enrichment + commentary generation
- `MusicModel/` — AI commentary layer (`CommentaryService` protocol, `AppleIntelligenceService`, `Personality`, `TrackInput`)
- `MusicContext/` — Music metadata from MusicBrainz, MusicKit, and Genius APIs
- `MusicContextGenerator/` — Standalone macOS app for testing MusicContext providers (GUI + CLI mode)

**Key flow:** MusicListener detects track change via `DistributedNotificationCenter` → `AppState.handleTrackChange()` → `FicinoCore.process()` (MusicKit lookup → enriched TrackInput → commentary generation) → artwork loaded from URL → result saved to history → floating NSPanel notification shown.

### FicinoCore Package

`FicinoCore/` is the main orchestration layer. The `FicinoCore` actor is the single entry point for the app:
- Takes a `TrackRequest` (notification data) and returns a `TrackResult` (commentary + artwork URL)
- Internally: MusicKit catalog search → `PromptBuilder` enriches `TrackInput` with metadata (genres, composers, editorial notes, release date, similar artists, etc.) → `CommentaryService` generates commentary
- `CommentaryService` is dependency-injected — app passes in `AppleIntelligenceService`
- MusicKit failures are non-fatal — commentary still generates with basic track info

### Services

**AppleIntelligenceService** (in `MusicModel/`) uses the `FoundationModels` framework (macOS 26+) to generate commentary. It conforms to `CommentaryService`, the protocol boundary for the AI backend. The prompt includes an optional `context` field from `TrackInput` with MusicKit metadata when available.

**Notifications** are custom floating `NSPanel` windows (not system UNUserNotificationCenter), hosted with SwiftUI content, drag-to-dismiss, and auto-dismissed after a configurable duration. This avoids system permission prompts and gives full control over styling/positioning.

### MusicModel Package

`MusicModel/` is a Swift package containing the AI interaction layer:
- `CommentaryService` protocol — interface for AI backends
- `AppleIntelligenceService` — `FoundationModels` wrapper (`LanguageModelSession`)
- `Personality` enum — single "Ficino" personality with system prompt
- `TrackInput` — normalized track data passed to the LLM (includes optional `context` for enriched metadata)

### MusicContext Package

`MusicContext/` is a standalone Swift package with three providers:

- **MusicBrainzProvider** — Actor wrapping MusicBrainz REST API with rate limiting (1 req/sec). Has a multi-fallback search strategy: strips Apple Music suffixes (" - EP", " (Deluxe)"), featuring credits, collaborator names to improve match rates. Multi-stage lookup: recording → tags/genres → artist details → release group → label/format.
- **MusicKitProvider** — Actor wrapping Apple MusicKit catalog search with smart matching (exact → fuzzy → fallback). Loads full relationships (albums, artists, composers, genres, audio variants).
- **GeniusProvider** — Actor wrapping Genius API with rate limiting (5 req/sec). Extracts songwriting credits, producer info, song descriptions, and relationship data (samples, sampled_by, covers, interpolates).

**MusicContextGenerator** can run as GUI or CLI: `-p mb|mk|g <Artist> <Album> <Track> [DurationMs]` or `-p mk --id <CatalogID>`.

## Xcode Project Rules

- **NEVER modify `.pbxproj` or any file inside `.xcodeproj`** — one corrupted project file wastes hours. The project uses Xcode 16+ synchronized folders (`PBXFileSystemSynchronizedRootGroup`), so creating/editing/deleting Swift files on disk is automatically picked up by Xcode.
- For structural changes (new targets, build settings, frameworks, build phases), instruct the user to do it manually in Xcode.

## Platform

**This is a macOS-only app.** Many Apple frameworks have APIs that are iOS-only or marked `@available(macOS, unavailable)`. Before proposing or using any Apple framework API, verify it is actually available on macOS — do not assume iOS availability implies macOS availability. Notable examples: `SystemMusicPlayer` (MusicKit) is explicitly unavailable on macOS.

## Reference Docs

- `docs/apple_fm_specs.md` — Detailed Apple Intelligence Foundation Models specification (architecture, API, benchmarks, token budgets). Consult this when working with `FoundationModels` framework features.

## Important Details

- App sandbox is **enabled** with `com.apple.security.network.client` for MusicKit catalog access
- `FicinoApp.swift` is the `@main` entry using `MenuBarExtra` scene API
- MusicKit authorization is requested at startup for catalog search access
- Album artwork comes from MusicKit catalog search (URL-based, loaded via URLSession)
- History is capped at 50 entries with JPEG-compressed thumbnails (48pt, 0.7 quality)
- Single personality ("Ficino") with a detailed system prompt defined in `Personality.swift`
- **Preferences** persist via `UserDefaults`: skip threshold, notification duration
- Skip threshold enforcement: only generates commentary for tracks played longer than the threshold, preventing spam from rapid skipping
- All services use **actor isolation** for thread safety (FicinoCore, AppleIntelligenceService, MusicBrainzProvider, MusicKitProvider, GeniusProvider, RateLimiter)
- `AppState` and `NotificationService` are `@MainActor`-isolated for UI safety
