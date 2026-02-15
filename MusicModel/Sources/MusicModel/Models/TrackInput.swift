import Foundation

public struct TrackInput: Sendable {
    public let name: String
    public let artist: String
    public let album: String
    public let genre: String
    public let durationString: String

    public init(name: String, artist: String, album: String, genre: String, durationString: String) {
        self.name = name
        self.artist = artist
        self.album = album
        self.genre = genre
        self.durationString = durationString
    }
}
