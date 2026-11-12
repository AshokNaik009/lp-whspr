import Foundation

enum TranscriptCleaner {
    /// Removes whisper annotations such as `[BLANK_AUDIO]` or `(music)` and collapses whitespace.
    static func clean(_ text: String) -> String {
        var result = text.replacingOccurrences(of: #"\[[^\]]*\]|\([^)]*(music|silence|blank|inaudible)[^)]*\)"#, with: "", options: [.regularExpression, .caseInsensitive])
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Text to insert after `before` so words don't run together (spec 001, FR-001-5).
    static func spaced(_ text: String, after before: String?) -> String {
        guard let last = before?.last, !last.isWhitespace,
              let first = text.first, !first.isPunctuation, !first.isWhitespace else { return text }
        return " " + text
    }
}
