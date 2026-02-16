import Foundation
import MusicKit
import MusicModel
import MusicContext

public actor FicinoCore {
    private let commentaryService: any CommentaryService
    private let musicKit: MusicKitProvider
    private var currentTask: Task<TrackResult, Error>?

    public init(commentaryService: any CommentaryService) {
        self.commentaryService = commentaryService
        self.musicKit = MusicKitProvider()
    }

    /// Process a track change: look up MusicKit metadata, build enriched prompt, generate commentary.
    public func process(_ request: TrackRequest, personality: Personality) async throws -> TrackResult {
        // Cancel any in-flight processing
        currentTask?.cancel()

        let service = commentaryService
        let musicKit = self.musicKit

        let task = Task<TrackResult, Error> {
            // Phase 1: MusicKit lookup (failable)
            let song: Song? = await {
                do {
                    let result = try await musicKit.searchSong(
                        artist: request.artist,
                        track: request.name,
                        album: request.album
                    )
                    NSLog("[FicinoCore] MusicKit match: \"%@\" by %@", result.title, result.artistName)
                    return result
                } catch {
                    NSLog("[FicinoCore] MusicKit lookup failed (non-fatal): %@", error.localizedDescription)
                    return nil
                }
            }()

            try Task.checkCancellation()

            // Phase 2: Build enriched TrackInput
            let trackInput = PromptBuilder.buildTrackInput(from: request, song: song)
            let artworkURL = song.flatMap { PromptBuilder.artworkURL(from: $0) }

            // Phase 3: Generate commentary
            let commentary = try await service.getCommentary(for: trackInput, personality: personality)

            return TrackResult(commentary: commentary, artworkURL: artworkURL)
        }

        currentTask = task

        do {
            let result = try await task.value
            currentTask = nil
            return result
        } catch {
            currentTask = nil
            throw error
        }
    }

    /// Cancel any in-flight processing.
    public func cancel() async {
        currentTask?.cancel()
        currentTask = nil
        await commentaryService.cancelCurrent()
    }

    /// Request MusicKit authorization.
    public static func requestMusicKitAuthorization() async -> MusicAuthorization.Status {
        await MusicKitProvider.authorize()
    }
}
