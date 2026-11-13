import Foundation

/// What the keyboard does with a dictation it wasn't on screen to insert (spec 009, FR-009-7).
enum TranscriptDelivery {
    /// How long a missed dictation is offered as an Insert chip.
    static let offerWindow: TimeInterval = 600

    static func isOffered(createdAt: Date, alreadyInserted: Bool, now: Date = Date()) -> Bool {
        !alreadyInserted && now.timeIntervalSince(createdAt) < offerWindow
    }
}

/// The on-device record of how each "Dictate" press was started (spec 009, FR-009-8).
enum StartLog {
    static let limit = 20

    static func appending(_ entry: String, to entries: [String]) -> [String] {
        Array((entries + [entry]).suffix(limit))
    }

    /// Audio errors are four-character codes packed into an integer; '!rec' says more than 561145187.
    static func fourCharacterCode(_ code: Int) -> String? {
        guard let value = UInt32(exactly: code) else { return nil }
        let bytes = [24, 16, 8, 0].map { UInt8((value >> $0) & 0xFF) }
        guard bytes.allSatisfy({ (0x20...0x7E).contains($0) }) else { return nil }
        return String(decoding: bytes, as: UTF8.self)
    }

    static func describe(_ error: NSError) -> String {
        let code = fourCharacterCode(error.code).map { "'\($0)' " } ?? ""
        return "\(code)\(error.domain) \(error.code)"
    }
}
