import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Now Playing
            NowPlayingView()
                .padding(16)

            // Controls
            HStack {
                Spacer()
                SettingsView()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // History
            HistoryView()
        }
        .background(.ultraThinMaterial)
        .task {
            appState.startIfNeeded()
        }
    }
}
