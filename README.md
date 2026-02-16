# Ficino

A macOS menu bar app that listens to Apple Music and delivers AI-powered commentary on every track you play — powered entirely by Apple Intelligence.

## What it does

When a song starts playing in Apple Music, Ficino catches the track change, looks up rich metadata via MusicKit (genres, composers, editorial notes, similar artists), generates a commentary via on-device Apple Intelligence, and shows a custom floating notification with album artwork and its take on the song.

Ficino is a music obsessive who lives for the story behind the song — the failed session that produced a masterpiece, the personal feud that shaped a lyric, the borrowed chord progression that changed a genre.

## Tech Stack

- **Swift / SwiftUI** — menu bar UI via `MenuBarExtra` scene API
- **DistributedNotificationCenter** — catches `com.apple.Music.playerInfo` events
- **FoundationModels** (Apple Intelligence) — on-device LLM commentary, zero API keys
- **MusicKit** — catalog search for album artwork, genres, composers, editorial notes, and artist metadata
- **Custom floating NSPanel** — styled notifications with album art, drag-to-dismiss, no system permission prompts

## Packages

- **FicinoCore** — Facade actor orchestrating MusicKit lookup → enriched prompt building → commentary generation. Clean boundary: `TrackRequest` in, `TrackResult` (commentary + artwork URL) out.
- **MusicModel** — AI commentary layer (`CommentaryService` protocol, `AppleIntelligenceService`, personality definition, `TrackInput`)
- **MusicContext** — Rich music metadata from MusicBrainz, Apple MusicKit, and Genius APIs
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
