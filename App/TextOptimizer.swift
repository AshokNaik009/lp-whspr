import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum TextOptimizerError: LocalizedError {
    case appleModelUnavailable
    case rewritingOff
    case noEngine

    var errorDescription: String? {
        switch self {
        case .appleModelUnavailable:
            return "Apple Intelligence isn't available on this device. Choose Groq or Automatic in Settings."
        case .rewritingOff:
            return "rewriting is off in Settings, so your words were inserted as spoken."
        case .noEngine:
            return "add a Groq API key in Settings to rewrite or translate."
        }
    }
}

enum TextOptimizer {
    private static let guardrail = "You receive a raw speech-to-text transcript. Apply the instructions and reply with the rewritten text only — no preamble, no quotes, no explanations."

    static func cleanTranscript(_ text: String) -> String { TranscriptCleaner.clean(text) }

    static func optimize(_ text: String, mode: DictationMode, settings: AppSettings) async throws -> String {
        guard !mode.isVerbatim, !text.isEmpty else { return text }
        let system = "\(guardrail)\n\nInstructions: \(mode.instructions)"

        switch settings.optimizerBackend {
        case .off:
            throw TextOptimizerError.rewritingOff
        case .groq:
            guard let key = settings.groqAPIKey else { throw GroqError.missingAPIKey }
            return try await optimizeWithGroq(text, system: system, key: key, model: settings.groqChatModel)
        case .apple:
            return try await optimizeWithApple(text, system: system)
        case .auto:
            if let key = settings.groqAPIKey {
                return try await optimizeWithGroq(text, system: system, key: key, model: settings.groqChatModel)
            }
            guard isAppleModelAvailable else { throw TextOptimizerError.noEngine }
            return try await optimizeWithApple(text, system: system)
        }
    }

    /// Whether a non-verbatim mode can actually be applied with the current settings.
    static func canRewrite(settings: AppSettings) -> Bool {
        switch settings.optimizerBackend {
        case .off: return false
        case .groq: return settings.groqAPIKey != nil
        case .apple: return isAppleModelAvailable
        case .auto: return settings.groqAPIKey != nil || isAppleModelAvailable
        }
    }

    private static func optimizeWithGroq(_ text: String, system: String, key: String, model: String) async throws -> String {
        let output = try await GroqClient(apiKey: key).complete(system: system, user: text, model: model)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var isAppleModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    private static func optimizeWithApple(_ text: String, system: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAppleModelAvailable {
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(to: text)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw TextOptimizerError.appleModelUnavailable
    }
}
