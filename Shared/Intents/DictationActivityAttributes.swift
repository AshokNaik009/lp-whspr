import ActivityKit
import Foundation

/// The Live Activity that is up while the microphone is on (spec 009, FR-009-4).
struct DictationActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable {
            case recording
            case transcribing
            case ready
        }

        var phase: Phase
        /// When the current recording began; the timer counts up from here.
        var since: Date
    }
}
