import SwiftUI
import UIKit

/// SplitSnap's look: vivid violet → pink brand, rounded type, soft cards.
/// Every color has a deliberate dark-mode value rather than a plain inversion.
enum Theme {
    // MARK: Brand

    static let violet = Color(light: 0x6A4CFF, dark: 0x8F7BFF)
    static let pink = Color(light: 0xFF4FA3, dark: 0xFF6FB8)
    static let sunshine = Color(light: 0xFFC233, dark: 0xFFD25C)

    static let brandGradient = LinearGradient(
        colors: [violet, pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Surfaces

    /// Screen background: faint lavender in light mode, deep ink in dark.
    static let background = Color(light: 0xF4F2FF, dark: 0x0D0B17)
    /// Cards sit on the background.
    static let card = Color(light: 0xFFFFFF, dark: 0x1A1730)
    /// Inputs and unselected controls inside cards.
    static let field = Color(light: 0xEEEBFB, dark: 0x282343)
    /// Hairline that separates cards in dark mode, where shadows don't read.
    static let cardStroke = Color(light: 0xFFFFFF, lightAlpha: 0, dark: 0xFFFFFF, darkAlpha: 0.07)
    /// Soft violet-tinted shadow in light mode; none in dark mode.
    static let shadow = Color(light: 0x2B1C80, lightAlpha: 0.09, dark: 0x000000, darkAlpha: 0)

    // MARK: Status

    static let warning = Color(light: 0xF08C00, dark: 0xFFAD4D)
    static let success = Color(light: 0x0FA97A, dark: 0x3DDBA9)

    // MARK: People

    /// Vivid enough for white text in both modes.
    static let personColors: [Color] = [
        Color(light: 0x6A4CFF, dark: 0x8F7BFF), // violet
        Color(light: 0xFF6B3D, dark: 0xFF8257), // tangerine
        Color(light: 0x0FA97A, dark: 0x22C08F), // mint
        Color(light: 0xF0479B, dark: 0xFF62AE), // pink
        Color(light: 0x1E8FFF, dark: 0x4AA6FF), // sky
        Color(light: 0xE09B00, dark: 0xF2B11F), // mustard
        Color(light: 0x0AA9BA, dark: 0x24C3D3), // teal
        Color(light: 0xE5484D, dark: 0xFF6369), // red
        Color(light: 0x3D5AFE, dark: 0x6680FF), // cobalt
        Color(light: 0xA0704A, dark: 0xC08A5E), // mocha
    ]

    // MARK: Shape & type

    static let cornerRadius: CGFloat = 24

    static func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }

    static func font(size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Color helpers

extension Color {
    /// A color that switches between two hex values for light and dark mode.
    init(light: UInt32, lightAlpha: Double = 1, dark: UInt32, darkAlpha: Double = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}
