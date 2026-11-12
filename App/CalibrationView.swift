import SwiftUI

struct CalibrationResult: Identifiable {
    enum Engine: Hashable {
        case local(file: String)
        case groq
    }

    let engine: Engine
    let title: String
    var text = ""
    var seconds: Double = 0
    var confidence: Float?
    var wordErrorRate: Double?
    var error: String?

    var id: Engine { engine }
    var accuracy: Double? { wordErrorRate.map { max(0, 1 - $0) } }
}

@MainActor
final class CalibrationRunner: ObservableObject {
    static let referenceSentence = "Leap Whisper turns my voice into clean text. Please schedule the meeting for Tuesday at three thirty and send the notes to the team."

    enum Phase: Equatable { case ready, recording, running(String), done }

    @Published var phase: Phase = .ready
    @Published var results: [CalibrationResult] = []
    @Published var message: String?
    @Published var includeGroq = true

    private var samples: [Float] = []

    func startRecording() async {
        message = nil
        results = []
        if await DictationController.shared.beginCalibrationCapture() {
            phase = .recording
        } else {
            message = "Couldn't start the microphone. Check microphone permission in Settings."
        }
    }

    func stopAndEvaluate() async {
        samples = DictationController.shared.endCalibrationCapture()
        guard samples.count > Int(AudioCapture.sampleRate) else {
            phase = .ready
            message = "Recording too short — read the whole sentence."
            return
        }
        await evaluate()
    }

    private func evaluate() async {
        let settings = AppSettings.shared
        let models = ModelManager.shared
        let language = settings.language
        let reference = Self.referenceSentence
        let audio = samples
        var pending: [CalibrationResult] = models.installed.map { file in
            CalibrationResult(engine: .local(file: file), title: WhisperModelInfo.catalog.first { $0.file == file }?.title ?? file)
        }
        if includeGroq, settings.groqAPIKey != nil {
            pending.append(CalibrationResult(engine: .groq, title: "Groq · \(settings.groqTranscriptionModel)"))
        }
        results = pending

        for index in results.indices {
            phase = .running(results[index].title)
            let started = Date()
            do {
                switch results[index].engine {
                case .local(let file):
                    let url = models.url(for: file)
                    let result = try await Task.detached(priority: .userInitiated) { () throws -> WhisperResult in
                        try await WhisperEngine.shared.load(modelAt: url, useGPU: true)
                        return try await WhisperEngine.shared.transcribe(samples: audio, language: language, prompt: nil)
                    }.value
                    results[index].text = result.text
                    results[index].confidence = result.confidence
                case .groq:
                    guard let key = settings.groqAPIKey else { continue }
                    results[index].text = try await DictationController.shared.transcribeWithGroq(audio, key: key, language: language, prompt: nil)
                }
                results[index].seconds = Date().timeIntervalSince(started)
                results[index].wordErrorRate = WordErrorRate.compute(reference: reference, hypothesis: results[index].text)
            } catch {
                results[index].error = error.localizedDescription
            }
        }
        phase = .done
    }

    /// Best result: highest accuracy, ties broken by speed.
    var recommended: CalibrationResult? {
        results.filter { $0.error == nil && $0.accuracy != nil }.max {
            let a = $0.accuracy ?? 0, b = $1.accuracy ?? 0
            return abs(a - b) < 0.02 ? $0.seconds > $1.seconds : a < b
        }
    }

    /// Lowest local confidence among results that were still accurate, used to suggest a fallback threshold.
    var suggestedThreshold: Double? {
        FallbackPolicy.suggestedThreshold(results: results.compactMap { r in
            guard let accuracy = r.accuracy, let confidence = r.confidence else { return nil }
            return (accuracy, confidence)
        })
    }

    func apply(_ result: CalibrationResult) {
        let settings = AppSettings.shared
        switch result.engine {
        case .local(let file):
            settings.transcriptionBackend = .local
            settings.selectedModelFile = file
        case .groq:
            settings.transcriptionBackend = .groq
        }
    }
}

struct CalibrationView: View {
    @EnvironmentObject private var controller: DictationController
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var models: ModelManager
    @StateObject private var runner = CalibrationRunner()

