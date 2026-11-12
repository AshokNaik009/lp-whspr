import SwiftUI
import UIKit

/// The Leap Whisper keyboard's background: the system default, a preset gradient or a custom two-colour gradient.
struct KeyboardBackground: Codable, Equatable {
    var presetID: String
    var startHex: String
    var endHex: String

    static let systemID = "system"
    static let customID = "custom"
    static let system = KeyboardBackground(presetID: systemID, startHex: "", endHex: "")

    struct Preset: Identifiable {
        let id: String
        let name: String
        let startHex: String
        let endHex: String
        var background: KeyboardBackground { KeyboardBackground(presetID: id, startHex: startHex, endHex: endHex) }
    }

    static let presets = [
        Preset(id: "aurora", name: "Aurora", startHex: "6D5BFF", endHex: "2FA8FF"),
        Preset(id: "sunset", name: "Sunset", startHex: "FF5E7E", endHex: "FF9A4D"),
        Preset(id: "ocean", name: "Ocean", startHex: "0EA5E9", endHex: "14B8A6"),
        Preset(id: "forest", name: "Forest", startHex: "16A34A", endHex: "0F766E"),
        Preset(id: "rose", name: "Rose", startHex: "F472B6", endHex: "A855F7"),
        Preset(id: "midnight", name: "Midnight", startHex: "312E81", endHex: "0F172A"),
    ]

    var gradient: LinearGradient? {
        guard presetID != Self.systemID else { return nil }
        return LinearGradient(colors: [Color(hex: startHex), Color(hex: endHex)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")), radix: 16) ?? 0x6D5BFF
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let clamp = { (v: CGFloat) in Int((min(1, max(0, v)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }
}
