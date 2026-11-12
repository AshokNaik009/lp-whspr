import AVFoundation
import SwiftUI
import UIKit

/// Owns the background dictation session: keeps the mic engine alive, reacts to keyboard commands,
/// transcribes (on-device first, Groq as fallback), applies the optimization mode and hands text back.
@MainActor
final class DictationController: ObservableObject {
    static let shared = DictationController()

    @Published private(set) var state: DictationState = .idle
    @Published private(set) var statusMessage: String?
    @Published private(set) var isSessionActive = false
    @Published private(set) var level: Float = 0
    @Published private(set) var lastTranscript: String = ""
    @Published private(set) var lastSource: String = ""
    @Published var openedFromKeyboard = false
    @Published private(set) var returnedToHost = false
    /// Words recognised so far while recording (live preview).
    @Published private(set) var liveText = ""
    private var liveTask: Task<Void, Never>?

    private let capture = AudioCapture()
    private let settings = AppSettings.shared
    private var currentModeID: String?
    private var lastCommandID: UUID?
    private var lastActivity = Date()
    private var idleTimer: Timer?

    private init() {
        capture.onTick = {
            SharedStore.touchHeartbeat()
            Task { @MainActor in DictationController.shared.checkIdleTimeout() }
        }
        capture.onLevel = { value in
            Task { @MainActor in DictationController.shared.level = value }
        }
        DarwinNotifier.shared.observe(.command) {
            Task { @MainActor in DictationController.shared.handleCommand() }
        }
        DarwinNotifier.shared.observe(.pendingStart) {
            Task { @MainActor in
                if UIApplication.shared.applicationState == .active { DictationController.shared.handlePendingStart() }
            }
        }
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            Task { @MainActor in
                if type == .began { DictationController.shared.endSession(reason: "Session interrupted by another app.") }
            }
        }
        SharedStore.clearHeartbeat()
        SharedStore.publish(state: .idle)
        lastCommandID = SharedStore.command?.id
    }

    // MARK: Entry points

    func handle(url: URL) {
        guard url.scheme == AppGroup.urlScheme, url.host == "session" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let modeID = items.first { $0.name == "mode" }?.value
        let shouldStart = items.first { $0.name == "start" }?.value == "1"
        openedFromKeyboard = items.first { $0.name == "source" }?.value == "keyboard"
        let host = items.first { $0.name == "host" }?.value
        returnedToHost = false
        Task {
            guard await ensureSession() else { return }
            if shouldStart { startRecording(modeID: modeID) }
            if openedFromKeyboard {
                // Give the audio engine a moment to go live before leaving the foreground.
                try? await Task.sleep(for: .milliseconds(400))
                returnedToHost = HostAppReturn.goBack(to: host)
            }
        }
    }

    func handlePendingStart() {
        guard let modeID = SharedStore.pendingStartModeID else { return }
        SharedStore.pendingStartModeID = nil
        Task {
            guard await ensureSession() else { return }
            startRecording(modeID: modeID)
        }
    }

    func toggleRecording() {
        if state == .recording {
            stopRecording()
        } else {
            Task {
                guard await ensureSession() else { return }
                startRecording(modeID: nil)
            }
        }
    }

    // MARK: Session

    @discardableResult
    func ensureSession() async -> Bool {
        if capture.isRunning {
            isSessionActive = true
            return true
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            fail("Microphone access is off. Enable it in Settings > Leap Whisper.")
            return false
        }
        do {
            try capture.startEngine()
            isSessionActive = true
            lastActivity = Date()
            SharedStore.touchHeartbeat()
            SharedStore.publish(state: .idle, message: nil)
            update(state: .idle)
            preloadModel()
            return true
        } catch {
            fail("Couldn't start the microphone: \(error.localizedDescription)")
            return false
        }
    }

    func endSession(reason: String? = nil) {
        if state == .recording { _ = capture.endRecording() }
        capture.stopEngine()
        isSessionActive = false
        level = 0
        SharedStore.clearHeartbeat()
        update(state: .idle, message: reason)
    }

    private func checkIdleTimeout() {
        guard isSessionActive, state == .idle else { return }
        if Date().timeIntervalSince(lastActivity) > Double(settings.sessionTimeoutMinutes * 60) {
            endSession(reason: "Session ended after \(settings.sessionTimeoutMinutes) idle minutes.")
        }
    }

    private func preloadModel() {
        guard settings.transcriptionBackend == .local, let url = ModelManager.shared.selectedModelURL else { return }
        let useGPU = UIApplication.shared.applicationState != .background
        Task.detached(priority: .utility) { try? await WhisperEngine.shared.load(modelAt: url, useGPU: useGPU) }
    }

    // MARK: Recording

    private func handleCommand() {
        guard let command = SharedStore.command, command.id != lastCommandID else { return }
        lastCommandID = command.id
        guard Date().timeIntervalSince(command.issuedAt) < 10 else { return }
        switch command.kind {
        case .start: startRecording(modeID: command.modeID)
        case .stop: stopRecording()
        case .cancel: cancelRecording()
        }
    }

    func startRecording(modeID: String?) {
        guard capture.isRunning, state != .recording, state != .transcribing else { return }
        currentModeID = modeID ?? SharedStore.selectedModeID
        lastActivity = Date()
        capture.beginRecording()
        update(state: .recording)
        startLiveTranscription()
    }

    /// Re-transcribes the last few seconds roughly every second while recording so words appear as you speak.
    private func startLiveTranscription() {
        liveTask?.cancel()
        guard settings.liveTranscription, settings.transcriptionBackend == .local,
              let modelURL = ModelManager.shared.selectedModelURL else { return }
        let language = settings.language
        let prompt = TranscriptionPrompt.build(vocabulary: settings.vocabulary)
        liveTask = Task { [weak self] in
            var lastCount = 0
            while !Task.isCancelled {
                // In the background (keyboard) whisper runs on the CPU, so preview less often over a shorter
                // window to leave the CPU free for the final pass.
                let useGPU = UIApplication.shared.applicationState != .background
                try? await Task.sleep(for: .milliseconds(useGPU ? 800 : 2000))
                guard let self, !Task.isCancelled, self.state == .recording else { return }
                let (samples, truncated) = self.capture.snapshot(lastSeconds: useGPU ? 25 : 10)
                guard samples.count > Int(AudioCapture.sampleRate * 0.8), samples.count != lastCount else { continue }
                lastCount = samples.count
                let result = try? await Task.detached(priority: .userInitiated) { () throws -> WhisperResult in
                    try await WhisperEngine.shared.load(modelAt: modelURL, useGPU: useGPU)
                    return try await WhisperEngine.shared.transcribe(
                        samples: AudioPreprocessor.normalized(samples), language: language, prompt: prompt, fast: true)
                }.value
                guard let result, !Task.isCancelled, self.state == .recording,
                      result.noSpeechProbability < FallbackPolicy.noSpeechCutoff else { continue }
                let text = TextOptimizer.cleanTranscript(result.text)
                guard !text.isEmpty else { continue }
                self.liveText = truncated ? "…" + text : text
                SharedStore.publish(livePartial: self.liveText)
            }
        }
    }

    func stopRecording() {
        guard state == .recording, !isCalibrating else { return }
        let samples = capture.endRecording()
        liveTask?.cancel()
        let mode = SharedStore.mode(withID: currentModeID)
        update(state: .transcribing)
        level = 0
        Task { await process(samples: samples, mode: mode) }
    }

    func cancelRecording() {
        guard state == .recording, !isCalibrating else { return }
        _ = capture.endRecording()
        level = 0
        update(state: .idle)
    }

    private func process(samples: [Float], mode: DictationMode) async {
        defer { lastActivity = Date() }
        guard samples.count > Int(AudioCapture.sampleRate * 0.3) else {
            update(state: .idle, message: "Didn't catch that — hold on a bit longer.")
            return
        }
        let started = Date()
        do {
            let outcome = try await transcribe(samples: AudioPreprocessor.prepare(samples, sampleRate: AudioCapture.sampleRate))
            let cleaned = TextOptimizer.cleanTranscript(outcome.text)
            guard !cleaned.isEmpty else {
                update(state: .idle, message: "No speech detected.")
                return
            }
            var output = cleaned
            var note: String?
            do {
                output = try await TextOptimizer.optimize(cleaned, mode: mode, settings: settings)
                if output.isEmpty { output = cleaned }
            } catch {
                note = "\(mode.name) mode skipped: \(error.localizedDescription)"
            }
            lastTranscript = output
            lastSource = outcome.source
            SharedStore.publish(transcript: TranscriptPayload(text: output, modeID: mode.id))
            HistoryStore.shared.add(DictationRecord(
                rawText: cleaned,
                finalText: output,
                modeID: mode.id,
                modeName: mode.name,
                engine: outcome.source,
                usedCloud: outcome.usedCloud,
                confidence: outcome.confidence.map(Double.init),
                audioSeconds: Double(samples.count) / AudioCapture.sampleRate,
                processingSeconds: Date().timeIntervalSince(started)
            ))
            update(state: .idle, message: note)
        } catch {
            fail(error.localizedDescription)
        }
    }

    private struct TranscriptionOutcome {
        var text: String
        var source: String
        var usedCloud: Bool
        var confidence: Float?
    }

    private func transcribe(samples: [Float]) async throws -> TranscriptionOutcome {
        let language = settings.language
        let prompt = TranscriptionPrompt.build(vocabulary: settings.vocabulary)
        let groqKey = settings.groqAPIKey

        func cloud(_ reason: String, confidence: Float? = nil) async throws -> TranscriptionOutcome {
            guard let groqKey else { throw GroqError.missingAPIKey }
            let text = try await transcribeWithGroq(samples, key: groqKey, language: language, prompt: prompt)
            return TranscriptionOutcome(text: text, source: reason, usedCloud: true, confidence: confidence)
        }

        if settings.transcriptionBackend == .groq {
            return try await cloud("Groq")
        }

        let canFallBack = settings.cloudFallbackEnabled && groqKey != nil
        guard let modelURL = ModelManager.shared.selectedModelURL else {
            if canFallBack { return try await cloud("Groq (no local model)") }
            throw WhisperEngineError.modelLoadFailed("— download one in the Models tab")
        }

        let useGPU = UIApplication.shared.applicationState != .background
        do {
            let result = try await Task.detached(priority: .userInitiated) { () throws -> WhisperResult in
                try await WhisperEngine.shared.load(modelAt: modelURL, useGPU: useGPU)
                return try await WhisperEngine.shared.transcribe(samples: samples, language: language, prompt: prompt)
            }.value

            if FallbackPolicy.shouldUseCloud(confidence: result.confidence, noSpeechProbability: result.noSpeechProbability,
                                             threshold: settings.fallbackConfidenceThreshold, cloudAvailable: canFallBack),
               let outcome = try? await cloud(String(format: "Groq (local confidence %.0f%%)", result.confidence * 100), confidence: result.confidence),
               !outcome.text.isEmpty {
                return outcome
            }
            let source = String(format: "On-device · %@ · %.0f%%", modelURL.deletingPathExtension().lastPathComponent, result.confidence * 100)
            return TranscriptionOutcome(text: result.text, source: source, usedCloud: false, confidence: result.confidence)
        } catch {
            if canFallBack { return try await cloud("Groq (local failed)") }
            throw error
        }
    }

    // MARK: Calibration

    @Published private(set) var isCalibrating = false

    func beginCalibrationCapture() async -> Bool {
        guard state == .idle || state == .error, await ensureSession() else { return false }
        isCalibrating = true
        lastActivity = Date()
        capture.beginRecording()
        update(state: .recording)
        return true
    }

    func endCalibrationCapture() -> [Float] {
        guard isCalibrating else { return [] }
        isCalibrating = false
        level = 0
        let samples = capture.endRecording()
        update(state: .idle)
        return samples
    }

    func transcribeWithGroq(_ samples: [Float], key: String, language: String, prompt: String?) async throws -> String {
        let wav = WAVEncoder.encode(samples: samples, sampleRate: Int(AudioCapture.sampleRate))
        return try await GroqClient(apiKey: key).transcribe(wav: wav, model: settings.groqTranscriptionModel, language: language, prompt: prompt)
    }

    // MARK: State

    private func update(state newState: DictationState, message: String? = nil) {
        if newState != .recording && newState != .transcribing {
            liveTask?.cancel()
            liveText = ""
            SharedStore.publish(livePartial: nil)
        }
        state = newState
        statusMessage = message
        SharedStore.publish(state: newState, message: message)
    }

    private func fail(_ message: String) {
        update(state: .error, message: message)
    }
}
