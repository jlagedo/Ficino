import SwiftUI
import Combine
import MusicKit
import MusicModel
import FicinoCore
import os

private let logger = Logger(subsystem: "com.ficino", category: "AppState")

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State
    @Published var currentTrack: TrackInfo?
    @Published var currentComment: String?
    @Published var currentArtwork: NSImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var history: [CommentEntry] = []
    @Published var setupError: String?

    @Published var isPaused: Bool {
        didSet { UserDefaults.standard.set(isPaused, forKey: "isPaused") }
    }
    @Published var skipThreshold: TimeInterval {
        didSet { UserDefaults.standard.set(skipThreshold, forKey: "skipThreshold") }
    }
    @Published var notificationDuration: TimeInterval {
        didSet { UserDefaults.standard.set(notificationDuration, forKey: "notificationDuration") }
    }

    // MARK: - Services
    private let musicListener = MusicListener()
    let notificationService = NotificationService()

    private var ficinoCore: FicinoCore?

    private var lastTrackID: String?
    private var trackStartTime: Date?
    private var commentTask: Task<Void, Never>?
    private var hasStarted = false

    private static let historyCapacity = 50

    // MARK: - Lifecycle

    init() {
        let defaults = UserDefaults.standard
        self.isPaused = defaults.bool(forKey: "isPaused")
        self.skipThreshold = defaults.object(forKey: "skipThreshold") as? TimeInterval ?? 5.0
        self.notificationDuration = defaults.object(forKey: "notificationDuration") as? TimeInterval ?? 30.0

        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            let geniusToken = Self.geniusAccessToken()
            if geniusToken != nil {
                logger.info("Genius API token found, Genius context enabled")
            }
            self.ficinoCore = FicinoCore(
                commentaryService: AppleIntelligenceService(),
                geniusAccessToken: geniusToken
            )
        }
        #endif

        start()
    }

    func startIfNeeded() {
        start()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        logger.notice("Starting services...")

        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            Task {
                let status = await FicinoCore.requestMusicKitAuthorization()
                logger.info("MusicKit authorization: \(String(describing: status))")
            }
        } else {
            setupError = "Ficino requires macOS 26 or later for Apple Intelligence"
        }
        #else
        setupError = "Apple Intelligence is not available on this system"
        #endif

        musicListener.onTrackChange = { [weak self] track, playerState in
            guard let self else { return }
            logger.info("Track change: \(track.name) - \(track.artist) (state: \(playerState))")
            Task { @MainActor in
                self.handleTrackChange(track: track, playerState: playerState)
            }
        }
        musicListener.start()
    }

    func stop() {
        musicListener.stop()
        commentTask?.cancel()
        Task { await ficinoCore?.cancel() }
    }

    // MARK: - Track Handling

    private func handleTrackChange(track: TrackInfo, playerState: String) {
        guard !isPaused else {
            logger.debug("Paused, ignoring track change")
            return
        }
        guard playerState == "Playing" else {
            logger.debug("State is '\(playerState)', ignoring (only handling Playing)")
            return
        }
        guard track.id != lastTrackID else {
            logger.debug("Same track (id=\(track.id)), ignoring duplicate")
            return
        }

        // Skip threshold: ignore tracks that were played too briefly
        if let startTime = trackStartTime, skipThreshold > 0 {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < skipThreshold {
                logger.info("Previous track played \(elapsed, format: .fixed(precision: 1))s (threshold: \(self.skipThreshold, format: .fixed(precision: 1))s), skipping commentary for it")
            }
        }
        trackStartTime = Date()

        logger.info("New track accepted: \"\(track.name)\" by \(track.artist) (id=\(track.id))")

        lastTrackID = track.id
        currentTrack = track
        currentComment = nil
        currentArtwork = nil
        errorMessage = nil
        setupError = nil

        commentTask?.cancel()

        commentTask = Task {
            isLoading = true

            guard let core = ficinoCore else {
                isLoading = false
                errorMessage = "Apple Intelligence is not available"
                return
            }

            logger.info("Processing track via FicinoCore...")

            // Kick off artwork fetch in parallel with commentary
            async let artworkTask: NSImage? = fetchArtwork(name: track.name, artist: track.artist)

            do {
                let commentary = try await core.process(track.asTrackRequest)

                guard !Task.isCancelled else {
                    logger.debug("Task cancelled (track changed before response)")
                    return
                }

                guard !commentary.isEmpty else {
                    isLoading = false
                    logger.warning("Empty comment from Apple Intelligence")
                    errorMessage = "Apple Intelligence returned an empty response"
                    return
                }

                // Artwork may arrive before or after commentary
                let artwork = await artworkTask

                guard !Task.isCancelled else { return }

                currentArtwork = artwork
                currentComment = commentary
                isLoading = false

                logger.info("Got comment (\(commentary.count) chars), showing notification")

                // Save to history
                let entry = CommentEntry(
                    track: track,
                    comment: commentary,
                    artwork: artwork
                )
                history.insert(entry, at: 0)
                if history.count > Self.historyCapacity {
                    history.removeLast()
                }

                // Send floating notification
                notificationService.duration = notificationDuration
                notificationService.send(
                    track: track,
                    comment: commentary,
                    artwork: artwork
                )
                logger.info("Floating notification sent (duration: \(self.notificationDuration, format: .fixed(precision: 0))s)")

            } catch is CancellationError {
                logger.debug("Task cancelled")
                return
            } catch {
                guard !Task.isCancelled else { return }
                isLoading = false
                logger.error("FicinoCore error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    private static func geniusAccessToken() -> String? {
        guard let token = Bundle.main.infoDictionary?["GeniusAccessToken"] as? String,
              !token.isEmpty,
              !token.hasPrefix("$(") else {
            return nil
        }
        return token
    }

    private nonisolated func fetchArtwork(name: String, artist: String) async -> NSImage? {
        var request = MusicCatalogSearchRequest(term: "\(artist) \(name)", types: [Song.self])
        request.limit = 1
        guard let song = try? await request.response().songs.first,
              let url = song.artwork?.url(width: 600, height: 600) else { return nil }
        return await loadImage(from: url)
    }

    private nonisolated func loadImage(from url: URL) async -> NSImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return NSImage(data: data)
        } catch {
            logger.error("Failed to load artwork: \(error.localizedDescription)")
            return nil
        }
    }
}
