import Foundation
import MusicKit
import MusicModel
import MusicContext
import SwiftData

public actor FicinoCore {
    private let commentaryService: any CommentaryService
    private let musicContext: MusicContextService
    private let historyStore: HistoryStore
    private var currentTask: Task<CommentaryResult, Error>?

    public init(
        commentaryService: any CommentaryService,
        geniusAccessToken: String? = nil,
        historyCapacity: Int = 200
    ) throws {
        self.commentaryService = commentaryService
        self.musicContext = MusicContextService(geniusAccessToken: geniusAccessToken)
        self.historyStore = try HistoryStore(capacity: historyCapacity)
    }

    /// Process a track change: fetch context, generate commentary, save to history.
    public func process(_ request: TrackRequest, thumbnailData: Data? = nil) async throws -> CommentaryResult {
        currentTask?.cancel()
        return try await runCommentary(request, thumbnailData: thumbnailData, updateCurrentTask: true)
    }

    /// Regenerate commentary for a track without cancelling in-flight work.
    public func regenerate(_ request: TrackRequest, thumbnailData: Data? = nil) async throws -> CommentaryResult {
        try await runCommentary(request, thumbnailData: thumbnailData, updateCurrentTask: false)
    }

    /// Cancel any in-flight processing.
    public func cancel() async {
        currentTask?.cancel()
        currentTask = nil
        await commentaryService.cancelCurrent()
    }

    /// Request MusicKit authorization.
    public static func requestMusicKitAuthorization() async -> MusicAuthorization.Status {
        await MusicContextService.requestAuthorization()
    }

    // MARK: - History

    public func history() async -> [CommentaryRecord] {
        await historyStore.getAll()
    }

    public func historyRecord(id: UUID) async -> CommentaryRecord? {
        await historyStore.getRecord(id: id)
    }

    public func searchHistory(query: String) async -> [CommentaryRecord] {
        await historyStore.search(query: query)
    }

    public func toggleFavorite(id: UUID) async -> Bool? {
        await historyStore.toggleFavorite(id: id)
    }

    public func deleteHistoryRecord(id: UUID) async {
        await historyStore.delete(id: id)
    }

    public func favorites() async -> [CommentaryRecord] {
        await historyStore.favorites()
    }

    public func updateThumbnail(id: UUID, data: Data) async {
        await historyStore.updateThumbnail(id: id, data: data)
    }

    public func shareText(for record: CommentaryRecord) -> String {
        var text = "\(record.trackName) by \(record.artist)"
        if !record.album.isEmpty {
            text += " (\(record.album))"
        }
        text += "\n\n\(record.commentary)"
        if let url = record.appleMusicURL {
            text += "\n\n\(url.absoluteString)"
        }
        return text
    }

    // MARK: - Private

    private func runCommentary(
        _ request: TrackRequest,
        thumbnailData: Data?,
        updateCurrentTask: Bool
    ) async throws -> CommentaryResult {
        let service = commentaryService
        let context = musicContext
        let store = historyStore

        let task = Task<CommentaryResult, Error> {
            async let warmup: Void = service.prewarm()
            let fetchResult = await context.fetch(
                name: request.name, artist: request.artist,
                album: request.album, genre: request.genre
            )
            _ = await warmup

            try Task.checkCancellation()

            let trackInput = TrackInput(
                name: request.name, artist: request.artist,
                album: request.album, genre: request.genre,
                durationString: "0:00", context: fetchResult.sections
            )

            let commentary = try await service.getCommentary(for: trackInput)

            let id = UUID()
            let record = CommentaryRecord(
                id: id,
                trackName: request.name,
                artist: request.artist,
                album: request.album,
                genre: request.genre,
                commentary: commentary,
                timestamp: Date(),
                appleMusicURL: fetchResult.appleMusicURL,
                persistentID: request.persistentID,
                isFavorited: false,
                thumbnailData: thumbnailData
            )
            await store.save(record)

            return CommentaryResult(
                id: id,
                commentary: commentary,
                appleMusicURL: fetchResult.appleMusicURL,
                trackName: request.name,
                artist: request.artist,
                album: request.album,
                genre: request.genre
            )
        }

        if updateCurrentTask {
            currentTask = task
        }

        do {
            let result = try await task.value
            if updateCurrentTask {
                currentTask = nil
            }
            return result
        } catch {
            if updateCurrentTask {
                currentTask = nil
            }
            throw error
        }
    }
}