    var body: some View {
        List {
            Section {
                Text("Read this sentence aloud at your normal pace. Every installed model (and Groq, if enabled) transcribes the same recording so you can compare accuracy and speed on this device.")
                    .font(.jakarta(.footnote)).foregroundStyle(.secondary)
                Text("“\(CalibrationRunner.referenceSentence)”")
                    .font(.jakarta(.title3))
                    .padding(.vertical, 4)
                if settings.groqAPIKey != nil {
                    Toggle("Include Groq (online)", isOn: $runner.includeGroq)
                }
                recordButton
                if let message = runner.message {
                    Text(message).font(.jakarta(.footnote)).foregroundStyle(.red)
                }
            }

            if models.installed.isEmpty {
                Section { Text("No local models installed. Download at least one in the Models tab to compare on-device accuracy.").font(.jakarta(.footnote)) }
            }

            if !runner.results.isEmpty {
                Section("Results") {
                    ForEach(runner.results) { result in
                        CalibrationRow(result: result,
                                       isRecommended: runner.phase == .done && runner.recommended?.id == result.id,
                                       isCurrent: isCurrent(result)) {
                            runner.apply(result)
                        }
                    }
                }
            }

            if runner.phase == .done, let threshold = runner.suggestedThreshold {
                Section {
                    LabeledContent("Suggested threshold", value: threshold.formatted(.percent.precision(.fractionLength(0))))
                    Button("Use for Groq fallback") { settings.fallbackConfidenceThreshold = threshold }
                } header: {
                    Text("Fallback confidence")
                } footer: {
                    Text("Based on the lowest confidence among accurate local results. Dictations scoring below this are re-sent to Groq.")
                }
            }
        }
        .themedBackground()
            .navigationTitle("Calibration")
        .onDisappear {
            if runner.phase == .recording { _ = controller.endCalibrationCapture() }
        }
    }

    @ViewBuilder private var recordButton: some View {
        switch runner.phase {
        case .ready, .done:
            Button { Task { await runner.startRecording() } } label: {
                Label(runner.phase == .done ? "Record again" : "Start recording", systemImage: "mic.fill")
            }
        case .recording:
            Button { Task { await runner.stopAndEvaluate() } } label: {
                HStack {
                    Label("Stop and compare", systemImage: "stop.fill").foregroundStyle(.red)
                    Spacer()
                    ProgressView(value: Double(min(1, controller.level * 4))).frame(width: 80)
                }
            }
        case .running(let title):
            HStack { ProgressView(); Text("Testing \(title)…").foregroundStyle(.secondary) }
        }
    }

    private func isCurrent(_ result: CalibrationResult) -> Bool {
        switch result.engine {
        case .local(let file): settings.transcriptionBackend == .local && settings.selectedModelFile == file
        case .groq: settings.transcriptionBackend == .groq
        }
    }
}

private struct CalibrationRow: View {
    let result: CalibrationResult
    let isRecommended: Bool
    let isCurrent: Bool
    let apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(result.title).font(.jakarta(.headline))
                if isRecommended {
                    Text("Recommended").font(.jakarta(.caption2, .bold)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.green.opacity(0.2), in: Capsule()).foregroundStyle(.green)
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                } else if result.accuracy != nil {
                    Button("Use", action: apply).buttonStyle(.bordered).controlSize(.small)
                }
            }
            if let error = result.error {
                Text(error).font(.jakarta(.caption)).foregroundStyle(.red)
            } else if let accuracy = result.accuracy {
                HStack(spacing: 12) {
                    Label(accuracy.formatted(.percent.precision(.fractionLength(0))), systemImage: "checkmark.seal")
                    Label(String(format: "%.1f s", result.seconds), systemImage: "timer")
                    if let confidence = result.confidence {
                        Label(Double(confidence).formatted(.percent.precision(.fractionLength(0))), systemImage: "gauge.medium")
                    }
                }
                .font(.jakarta(.caption)).foregroundStyle(.secondary)
                Text(result.text).font(.jakarta(.footnote))
            } else {
                Text("Waiting…").font(.jakarta(.caption)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
