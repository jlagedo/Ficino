import Foundation
import MusicKit
import MusicContext

// MARK: - Top-level entry

struct ContextExtractEntry: Codable {
    let artist: String
    let track: String
    let album: String
    let musickit: MusicKitJSON?
    let genius: MusicContextData?
}

// MARK: - MusicKit wrapper

struct MusicKitJSON: Codable {
    let song: MusicKitSongJSON
    let album: MusicKitAlbumJSON?
    let artist: MusicKitArtistJSON?
}

// MARK: - Song

struct MusicKitSongJSON: Codable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String?
    let trackNumber: Int?
    let discNumber: Int?
    let durationMs: Int?
    let genres: [String]
    let isrc: String?
    let composerName: String?
    let releaseDate: String?
    let hasLyrics: Bool
    let playCount: Int?
    let url: String?
    let artworkURL: String?
    let contentRating: String?
    let editorialNotesShort: String?
    let editorialNotesStandard: String?

    static func from(_ song: Song) -> MusicKitSongJSON {
        let durationMs = song.duration.map { Int($0 * 1000) }
        let artworkURL = song.artwork?.url(width: 600, height: 600)?.absoluteString
        let releaseDate = song.releaseDate.map { ISO8601DateFormatter().string(from: $0) }

        return MusicKitSongJSON(
            id: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            albumTitle: song.albumTitle,
            trackNumber: song.trackNumber,
            discNumber: song.discNumber,
            durationMs: durationMs,
            genres: song.genreNames,
            isrc: song.isrc,
            composerName: song.composerName,
            releaseDate: releaseDate,
            hasLyrics: song.hasLyrics,
            playCount: song.playCount,
            url: song.url?.absoluteString,
            artworkURL: artworkURL,
            contentRating: song.contentRating.map { "\($0)" },
            editorialNotesShort: song.editorialNotes?.short,
            editorialNotesStandard: song.editorialNotes?.standard
        )
    }
}

// MARK: - Album

struct MusicKitAlbumJSON: Codable {
    let id: String
    let title: String
    let artistName: String
    let releaseDate: String?
    let genres: [String]
    let trackCount: Int
    let copyright: String?
    let upc: String?
    let url: String?
    let artworkURL: String?
    let contentRating: String?
    let isCompilation: Bool?
    let isSingle: Bool?
    let editorialNotesShort: String?
    let recordLabels: [String]?

    static func from(_ album: Album) -> MusicKitAlbumJSON {
        let artworkURL = album.artwork?.url(width: 600, height: 600)?.absoluteString
        let releaseDate = album.releaseDate.map { ISO8601DateFormatter().string(from: $0) }
        let labels = album.recordLabels.map { $0.map { $0.name } }

        return MusicKitAlbumJSON(
            id: album.id.rawValue,
            title: album.title,
            artistName: album.artistName,
            releaseDate: releaseDate,
            genres: album.genreNames,
            trackCount: album.trackCount,
            copyright: album.copyright,
            upc: album.upc,
            url: album.url?.absoluteString,
            artworkURL: artworkURL,
            contentRating: album.contentRating.map { "\($0)" },
            isCompilation: album.isCompilation,
            isSingle: album.isSingle,
            editorialNotesShort: album.editorialNotes?.short,
            recordLabels: labels
        )
    }
}

// MARK: - Artist

struct MusicKitArtistJSON: Codable {
    let id: String
    let name: String
    let url: String?
    let artworkURL: String?
    let genres: [String]?
    let editorialNotesShort: String?
    let topSongs: [String]?
    let similarArtists: [String]?

    static func from(_ artist: Artist) -> MusicKitArtistJSON {
        let artworkURL = artist.artwork?.url(width: 600, height: 600)?.absoluteString
        let topSongs = artist.topSongs.map { $0.prefix(10).map { $0.title } }
        let similar = artist.similarArtists.map { $0.prefix(10).map { $0.name } }

        return MusicKitArtistJSON(
            id: artist.id.rawValue,
            name: artist.name,
            url: artist.url?.absoluteString,
            artworkURL: artworkURL,
            genres: artist.genreNames,
            editorialNotesShort: artist.editorialNotes?.short,
            topSongs: topSongs.map { Array($0) },
            similarArtists: similar.map { Array($0) }
        )
    }
}
