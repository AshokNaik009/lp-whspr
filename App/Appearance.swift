import SwiftUI
import UIKit

/// App-wide look. Glass is the dark aurora + Liquid Glass theme; the others are a flat ink-on-cream system
/// (warm cream canvas, near-black ink, 1px hairlines, 4px corners, no gradients or glows).
enum AppAppearance: String, CaseIterable, Identifiable {
    case glass, system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: return "Glass"
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var isFlat: Bool { self != .glass }

    var colorScheme: ColorScheme? {
        switch self {
        case .glass, .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

/// Flat theme tokens; each colour resolves for light or dark appearance.
enum FlatPalette {
    static let canvas = dynamic(light: "FDFCFC", dark: "161414")
    static let surfaceCard = dynamic(light: "F1EEEE", dark: "201D1D")
    static let surfaceElevated = dynamic(light: "F8F7F7", dark: "302C2C")
    static let ink = dynamic(light: "201D1D", dark: "FDFCFC")
    static let mute = dynamic(light: "646262", dark: "9A9898")
    static let danger = Color(hex: "FF3B30")
    static let hairline = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.12)
            : UIColor(red: 15 / 255, green: 0, blue: 0, alpha: 0.12)
    })

    private static func dynamic(light: String, dark: String) -> Color {
        let lightColor = UIColor(Color(hex: light))
        let darkColor = UIColor(Color(hex: dark))
        return Color(UIColor { $0.userInterfaceStyle == .dark ? darkColor : lightColor })
    }
}

extension EnvironmentValues {
    @Entry var flatTheme = false
}

private struct ThemedBackground: ViewModifier {
    @Environment(\.flatTheme) private var flat

    func body(content: Content) -> some View {
        if flat {
            content
                .scrollContentBackground(.hidden)
                .background(FlatPalette.canvas.ignoresSafeArea())
        } else {
            content
        }
    }
}

extension View {
    /// Cream/ink canvas behind lists, forms and scroll views in the flat themes.
    func themedBackground() -> some View { modifier(ThemedBackground()) }
}
