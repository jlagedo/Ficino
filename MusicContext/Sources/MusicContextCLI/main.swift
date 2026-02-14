import Foundation
import MusicContext

guard CommandLine.arguments.count >= 4 else {
    print("Usage: music-context-cli <Artist> <Album> <Track> [DurationMs]")
    print("Example: music-context-cli \"Radiohead\" \"OK Computer\" \"Let Down\" 299000")
    exit(1)
}

let artist = CommandLine.arguments[1]
let album = CommandLine.arguments[2]
let track = CommandLine.arguments[3]
let durationMs: Int? = CommandLine.arguments.count >= 5 ? Int(CommandLine.arguments[4]) : nil

guard !artist.isEmpty, !album.isEmpty, !track.isEmpty else {
    print("Error: Artist, album, and track name cannot be empty")
    exit(1)
}

let provider = MusicBrainzProvider(
    appName: "MusicContextCLI",
    version: "0.1.0",
    contact: "musiccontext@example.com"
)

do {
    let durationInfo = durationMs.map { " (\($0)ms)" } ?? ""
    print("Fetching context for: \"\(track)\" by \(artist) from \"\(album)\"\(durationInfo)...")
    print()

    let context = try await provider.fetchContext(artist: artist, track: track, album: album, durationMs: durationMs)

    // Track
    print("── Track ──────────────────────────────────")
    print("  Title:       \(context.track.title)")
    if let ms = context.track.durationMs {
        let seconds = ms / 1000
        print("  Duration:    \(seconds / 60):\(String(format: "%02d", seconds % 60))")
    }
    if !context.track.genres.isEmpty {
        print("  Genres:      \(context.track.genres.joined(separator: ", "))")
    }
    if !context.track.tags.isEmpty {
        print("  Tags:        \(context.track.tags.prefix(10).joined(separator: ", "))")
    }
    if let isrc = context.track.isrc {
        print("  ISRC:        \(isrc)")
    }
    if let rating = context.track.communityRating {
        print("  Rating:      \(String(format: "%.1f", rating))/5")
    }
    if let mbid = context.track.musicBrainzId {
        print("  MBID:        \(mbid)")
    }
    print()

    // Artist
    print("── Artist ─────────────────────────────────")
    print("  Name:        \(context.artist.name)")
    if let type = context.artist.type {
        print("  Type:        \(type)")
    }
    if let country = context.artist.country {
        print("  Country:     \(country)")
    }
    if let since = context.artist.activeSince {
        let until = context.artist.activeUntil ?? "present"
        print("  Active:      \(since) – \(until)")
    }
    if let dis = context.artist.disambiguation, !dis.isEmpty {
        print("  Disambig:    \(dis)")
    }
    if let mbid = context.artist.musicBrainzId {
        print("  MBID:        \(mbid)")
    }
    print()

    // Album
    print("── Album ──────────────────────────────────")
    print("  Title:       \(context.album.title)")
    if let date = context.album.releaseDate {
        print("  Released:    \(date)")
    }
    if let country = context.album.country {
        print("  Country:     \(country)")
    }
    if let label = context.album.label {
        print("  Label:       \(label)")
    }
    if let count = context.album.trackCount {
        print("  Tracks:      \(count)")
    }
    if let status = context.album.status {
        print("  Status:      \(status)")
    }
    if let type = context.album.albumType {
        print("  Type:        \(type)")
    }
    if let mbid = context.album.musicBrainzId {
        print("  MBID:        \(mbid)")
    }
    print()
    print("Done.")

} catch let error as MusicContextError {
    print("Error: \(error.description)")
    exit(1)
} catch {
    print("Unexpected error: \(error)")
    exit(1)
}
