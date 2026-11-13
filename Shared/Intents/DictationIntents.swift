import AppIntents

/// What the app did with a press of "Dictate".
enum DictationToggleResult {
    case started
    case stopped
    case busy
    /// iOS wouldn't let the dictation start where the app was; it has to come to the front.
    case needsApp
}

/// The system performs these intents in the app's process, but the types are also compiled into the widget
/// extension, because the control and the Live Activity refer to them. The app installs its handlers here at launch.
@MainActor
enum DictationIntentBridge {
    static var toggle: (() async -> DictationToggleResult)?
    static var cancel: (() -> Void)?
    static var micOff: (() -> Void)?
}

enum DictationIntentError: Error, CustomLocalizedStringResourceConvertible {
    case needsApp

    var localizedStringResource: LocalizedStringResource { "Open Leap Whisper to start dictating." }
}

/// Starts a dictation, or stops the one in progress, without bringing the app forward when iOS allows it
/// (spec 009). Recording from the background is only permitted to an `AudioRecordingIntent` with a Live Activity.
struct ToggleDictationIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Dictate"
    static let description = IntentDescription("Starts a Leap Whisper dictation, or stops the one in progress.")

    @MainActor
    func perform() async throws -> some IntentResult {
        if DictationIntentBridge.toggle == nil {
            SharedStore.logStart("\(Date().formatted(date: .abbreviated, time: .standard)): opened the app. The action ran outside the app's process.")
        }
        let result = await DictationIntentBridge.toggle?() ?? .needsApp
        guard result == .needsApp else { return .result() }
        guard #available(iOS 18.2, *) else { throw DictationIntentError.needsApp }
        return .result(opensIntent: StartDictationIntent())
    }
}

/// Opens the app and starts recording there: the fallback when a background start is refused.
struct StartDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Dictation"
    static let description = IntentDescription("Opens Leap Whisper and starts recording.")
    static let openAppWhenRun = true
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        SharedStore.pendingStartModeID = SharedStore.selectedModeID
        DarwinNotifier.shared.post(.pendingStart)
        return .result()
    }
}

struct CancelDictationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cancel Dictation"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        DictationIntentBridge.cancel?()
        return .result()
    }
}

struct TurnMicOffIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Turn Mic Off"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        DictationIntentBridge.micOff?()
        return .result()
    }
}
