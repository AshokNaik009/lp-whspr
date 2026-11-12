import SwiftUI
import UIKit

/// Plus Jakarta Sans (SIL OFL, bundled in Shared/Fonts) is the typeface for the app and keyboard.
enum JakartaFont: String {
    case regular = "PlusJakartaSans-Regular"
    case medium = "PlusJakartaSans-Medium"
    case semibold = "PlusJakartaSans-SemiBold"
    case bold = "PlusJakartaSans-Bold"
    case extraBold = "PlusJakartaSans-ExtraBold"

    init(_ weight: Font.Weight) {
        switch weight {
        case .black, .heavy: self = .extraBold
        case .bold: self = .bold
        case .semibold: self = .semibold
        case .medium: self = .medium
        default: self = .regular
        }
    }

    static func size(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline, .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }
}

extension Font {
    /// A Dynamic Type–scaled Plus Jakarta Sans font for a system text style.
    static func jakarta(_ style: Font.TextStyle, _ weight: Font.Weight? = nil) -> Font {
        let resolved = weight ?? (style == .headline ? .semibold : .regular)
        return .custom(JakartaFont(resolved).rawValue, size: JakartaFont.size(for: style), relativeTo: style)
    }

    static func jakarta(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(JakartaFont(weight).rawValue, fixedSize: size)
    }
}

extension UIFont {
    static func jakarta(size: CGFloat, _ font: JakartaFont = .regular) -> UIFont {
        UIFont(name: font.rawValue, size: size) ?? .systemFont(ofSize: size)
    }
}
