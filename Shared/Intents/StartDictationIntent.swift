import AppIntents

struct StartDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Dictation"
    static let description = IntentDescription("Opens Leap Whisper and starts recording.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        SharedStore.pendingStartModeID = SharedStore.selectedModeID
        DarwinNotifier.shared.post(.pendingStart)
        return .result()
    }
}
