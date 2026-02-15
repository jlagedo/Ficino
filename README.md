# Ficino

A macOS menu bar app that listens to Apple Music and delivers AI-powered commentary on every track you play — powered entirely by Apple Intelligence.

## What it does

When a song starts playing in Apple Music, Ficino catches the track change, generates a commentary via on-device Apple Intelligence, and shows a custom floating notification with its take on the song. Every five tracks, it delivers a vibe review of your recent listening.

Ficino is a music obsessive who lives for the story behind the song — the failed session that produced a masterpiece, the personal feud that shaped a lyric, the borrowed chord progression that changed a genre.

## Tech Stack

- **Swift / SwiftUI** — menu bar UI via `MenuBarExtra` scene API
- **DistributedNotificationCenter** — catches `com.apple.Music.playerInfo` events
- **FoundationModels** (Apple Intelligence) — on-device LLM commentary, zero API keys
- **Custom floating NSPanel** — styled notifications with album art, no system permission prompts
- **AppleScript** — fetches album artwork directly from Music.app

## Packages

- **MusicModel** — Swift package for the AI commentary layer (`CommentaryService` protocol, `AppleIntelligenceService`, personality definition)
- **MusicContext** — Swift package for fetching rich music metadata from MusicBrainz, Apple MusicKit, and Genius APIs
- **MusicContextGenerator** — Standalone macOS app for testing metadata providers (GUI + CLI mode)

## Building

Open `Ficino.xcodeproj` in Xcode and build, or from the command line:

```sh
xcodebuild -project Ficino.xcodeproj -scheme Ficino -derivedDataPath ./build build
```

To build the metadata testing tool:

```sh
xcodebuild -project Ficino.xcodeproj -scheme MusicContextGenerator -derivedDataPath ./build build
```

## Requirements

- macOS 26+
- Apple Music
