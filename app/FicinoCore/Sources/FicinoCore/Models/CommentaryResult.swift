import Foundation

/// Transient result returned from `FicinoCore.process()`.
public struct CommentaryResult: Sendable {
    public let id: UUID
    public let commentary: String
    public let appleMusicURL: URL?
    public let trackName: String
    public let artist: String
    public let album: String
    public let genre: String

    public init(id: UUID, commentary: String, appleMusicURL: URL?, trackName: String, artist: String, album: String, genre: String) {
        self.id = id
        self.commentary = commentary
        self.appleMusicURL = appleMusicURL
        self.trackName = trackName
        self.artist = artist
        self.album = album
        self.genre = genre
    }
}
