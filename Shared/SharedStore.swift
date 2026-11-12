import Foundation

enum DictationState: String, Codable {
    case idle
    case recording
    case transcribing
    case error
}

enum DictationCommandKind: String, Codable {
    case start
    case stop
    case cancel
}

struct DictationCommand: Codable {
    var id = UUID()
    var kind: DictationCommandKind
    var modeID: String?
    var issuedAt = Date()
}

struct TranscriptPayload: Codable {
    var id = UUID()
    var text: String
    var modeID: String
    var createdAt = Date()
}

/// State shared between the app, the keyboard and the widgets through the App Group.
enum SharedStore {
    private static var defaults: UserDefaults { AppGroup.defaults }

    private enum Key {
        static let heartbeat = "session.heartbeat"
        static let state = "session.state"
        static let statusMessage = "session.statusMessage"
        static let command = "session.command"
        static let transcript = "session.transcript"
        static let pendingStart = "session.pendingStart"
        static let modes = "modes"
        static let selectedModeID = "modes.selected"
        static let knownBuiltInModeIDs = "modes.knownBuiltIns"
        static let keyboardConnected = "keyboard.connected"
        static let livePartial = "session.livePartial"
    }

    /// The app refreshes the heartbeat from its audio tap while a background session is running.
    static let heartbeatTimeout: TimeInterval = 3

    static var isSessionAlive: Bool {
        let last = defaults.double(forKey: Key.heartbeat)
        return last > 0 && Date().timeIntervalSince1970 - last < heartbeatTimeout
    }

    static func touchHeartbeat() {
        defaults.set(Date().timeIntervalSince1970, forKey: Key.heartbeat)
    }

    /// True once the keyboard has run with Full Access (writing to the App Group requires it).
    static var keyboardHasConnected: Bool { defaults.bool(forKey: Key.keyboardConnected) }

    static func markKeyboardConnected() {
        if !keyboardHasConnected { defaults.set(true, forKey: Key.keyboardConnected) }
    }

    static func clearHeartbeat() {
        defaults.removeObject(forKey: Key.heartbeat)
    }

    static var state: DictationState {
        get { defaults.string(forKey: Key.state).flatMap(DictationState.init(rawValue:)) ?? .idle }
        set { defaults.set(newValue.rawValue, forKey: Key.state) }
    }

    static var statusMessage: String? {
        get { defaults.string(forKey: Key.statusMessage) }
        set { defaults.set(newValue, forKey: Key.statusMessage) }
    }

    static func publish(state: DictationState, message: String? = nil) {
        self.state = state
        statusMessage = message
        DarwinNotifier.shared.post(.state)
    }

    static var command: DictationCommand? {
        get { decode(DictationCommand.self, key: Key.command) }
        set { encode(newValue, key: Key.command) }
    }

    static func send(_ command: DictationCommand) {
        self.command = command
        DarwinNotifier.shared.post(.command)
    }

    static var transcript: TranscriptPayload? {
        get { decode(TranscriptPayload.self, key: Key.transcript) }
        set { encode(newValue, key: Key.transcript) }
    }

    static func publish(transcript: TranscriptPayload) {
        self.transcript = transcript
        DarwinNotifier.shared.post(.transcript)
    }

    /// Rolling preview of the words recognised so far while recording; nil when not recording.
    static var livePartial: String? {
        get { defaults.string(forKey: Key.livePartial) }
        set { defaults.set(newValue, forKey: Key.livePartial) }
    }

    static func publish(livePartial: String?) {
        guard self.livePartial != livePartial else { return }
        self.livePartial = livePartial
        DarwinNotifier.shared.post(.live)
    }

    /// A start request from a widget, control or shortcut that the app picks up when it becomes active.
    static var pendingStartModeID: String? {
        get { defaults.string(forKey: Key.pendingStart) }
        set { defaults.set(newValue, forKey: Key.pendingStart) }
    }

    static var modes: [DictationMode] {
        get {
            guard let saved = decode([DictationMode].self, key: Key.modes) else { return DictationMode.defaults }
            return addingNewBuiltIns(to: saved)
        }
        set {
            encode(newValue, key: Key.modes)
            defaults.set(DictationMode.defaults.map(\.id), forKey: Key.knownBuiltInModeIDs)
        }
    }

    /// Built-in modes shipped after the user customised their list are appended once; ones they deleted stay deleted.
    private static func addingNewBuiltIns(to saved: [DictationMode]) -> [DictationMode] {
        let known = Set(defaults.stringArray(forKey: Key.knownBuiltInModeIDs) ?? ["raw", "clean", "message", "email", "notes", "prompt"])
        let present = Set(saved.map(\.id))
        let added = DictationMode.defaults.filter { !known.contains($0.id) && !present.contains($0.id) }
        guard !added.isEmpty else { return saved }
        let merged = saved + added
        modes = merged
        return merged
    }

    static var selectedModeID: String {
        get { defaults.string(forKey: Key.selectedModeID) ?? "clean" }
        set { defaults.set(newValue, forKey: Key.selectedModeID) }
    }

    static func mode(withID id: String?) -> DictationMode {
        let all = modes
        return all.first { $0.id == (id ?? selectedModeID) } ?? all.first ?? DictationMode.defaults[0]
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T?, key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
