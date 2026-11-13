import AppIntents
import SwiftUI

@main
struct LeapWhisperApp: App {
    @StateObject private var controller = DictationController.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var models = ModelManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let navigationBar = UINavigationBar.appearance()
        navigationBar.largeTitleTextAttributes = [.font: UIFont.jakarta(size: 34, .bold)]
        navigationBar.titleTextAttributes = [.font: UIFont.jakarta(size: 17, .semibold)]
        UITabBarItem.appearance().setTitleTextAttributes([.font: UIFont.jakarta(size: 10, .medium)], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: UIFont.jakarta(size: 13, .medium)], for: .normal)
        // Set before the system performs an intent on a background launch, which never builds the scene.
        DictationIntentBridge.toggle = { await DictationController.shared.toggleFromIntent() }
        DictationIntentBridge.cancel = { DictationController.shared.cancelRecording() }
        DictationIntentBridge.micOff = { DictationController.shared.turnMicOffFromIntent() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(controller)
                .environmentObject(settings)
                .environmentObject(models)
                .onOpenURL { controller.handle(url: $0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { controller.handlePendingStart() }
                    if phase == .background { controller.openedFromKeyboard = false }
                }
        }
    }
}

struct LeapWhisperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleDictationIntent(),
            phrases: ["Dictate with \(.applicationName)", "Start \(.applicationName)", "Stop \(.applicationName)"],
            shortTitle: "Dictate",
            systemImageName: "waveform"
        )
    }
}

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings

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
        .tint(settings.appearance.isFlat ? FlatPalette.ink : Theme.accent)
        .environment(\.font, .jakarta(.body))
        .environment(\.flatTheme, settings.appearance.isFlat)
        .preferredColorScheme(settings.appearance.colorScheme)
    }
}
