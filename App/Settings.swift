import Foundation

enum TranscriptionBackend: String, CaseIterable, Identifiable, Codable {
    case local
    case groq

    var id: String { rawValue }
    var title: String { self == .local ? "On-device (whisper.cpp)" : "Groq Cloud" }
}

enum OptimizerBackend: String, CaseIterable, Identifiable, Codable {
    case auto
    case off
    case apple
    case groq

    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: return "Automatic (Apple on-device, else Groq)"
        case .off: return "Off (verbatim)"
        case .apple: return "Apple Intelligence (on-device)"
        case .groq: return "Groq LLM"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = AppGroup.defaults

    @Published var transcriptionBackend: TranscriptionBackend { didSet { save(transcriptionBackend.rawValue, "transcriptionBackend") } }
    @Published var optimizerBackend: OptimizerBackend { didSet { save(optimizerBackend.rawValue, "optimizerBackend") } }
    @Published var selectedModelFile: String? { didSet { save(selectedModelFile, "selectedModelFile") } }
    @Published var language: String { didSet { save(language, "language") } }
    @Published var vocabulary: String { didSet { save(vocabulary, "vocabulary") } }
    @Published var groqTranscriptionModel: String { didSet { save(groqTranscriptionModel, "groqTranscriptionModel") } }
    @Published var groqChatModel: String { didSet { save(groqChatModel, "groqChatModel") } }
    @Published var sessionTimeoutMinutes: Int { didSet { save(sessionTimeoutMinutes, "sessionTimeoutMinutes") } }
    /// Re-transcribe with Groq when the on-device result is missing or below `fallbackConfidenceThreshold`.
    @Published var cloudFallbackEnabled: Bool { didSet { save(cloudFallbackEnabled, "cloudFallbackEnabled") } }
    /// Show words while speaking (fast on-device passes); the final text still comes from a full pass on stop.
    @Published var liveTranscription: Bool { didSet { save(liveTranscription, "liveTranscription") } }
    @Published var fallbackConfidenceThreshold: Double { didSet { save(fallbackConfidenceThreshold, "fallbackConfidenceThreshold") } }
    @Published var appearance: AppAppearance { didSet { save(appearance.rawValue, "appearance") } }

    private init() {
        let d = AppGroup.defaults
        transcriptionBackend = d.string(forKey: "transcriptionBackend").flatMap(TranscriptionBackend.init(rawValue:)) ?? .local
        optimizerBackend = d.string(forKey: "optimizerBackend").flatMap(OptimizerBackend.init(rawValue:)) ?? .auto
        selectedModelFile = d.string(forKey: "selectedModelFile")
        language = d.string(forKey: "language") ?? "auto"
        vocabulary = d.string(forKey: "vocabulary") ?? ""
        groqTranscriptionModel = d.string(forKey: "groqTranscriptionModel") ?? "whisper-large-v3-turbo"
        groqChatModel = d.string(forKey: "groqChatModel") ?? "openai/gpt-oss-20b"
        let timeout = d.integer(forKey: "sessionTimeoutMinutes")
        sessionTimeoutMinutes = timeout > 0 ? timeout : 30
        cloudFallbackEnabled = d.object(forKey: "cloudFallbackEnabled") as? Bool ?? true
        liveTranscription = d.object(forKey: "liveTranscription") as? Bool ?? true
        let threshold = d.double(forKey: "fallbackConfidenceThreshold")
        fallbackConfidenceThreshold = threshold > 0 ? threshold : 0.55
        appearance = d.string(forKey: "appearance").flatMap(AppAppearance.init(rawValue:)) ?? .glass
    }

    var groqAPIKey: String? {
        get { Keychain.read("groqAPIKey") }
        set {
            if let newValue, !newValue.isEmpty { Keychain.write("groqAPIKey", value: newValue) } else { Keychain.delete("groqAPIKey") }
            objectWillChange.send()
        }
    }

    private func save(_ value: Any?, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
