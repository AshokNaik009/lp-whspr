import Foundation

/// Builds Whisper's initial prompt. Whisper copies the spelling and punctuation style of its prompt,
/// so listing product names and jargon fixes mishearings like "Lee Bisper" for "Leap Whisper".
public enum TranscriptionPrompt {
    public static let builtInTerms = ["Leap Whisper", "Wispr Flow", "Groq", "Whisper", "TestFlight", "Xcode", "Swift", "iPhone", "iPad"]

    /// `vocabulary` is the user's comma- or newline-separated list from Settings.
    public static func build(vocabulary: String) -> String {
        let custom = vocabulary
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        let terms = (custom + builtInTerms).filter { seen.insert($0.lowercased()).inserted }
        return "Dictation with clear punctuation. Vocabulary: \(terms.joined(separator: ", "))."
    }
}
