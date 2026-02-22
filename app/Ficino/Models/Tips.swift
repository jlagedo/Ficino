import TipKit

struct DismissNotificationTip: Tip {
    var title: Text { Text("Dismiss Notification") }
    var message: Text? { Text("Tap to dismiss, or swipe toward the edge.") }
    var options: [any TipOption] { [Tips.MaxDisplayCount(1)] }
}

struct HistoryInteractionTip: Tip {
    static let commentaryReceived = Event(id: "commentaryReceived")

    var title: Text { Text("Explore Your History") }
    var message: Text? { Text("Click to expand, right-click for more options.") }
    var options: [any TipOption] { [Tips.MaxDisplayCount(1)] }

    var rules: [Rule] {
        #Rule(Self.commentaryReceived) { event in
            event.donations.count >= 2
        }
    }
}
