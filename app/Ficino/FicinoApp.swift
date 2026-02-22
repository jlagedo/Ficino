import SwiftUI
import TipKit

@main
struct FicinoApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .frame(width: 380, height: 540)
                .task {
                    try? Tips.configure([.displayFrequency(.immediate)])
                }
        } label: {
            Label("Ficino", systemImage: "waveform")
        }
        .menuBarExtraStyle(.window)
    }
}
