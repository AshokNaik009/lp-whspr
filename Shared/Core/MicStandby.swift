import Foundation

/// How long the microphone stays on after a dictation so the next keyboard tap records without opening the app
/// (spec 001, FR-001-8). iOS only lets an app start the microphone from the foreground, so `off` means every
/// keyboard dictation opens Leap Whisper first.
enum MicStandby: Int, CaseIterable, Identifiable, Codable {
    case off = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case oneHour = 60
    case always = -1

    static let `default` = MicStandby.fifteenMinutes

    init(stored: Int?) {
        self = stored.flatMap(MicStandby.init(rawValue:)) ?? .default
    }

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .oneHour: return "1 hour"
        case .always: return "Until I turn it off"
        }
    }

    /// Reads naturally after "The mic stays ready …".
    var phrase: String {
        switch self {
        case .off: return "only while you dictate"
        case .fiveMinutes: return "for 5 minutes after each dictation"
        case .fifteenMinutes: return "for 15 minutes after each dictation"
        case .oneHour: return "for an hour after each dictation"
        case .always: return "until you turn it off"
        }
    }

    var keepsMicAfterDictation: Bool { self != .off }

    /// Whether a session that has been idle for `idleSeconds` should give the microphone up.
    func hasExpired(idleSeconds: TimeInterval) -> Bool {
        switch self {
        case .off: return true
        case .always: return false
        default: return idleSeconds >= TimeInterval(rawValue * 60)
        }
    }
}
