import Foundation

public protocol CommentaryService: Sendable {
    func getCommentary(for track: TrackInput) async throws -> String
    func cancelCurrent() async
    func prewarm() async
}

extension CommentaryService {
    public func prewarm() async {}
}
