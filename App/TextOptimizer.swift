import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum TextOptimizerError: LocalizedError {
    case appleModelUnavailable
    case rewritingOff
    case noEngine
    case appleLanguageUnsupported

    var errorDescription: String? {
        switch self {
        case .appleModelUnavailable:
            return "\(TextOptimizer.appleUnavailableReason ?? "Apple Intelligence isn't available.") Or choose Groq in Settings."
        case .rewritingOff:
            return "rewriting is off in Settings, so your words were inserted as spoken."
        case .noEngine:
            return "\(TextOptimizer.appleUnavailableReason ?? "Apple Intelligence isn't available.") Or add a Groq API key in Settings."
        case .appleLanguageUnsupported:
            return "Apple's on-device model doesn't support Arabic yet. Add a Groq API key in Settings to translate."
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
            return try await optimizeWithApple(text, system: system, mode: mode)
        case .auto:
            if isAppleModelAvailable, appleSupports(mode) {
                return try await optimizeWithApple(text, system: system, mode: mode)
            }
            if let key = settings.groqAPIKey {
                return try await optimizeWithGroq(text, system: system, key: key, model: settings.groqChatModel)
            }
            if isAppleModelAvailable { throw TextOptimizerError.appleLanguageUnsupported }
            throw TextOptimizerError.noEngine
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

    /// Why Apple's on-device model can't be used right now, or nil when it is ready.
    static var appleUnavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Turn on Apple Intelligence in the iPhone's Settings > Apple Intelligence & Siri."
            case .unavailable(.modelNotReady):
                return "Apple Intelligence is still downloading its model. Keep the phone on Wi-Fi and charging, then try again."
            case .unavailable(.deviceNotEligible):
                return "This device doesn't support Apple Intelligence."
            case .unavailable:
                return "Apple Intelligence isn't available right now."
            }
        }
        #endif
        return "Apple Intelligence needs iOS 26 or later."
    }

    /// Apple's model only writes in the languages it supports; the Arabic mode needs Arabic output.
    private static func appleSupports(_ mode: DictationMode) -> Bool {
        guard mode.id == "arabic" else { return true }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.supportedLanguages.contains { $0.languageCode?.identifier == "ar" }
        }
        #endif
        return false
    }

    private static func optimizeWithApple(_ text: String, system: String, mode: DictationMode) async throws -> String {
        guard appleSupports(mode) else { throw TextOptimizerError.appleLanguageUnsupported }
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
