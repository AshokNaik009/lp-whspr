import Foundation

/// An optimization mode applied to the raw transcript. An empty `instructions` string means verbatim output.
struct DictationMode: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var symbol: String
    var instructions: String

    var isVerbatim: Bool { instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
            instructions: "Translate this dictated text into natural, fluent Modern Standard Arabic. Remove filler words and false starts, keep the meaning, names, numbers and tone. Keep product names such as Leap Whisper in their original form. Reply with the Arabic translation only."
        ),
    ]
}
