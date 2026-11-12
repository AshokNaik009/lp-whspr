import Foundation

/// Playful status lines shown while a dictation is being transcribed and rewritten.
public enum BusyPhrases {
    public static let all = [
        "Whispermaxxing…",
        "Cooking your words…",
        "Locking in…",
        "Decoding the vibes…",
        "Polishing your words…",
    ]

    /// Rotates every 1.5 s so the line changes while the user waits.
    public static func phrase(at date: Date) -> String {
        all[Int(date.timeIntervalSinceReferenceDate / 1.5) % all.count]
    }
}
