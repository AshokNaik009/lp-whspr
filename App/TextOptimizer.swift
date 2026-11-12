import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum TextOptimizerError: LocalizedError {
    case appleModelUnavailable

    var errorDescription: String? {
        "Apple Intelligence isn't available on this device. Choose Groq or turn optimization off in Settings."
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
            return text
        case .groq:
            guard let key = settings.groqAPIKey else { throw GroqError.missingAPIKey }
            let output = try await GroqClient(apiKey: key).complete(system: system, user: text, model: settings.groqChatModel)
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        case .apple:
            return try await optimizeWithApple(text, system: system)
        }
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
