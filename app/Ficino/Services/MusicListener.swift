import Foundation
import os

private let logger = Logger(subsystem: "com.ficino", category: "MusicListener")

final class MusicListener {
    private let notificationCenter = DistributedNotificationCenter.default()
    private var observer: NSObjectProtocol?

    var onTrackChange: ((TrackInfo, String) -> Void)?

    func start() {
        logger.notice("Subscribing to com.apple.Music.playerInfo")
        observer = notificationCenter.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleNotification(notification)
        }
    }

    func stop() {
        logger.notice("Stopping")
        if let observer {
            notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    private func handleNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            logger.debug("Notification with no userInfo, ignoring")
            return
        }

        // Dump every key/value from the notification for debugging (suppressed in production)
        logger.debug("── playerInfo dump (\(userInfo.count) keys) ──")
        for (key, value) in userInfo.sorted(by: { "\($0.key)" < "\($1.key)" }) {
            logger.debug("  \("\(key)") = \("\(value)") (\(String(describing: type(of: value))))")
        }
        logger.debug("── end dump ──")

        let playerState = userInfo["Player State"] as? String ?? "unknown"
        let name = userInfo["Name"] as? String ?? "?"
        let artist = userInfo["Artist"] as? String ?? "?"
        logger.info("Raw notification: \"\(name)\" by \(artist) (state: \(playerState))")

        guard let track = TrackInfo(userInfo: userInfo) else {
            logger.warning("Could not parse TrackInfo, ignoring")
            return
        }

        onTrackChange?(track, playerState)
    }

    deinit {
        stop()
    }
}
