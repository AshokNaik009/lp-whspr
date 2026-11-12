import AppIntents
import SwiftUI

@main
struct LeapWhisperApp: App {
    @StateObject private var controller = DictationController.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var models = ModelManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(controller)
                .environmentObject(settings)
                .environmentObject(models)
                .onOpenURL { controller.handle(url: $0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { controller.handlePendingStart() }
                }
        }
    }
}

struct LeapWhisperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartDictationIntent(),
            phrases: ["Dictate with \(.applicationName)", "Start \(.applicationName)"],
            shortTitle: "Dictate",
            systemImageName: "waveform"
        )
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Dictate", systemImage: "waveform") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            ModelsView()
                .tabItem { Label("Models", systemImage: "cpu") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
