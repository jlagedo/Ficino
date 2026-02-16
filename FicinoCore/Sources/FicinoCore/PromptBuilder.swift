import Foundation
import MusicKit
import MusicModel

struct PromptBuilder {

    /// Build a TrackInput from a TrackRequest, enriched with MusicKit metadata when available.
    static func buildTrackInput(from request: TrackRequest, song: Song?) -> TrackInput {
        let minutes = request.durationMs / 60_000
        let seconds = (request.durationMs % 60_000) / 1000
        let durationString = String(format: "%d:%02d", minutes, seconds)

        let context = song.flatMap { buildContext(from: $0) }

        return TrackInput(
            name: request.name,
            artist: request.artist,
            album: request.album,
            genre: request.genre,
            durationString: durationString,
            context: context
        )
    }

    /// Extract all available MusicKit metadata from a Song into a context string for the LLM.
    private static func buildContext(from song: Song) -> String? {
        var parts: [String] = []

        // Genre names (direct property, no relationship needed)
        if !song.genreNames.isEmpty {
            parts.append("Genres: \(song.genreNames.joined(separator: ", "))")
        }

        // Composers (relationship)
        if let composers = song.composers, !composers.isEmpty {
            let names = composers.map(\.name)
            parts.append("Composers: \(names.joined(separator: ", "))")
        }

        // Release date (direct property on Song)
        if let releaseDate = song.releaseDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            parts.append("Release date: \(formatter.string(from: releaseDate))")
        }

        // Disc and track number
        if let disc = song.discNumber, let track = song.trackNumber {
            parts.append("Disc \(disc), track \(track)")
        } else if let track = song.trackNumber {
            parts.append("Track number: \(track)")
        }

        // ISRC
        if let isrc = song.isrc {
            parts.append("ISRC: \(isrc)")
        }

        // Content rating
        if let rating = song.contentRating {
            parts.append("Content rating: \(rating)")
        }

        // Classical work name
        if let workName = song.workName {
            parts.append("Work: \(workName)")
        }

        // Editorial notes (Apple Music editorial descriptions — very rich context)
        if let notes = song.editorialNotes {
            if let standard = notes.standard, !standard.isEmpty {
                parts.append("Editorial notes: \(stripHTML(standard))")
            } else if let short = notes.short, !short.isEmpty {
                parts.append("Editorial notes: \(stripHTML(short))")
            }
        }

        // Audio variants (Dolby Atmos, Lossless, Hi-Res, etc.)
        if let variants = song.audioVariants, !variants.isEmpty {
            let names = variants.map { String(describing: $0) }
            parts.append("Audio formats: \(names.joined(separator: ", "))")
        }

        // Album details (from relationship)
        if let albums = song.albums, let album = albums.first {
            parts.append("Album: \(album.title)")

            if let albumNotes = album.editorialNotes {
                if let standard = albumNotes.standard, !standard.isEmpty {
                    parts.append("Album editorial notes: \(stripHTML(standard))")
                } else if let short = albumNotes.short, !short.isEmpty {
                    parts.append("Album editorial notes: \(stripHTML(short))")
                }
            }

            if let labels = album.recordLabels, !labels.isEmpty {
                let names = labels.map(\.name)
                parts.append("Label: \(names.joined(separator: ", "))")
            }

            if album.trackCount > 0 {
                parts.append("Album track count: \(album.trackCount)")
            }

            if let albumReleaseDate = album.releaseDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                parts.append("Album release date: \(formatter.string(from: albumReleaseDate))")
            }
        }

        // Artist details (from relationship)
        if let artists = song.artists, !artists.isEmpty {
            // All credited artists
            if artists.count > 1 {
                let names = artists.map(\.name)
                parts.append("All artists: \(names.joined(separator: ", "))")
            }

            if let artist = artists.first {
                // Artist genres
                if let artistGenres = artist.genres, !artistGenres.isEmpty {
                    let names = artistGenres.map(\.name)
                    parts.append("Artist genres: \(names.joined(separator: ", "))")
                }

                // Top songs — gives the LLM a sense of the artist's catalogue
                if let topSongs = artist.topSongs, !topSongs.isEmpty {
                    let titles = topSongs.prefix(5).map(\.title)
                    parts.append("Artist's top songs: \(titles.joined(separator: ", "))")
                }

                // Similar artists
                if let similar = artist.similarArtists, !similar.isEmpty {
                    let names = similar.prefix(5).map(\.name)
                    parts.append("Similar artists: \(names.joined(separator: ", "))")
                }

                // Latest release
                if let latest = artist.latestRelease {
                    parts.append("Artist's latest release: \(latest.title)")
                }
            }
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n")
    }

    /// Extract artwork URL from a MusicKit Song.
    static func artworkURL(from song: Song, width: Int = 600, height: Int = 600) -> URL? {
        song.artwork?.url(width: width, height: height)
    }

    /// Strip HTML tags from editorial notes.
    private static func stripHTML(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
