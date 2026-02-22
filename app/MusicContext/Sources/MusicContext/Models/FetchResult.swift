import Foundation

public struct FetchResult: Sendable {
    public let sections: String
    public let appleMusicURL: URL?

    public init(sections: String, appleMusicURL: URL?) {
        self.sections = sections
        self.appleMusicURL = appleMusicURL
    }
}
