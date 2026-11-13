import SwiftUI
import UIKit

@MainActor
final class KeyboardModel: ObservableObject {
    @Published var state: DictationState = .idle
    @Published var statusMessage: String?
    @Published var sessionAlive = false
    @Published var modes: [DictationMode] = []
    @Published var selectedModeID = SharedStore.selectedModeID
    @Published var showsGlobeKey = true
    @Published var hint: String?
    @Published var liveText: String?
    @Published var recordingStartedAt: Date?
    @Published var showingHistory = false
    @Published var background = SharedStore.keyboardBackground
    @Published var history: [RecentDictation] = []
    @Published var micStandby = SharedStore.micStandby

    private weak var controller: KeyboardViewController?
    private var tokens: [UUID] = []
    private var pollTimer: Timer?
    private var unconfirmedStart: UUID?

    private static let lastInsertedKey = "keyboard.lastInsertedTranscript"

    init(controller: KeyboardViewController) {
        self.controller = controller
    }

    var hasFullAccess: Bool { controller?.hasFullAccess ?? false }

    func activate() {
        if hasFullAccess { SharedStore.markKeyboardConnected() }
        refresh()
        // Don't re-insert a transcript that was produced while the keyboard was hidden.
        if let latest = SharedStore.transcript, AppGroup.defaults.string(forKey: Self.lastInsertedKey) == nil {
            AppGroup.defaults.set(latest.id.uuidString, forKey: Self.lastInsertedKey)
        }
        guard tokens.isEmpty else { return }
        tokens.append(DarwinNotifier.shared.observe(.state) { [weak self] in self?.refresh() })
        tokens.append(DarwinNotifier.shared.observe(.transcript) { [weak self] in self?.insertLatestTranscript() })
        tokens.append(DarwinNotifier.shared.observe(.live) { [weak self] in self?.refresh() })
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func deactivate() {
        tokens.forEach(DarwinNotifier.shared.removeObserver)
        tokens.removeAll()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refresh() {
        sessionAlive = SharedStore.isSessionAlive
        state = sessionAlive ? SharedStore.state : .idle
        if state == .recording {
            if recordingStartedAt == nil { recordingStartedAt = Date() }
        } else {
            recordingStartedAt = nil
        }
        statusMessage = SharedStore.statusMessage
        liveText = state == .recording || state == .transcribing ? SharedStore.livePartial : nil
        modes = SharedStore.modes
        selectedModeID = SharedStore.selectedModeID
        let storedBackground = SharedStore.keyboardBackground
        if storedBackground != background { background = storedBackground }
        let storedStandby = SharedStore.micStandby
        if storedStandby != micStandby { micStandby = storedStandby }
    }

    /// The mic is on and waiting, so a tap records right here without opening the app.
    var micIsReady: Bool { sessionAlive && (state == .idle || state == .error) }

    func select(_ mode: DictationMode) {
        selectedModeID = mode.id
        SharedStore.selectedModeID = mode.id
    }

    func micTapped() {
        hint = nil
        unconfirmedStart = nil
        guard hasFullAccess else {
            hint = "Turn on Allow Full Access for Leap Whisper in Settings > General > Keyboard."
            return
        }
        refresh()
        switch state {
        case .recording:
            SharedStore.send(DictationCommand(kind: .stop))
        case .transcribing:
            break
        case .idle, .error:
            if sessionAlive {
                SharedStore.send(DictationCommand(kind: .start, modeID: selectedModeID))
                state = .recording
                openAppIfStartIsMissed()
            } else {
                openAppToStart()
            }
        }
    }

    private func openAppToStart() {
        var components = URLComponents(url: AppGroup.sessionURL(startWithMode: selectedModeID), resolvingAgainstBaseURL: false)!
        components.queryItems?.append(URLQueryItem(name: "source", value: "keyboard"))
        if let host = controller?.hostBundleID {
            components.queryItems?.append(URLQueryItem(name: "host", value: host))
        }
        if controller?.openContainingApp(components.url!) != true {
            hint = "Open the Leap Whisper app once to start a session."
        }
    }

    /// iOS can end the app between two heartbeats, and a Darwin notification can get lost. Ring again twice
    /// (the app ignores a command it has already handled), then open the app instead of leaving the tap unanswered.
    private func openAppIfStartIsMissed() {
        let attempt = UUID()
        unconfirmedStart = attempt
        Task { @MainActor [weak self] in
            for check in 1...3 {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, self.unconfirmedStart == attempt else { return }
                let appState = SharedStore.state
                if appState == .recording || appState == .transcribing { break }
                if check < 3 {
                    DarwinNotifier.shared.post(.command)
                } else {
                    self.openAppToStart()
                }
            }
            if self?.unconfirmedStart == attempt { self?.unconfirmedStart = nil }
        }
    }

    /// Turns the mic (and the orange indicator) off without waiting for the standby window to run out.
    func micOffTapped() {
        unconfirmedStart = nil
        SharedStore.send(DictationCommand(kind: .end))
    }

    func toggleHistory() {
        hint = nil
        guard hasFullAccess else {
            hint = "Turn on Allow Full Access for Leap Whisper to see your history here."
            return
        }
        if !showingHistory { history = SharedStore.recentHistory }
        showingHistory.toggle()
    }

    func insertFromHistory(_ item: RecentDictation) {
        insert(item.text)
        showingHistory = false
    }

    func cancelTapped() {
        unconfirmedStart = nil
        SharedStore.send(DictationCommand(kind: .cancel))
    }

    private func insertLatestTranscript() {
        refresh()
        guard let transcript = SharedStore.transcript,
              AppGroup.defaults.string(forKey: Self.lastInsertedKey) != transcript.id.uuidString,
              Date().timeIntervalSince(transcript.createdAt) < 60
        else { return }
        AppGroup.defaults.set(transcript.id.uuidString, forKey: Self.lastInsertedKey)
        insert(transcript.text)
    }

    private func insert(_ text: String) {
        guard let proxy = controller?.textDocumentProxy else { return }
        proxy.insertText(TranscriptCleaner.spaced(text, after: proxy.documentContextBeforeInput))
    }

    // MARK: Basic keys

    func deleteBackward() { controller?.textDocumentProxy.deleteBackward() }
    func insertSpace() { controller?.textDocumentProxy.insertText(" ") }
    func insertReturn() { controller?.textDocumentProxy.insertText("\n") }
    func nextKeyboard() { controller?.advanceToNextInputMode() }
}
