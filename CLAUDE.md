# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Ficino

A macOS menu bar app that listens to Apple Music track changes and delivers AI-powered commentary via Claude CLI or Apple Intelligence. Runs as a menu bar utility (LSUIElement=true, no dock icon). Zero external dependencies — pure Apple frameworks.

## Build & Run

```sh
./build.sh          # kills running instance, builds with xcodebuild, launches app
```

Or open `Ficino.xcodeproj` in Xcode directly.

Build output: `./build/Build/Products/Debug/Ficino.app`

Build command used internally:
```sh
xcodebuild -project Ficino.xcodeproj -scheme Ficino -derivedDataPath ./build build
```

**Requirements:** macOS 14+, Claude Code CLI at `/usr/local/bin/claude`, Apple Music.

**No test suite exists.** Testing is manual via build and run.

## Architecture

**Pattern:** MVVM with a single `AppState` observable object coordinating services. Views bind to `@StateObject AppState`.

**Source layout:**
- `Ficino/Models/` — Data types and state (`AppState`, `TrackInfo`, `Personality`, `CommentEntry`, `AIEngine`)
- `Ficino/Services/` — Business logic (`MusicListener`, `ClaudeService`, `AppleIntelligenceService`, `ArtworkService`, `NotificationService`)
- `Ficino/Views/` — SwiftUI components (`MenuBarView`, `NowPlayingView`, `HistoryView`, `PersonalityPickerView`, `SettingsView`)

**Key flow:** MusicListener detects track change via `DistributedNotificationCenter` → `AppState.handleTrackChange()` → parallel artwork fetch + commentary request → result saved to history → floating NSPanel notification shown → every 5 songs triggers a review.

**ClaudeService** is a Swift `actor` that manages a persistent Claude CLI subprocess with JSON streaming over stdin/stdout. It handles process lifecycle, crash recovery (max 3 retries), stale response draining, and 30-second timeouts.

**CommentaryService** is the protocol both `ClaudeService` and `AppleIntelligenceService` conform to, allowing backend swapping. Apple Intelligence requires macOS 26+ and uses the `FoundationModels` framework.

**Notifications** are custom floating `NSPanel` windows (not system UNUserNotificationCenter), hosted with SwiftUI content and auto-dismissed after a configurable duration.

**Preferences** persist via `UserDefaults` (personality, AI engine, model name, skip threshold, notification duration).

## Important Details

- App sandbox is **disabled** in `Ficino.entitlements` — needed for subprocess spawning and DistributedNotificationCenter access
- `FicinoApp.swift` is the `@main` entry using `MenuBarExtra` scene API
- Album artwork is fetched via AppleScript bridge to Music.app, cached as temp files, cleaned between tracks
- History is capped at 50 entries
- The 6 personality options each have detailed system prompts defined in `Personality.swift`
