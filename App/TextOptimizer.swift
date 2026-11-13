import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum TextOptimizerError: LocalizedError {
    case appleModelUnavailable
    case rewritingOff
    case noEngine
    case appleLanguageUnsupported
    case notTranslated

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
        case .notTranslated:
            return "the translation didn't come back in Arabic, so your words were inserted as spoken."
        }
    }
}

enum TextOptimizer {
    static func cleanTranscript(_ text: String) -> String { TranscriptCleaner.clean(text) }

    static func optimize(_ text: String, mode: DictationMode, settings: AppSettings) async throws -> String {
        guard !mode.isVerbatim, !text.isEmpty else { return text }
        let system = RewritePrompt.system(instructions: mode.instructions)

        switch settings.optimizerBackend {
        case .off:
            throw TextOptimizerError.rewritingOff
        case .groq:
            guard let key = settings.groqAPIKey else { throw GroqError.missingAPIKey }
            return try await optimizeWithGroq(text, system: system, key: key, mode: mode, settings: settings)
        case .apple:
            return try await optimizeWithApple(text, system: system, mode: mode)
        case .auto:
            if isAppleModelAvailable, appleSupports(mode) {
                return try await optimizeWithApple(text, system: system, mode: mode)
            }
            if let key = settings.groqAPIKey {
                return try await optimizeWithGroq(text, system: system, key: key, mode: mode, settings: settings)
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

    /// Translation modes try the translation model first and fall back to the rewrite model, so a preview model
    /// that is rate-limited, withdrawn or answers in the wrong language doesn't cost the user the translation.
    private static func optimizeWithGroq(_ text: String, system: String, key: String, mode: DictationMode, settings: AppSettings) async throws -> String {
        var models = [settings.groqChatModel]
        if mode.isTranslation, !settings.groqTranslationModel.isEmpty, settings.groqTranslationModel != settings.groqChatModel {
            models.insert(settings.groqTranslationModel, at: 0)
        }
        var failure: Error = TextOptimizerError.noEngine
        for model in models {
            do {
                let reply = try await GroqClient(apiKey: key).complete(system: system, user: RewritePrompt.user(transcript: text), model: model)
                let output = RewritePrompt.cleaned(reply)
                if mode.expectsArabic, !RewritePrompt.isArabic(output) {
                    failure = TextOptimizerError.notTranslated
                    continue
                }
                return output
            } catch {
                failure = error
            }
        }
        throw failure
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
            let response = try await session.respond(to: RewritePrompt.user(transcript: text))
            return RewritePrompt.cleaned(response.content)
        }
        #endif
        throw TextOptimizerError.appleModelUnavailable
    }
}
