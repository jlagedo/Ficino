import Foundation
import MusicKit
import os

private let logger = Logger(subsystem: "com.ficino", category: "MusicContext")

public actor MusicContextService {
    private let musicKit: MusicKitProvider
    private let genius: GeniusProvider?

    public init(geniusAccessToken: String? = nil) {
        self.musicKit = MusicKitProvider()
        self.genius = geniusAccessToken.map { GeniusProvider(accessToken: $0) }
    }

    /// Fetch metadata from MusicKit + Genius in parallel, format into v17 section blocks.
    /// Always returns at least a `[Song]` section — both lookups are failable.
    public func fetch(name: String, artist: String, album: String, genre: String) async -> String {
        // MusicKit + Genius in parallel (both non-fatal)
        async let songResult: Song? = {
            do {
                let result = try await musicKit.searchSong(artist: artist, track: name, album: album)
                logger.info("MusicKit match: \"\(result.title)\" by \(result.artistName)")
                return result
            } catch {
                logger.warning("MusicKit lookup failed (non-fatal): \(error.localizedDescription)")
                return nil
            }
        }()

        async let geniusResult: MusicContextData? = {
            guard let genius else {
                logger.debug("Genius: skipped (no token)")
                return nil
            }
            do {
                logger.info("Genius: searching \"\(name)\" by \(artist)")
                let data = try await genius.fetchContext(artist: artist, track: name, album: album)
                logger.info("Genius match: \"\(data.track.title)\" by \(data.artist.name)")
                return data
            } catch {
                logger.warning("Genius lookup failed (non-fatal): \(error.localizedDescription)")
                return nil
            }
        }()

        let song = await songResult
        let geniusData = await geniusResult

        let sections = PromptBuilder.build(
            name: name, artist: artist, album: album, genre: genre,
            song: song, geniusData: geniusData
        )

        logger.debug("Built sections (\(sections.count) chars):\n\(sections)")
        return sections
    }

    /// Request MusicKit authorization.
    public static func requestAuthorization() async -> MusicAuthorization.Status {
        await MusicKitProvider.authorize()
    }
}
