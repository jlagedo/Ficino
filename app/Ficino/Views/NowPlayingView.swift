import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let setupError = appState.setupError {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(.orange)
                Text(setupError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Setup error: \(setupError)")
        } else if let track = appState.currentTrack {
            HStack(alignment: .top, spacing: 12) {
                // Artwork
                Group {
                    if let artwork = appState.currentArtwork {
                        Image(nsImage: artwork)
                            .resizable()
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.quaternary)
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel("Album artwork for \(track.album)")

                // Track info + comment
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name)
                            .font(.system(.body, weight: .semibold))
                            .lineLimit(1)

                        Text("\(track.artist) — \(track.album)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Group {
                        if appState.isLoading {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("Listening...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .accessibilityLabel("Loading commentary")
                        } else if let comment = appState.currentComment {
                            CommentaryScrollView(text: comment)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else if let error = appState.errorMessage {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .lineLimit(3)
                                .transition(.opacity)
                                .accessibilityLabel("Error: \(error)")
                        }
                    }
                    .animation(.spring(duration: 0.4, bounce: 0.1), value: appState.isLoading)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Now playing: \(track.name) by \(track.artist)")
        } else {
            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Play something in Apple Music")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .accessibilityLabel("No track playing. Play something in Apple Music to get started.")
        }
    }
}

// MARK: - Commentary scroll with fade gradient

private struct CommentaryScrollView: View {
    let text: String
    @State private var contentOverflows = false

    var body: some View {
        ScrollView {
            Text(text)
                .font(.body)
                .lineSpacing(3)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { contentGeo in
                        Color.clear.preference(
                            key: ContentHeightKey.self,
                            value: contentGeo.size.height
                        )
                    }
                )
        }
        .frame(maxHeight: 120)
        .overlay(alignment: .bottom) {
            if contentOverflows {
                LinearGradient(
                    colors: [
                        Color(.windowBackgroundColor).opacity(0.8),
                        .clear,
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 20)
                .allowsHitTesting(false)
            }
        }
        .onPreferenceChange(ContentHeightKey.self) { height in
            contentOverflows = height > 120
        }
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
