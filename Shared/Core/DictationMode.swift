import Foundation

/// An optimization mode applied to the raw transcript. An empty `instructions` string means verbatim output.
struct DictationMode: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var symbol: String
    var instructions: String

    var isVerbatim: Bool { instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Changing the language is harder than tidying text, so these modes get the translation model.
    var isTranslation: Bool { id == "arabic" || instructions.range(of: "translat", options: .caseInsensitive) != nil }

    /// The built-in Arabic mode must come back in Arabic script, unless the user pointed it at another language.
    var expectsArabic: Bool { id == "arabic" && instructions.range(of: "arabic", options: .caseInsensitive) != nil }

    /// Instructions earlier versions shipped for built-in modes. A saved mode that still carries one of them
    /// was never edited by the user, so it can take the current default.
    static let retiredInstructions: [String: [String]] = [
        "arabic": [
            "Translate this dictated text into natural, fluent Modern Standard Arabic. Remove filler words and false starts, keep the meaning, names, numbers and tone. Keep product names such as Leap Whisper in their original form. Reply with the Arabic translation only.",
        ],
    ]

    static func refreshingBuiltIns(_ saved: [DictationMode]) -> [DictationMode] {
        saved.map { mode in
            guard retiredInstructions[mode.id]?.contains(mode.instructions) == true,
                  let current = defaults.first(where: { $0.id == mode.id }) else { return mode }
            var refreshed = mode
            refreshed.instructions = current.instructions
            return refreshed
        }
    }

    static let defaults: [DictationMode] = [
        DictationMode(
            id: "raw", name: "Raw", symbol: "text.quote",
            instructions: ""
        ),
        DictationMode(
            id: "clean", name: "Clean", symbol: "sparkles",
            instructions: "Clean up this dictated text. Remove filler words (um, uh, like, you know), false starts and repetitions. Fix punctuation, capitalization and obvious grammar mistakes. Keep the speaker's wording, meaning and language. Do not add anything."
        ),
        DictationMode(
            id: "message", name: "Message", symbol: "message",
            instructions: "Rewrite this dictated text as a short, friendly chat message. Keep it concise and natural, fix grammar and punctuation, remove filler words. Keep the original language. Do not add greetings or sign-offs that were not dictated."
        ),
        DictationMode(
            id: "email", name: "Email", symbol: "envelope",
            instructions: "Rewrite this dictated text as a clear, professional email body. Use proper paragraphs, fix grammar and punctuation, remove filler words, keep every fact and request. Keep the original language. Do not invent names, dates or details."
        ),
        DictationMode(
            id: "notes", name: "Notes", symbol: "list.bullet",
            instructions: "Turn this dictated text into concise bullet-point notes. One idea per bullet, starting each line with \"- \". Keep all facts, remove filler. Keep the original language."
        ),
        DictationMode(
            id: "prompt", name: "AI Prompt", symbol: "wand.and.stars",
            instructions: "Rewrite this dictated text as a clear, well-structured prompt for an AI assistant. State the goal, relevant context and any constraints explicitly. Keep the original intent and language. Do not answer the prompt."
        ),
        DictationMode(
            id: "arabic", name: "To Arabic", symbol: "translate",
            instructions: "Translate the transcript into natural, fluent Modern Standard Arabic, written the way a native speaker would write it. Translate the meaning rather than word for word: express idioms and figures of speech by what they mean. Use correct Arabic grammar (gender and number agreement, hamza and ta marbuta spelling), Arabic punctuation (، ؛ ؟) and no diacritics. Leave out filler words and false starts, and keep the tone, the facts and the numbers. Write people's names in Arabic script and keep product and brand names such as Leap Whisper in their original form. If the transcript is already in Arabic, only correct it. Reply in Arabic only."
        ),
    ]
}
