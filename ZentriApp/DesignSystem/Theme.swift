import SwiftUI
import UIKit

/// The app's design tokens: the spacing scale, corner radii, and palette.
///
/// Views never build colors themselves. The brand colors are asset-catalog color sets with light and
/// dark variants; the translucent "Liquid Glass" surface tokens are defined here as dynamic colors,
/// so the warm-neutral canvas, glass cards, ink text, and teal accent are designed for both
/// appearances instead of being inverted. The category tokens match the values `SeedData` stores on
/// the built-in categories.
enum Theme {
    /// The spacing scale used for padding and stack spacing.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// The corner radii used by cards, grouped lists, and the balance hero.
    enum Radius {
        static let card: CGFloat = 24
        static let group: CGFloat = 20
        static let hero: CGFloat = 30
        static let tile: CGFloat = 12
    }

    /// Layout constants shared by the shell's controls.
    enum Layout {
        /// The minimum size of an interactive control, per the Human Interface Guidelines.
        static let minimumTapTarget: CGFloat = 44
    }

    /// The motion curves the design uses. Springs are interruptible and are driven by the display's
    /// own refresh rate, so they run at 120 Hz on ProMotion screens.
    enum Motion {
        /// Cards rising into place, the design's `cubic-bezier(.2,.8,.2,1)`.
        static let rise = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.6)
        /// Bars and progress growing, with a slight overshoot.
        static let grow = Animation.spring(response: 0.7, dampingFraction: 0.72)
        /// Selection changes: chips, bars, toggles.
        static let snap = Animation.spring(response: 0.35, dampingFraction: 0.68)
        /// Rolling digits and long fills, the design's `cubic-bezier(.16,1,.3,1)`.
        static let settle = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 1.0)
    }

    // MARK: Brand colors (asset catalog)

    /// The deep teal accent, applied with `tint` at the app root.
    static let accent = Color("AccentColor")
    /// Text and symbols drawn on an accent fill, such as a prominent button's label.
    static let onAccent = Color("OnAccent")
    /// A disabled prominent button's label, on the system's grey disabled fill: ink in light mode,
    /// secondary ink in dark mode.
    static let onAccentDisabled = Color("OnAccentDisabled")
    /// The warm neutral page background.
    static let canvas = Color("Canvas")
    /// Primary text.
    static let ink = Color("Ink")
    /// Supporting text and labels.
    static let secondaryInk = Color("SecondaryInk")
    /// Money that arrived.
    static let income = Color("Income")
    /// Money that left.
    static let spending = Color("Spending")

    // MARK: Glass surface tokens

    /// The faintest text: axis labels, chevrons, decimals.
    static let tertiaryInk = Color(light: 0xA89F94, dark: 0x6E675F)
    /// A data card's translucent fill.
    static let glass = Color(light: .white.withAlphaComponent(0.55), dark: .white.withAlphaComponent(0.06))
    /// The balance hero's thinner fill, which lets its glow show through.
    static let heroGlass = Color(light: .white.withAlphaComponent(0.38), dark: .white.withAlphaComponent(0.07))
    /// A glass edge.
    static let glassBorder = Color(light: .white.withAlphaComponent(0.85), dark: .white.withAlphaComponent(0.10))
    /// The bright top edge of a glass card, the design's inset highlight.
    static let glassHighlight = Color(light: .white.withAlphaComponent(0.95), dark: .white.withAlphaComponent(0.14))
    /// The light sheen across the top of the hero.
    static let sheen = Color(light: .white.withAlphaComponent(0.6), dark: .white.withAlphaComponent(0.1))
    /// A card's soft drop shadow.
    static let cardShadow = Color(
        light: UIColor(red: 60 / 255, green: 48 / 255, blue: 30 / 255, alpha: 0.13),
        dark: .black.withAlphaComponent(0.45)
    )
    /// Hairlines between rows.
    static let hairline = Color(
        light: UIColor(red: 27 / 255, green: 25 / 255, blue: 23 / 255, alpha: 0.08),
        dark: .white.withAlphaComponent(0.07)
    )
    /// A quiet filled tile, such as the ingestion figures.
    static let fill = Color(
        light: UIColor(red: 118 / 255, green: 110 / 255, blue: 100 / 255, alpha: 0.10),
        dark: .white.withAlphaComponent(0.07)
    )
    /// The empty part of a progress bar or donut.
    static let track = Color(
        light: UIColor(red: 27 / 255, green: 25 / 255, blue: 23 / 255, alpha: 0.07),
        dark: .white.withAlphaComponent(0.08)
    )
    /// A chip's resting fill.
    static let chip = Color(light: .white.withAlphaComponent(0.6), dark: .white.withAlphaComponent(0.08))
    /// The accent at low strength, behind accent text and symbols.
    static let accentSoft = Color(
        light: UIColor(red: 14 / 255, green: 95 / 255, blue: 90 / 255, alpha: 0.12),
        dark: UIColor(red: 95 / 255, green: 208 / 255, blue: 196 / 255, alpha: 0.14)
    )
    /// The spending color at low strength, behind spending text and symbols.
    static let spendingSoft = Color(
        light: UIColor(red: 180 / 255, green: 63 / 255, blue: 44 / 255, alpha: 0.10),
        dark: UIColor(red: 255 / 255, green: 146 / 255, blue: 126 / 255, alpha: 0.12)
    )
    /// The glow under prominent accent buttons.
    static let accentGlow = Color(
        light: UIColor(red: 14 / 255, green: 95 / 255, blue: 90 / 255, alpha: 0.45),
        dark: UIColor(red: 95 / 255, green: 208 / 255, blue: 196 / 255, alpha: 0.35)
    )
    /// The two soft ambient lights behind every screen.
    static let ambientTeal = Color(light: 0x9ED9CF, dark: 0x0F6B66)
    static let ambientPeach = Color(light: 0xF3C9A0, dark: 0x6B4222)

    // MARK: Category palette

    private static let categoryGreen = Color("green")
    private static let categoryCoral = Color("coral")
    private static let categoryTeal = Color("teal")
    private static let categoryViolet = Color("violet")
    private static let categoryAmber = Color("amber")
    private static let categoryCyan = Color("cyan")
    private static let categoryIndigo = Color("indigo")
    private static let categorySlate = Color("slate")

    /// The color for a category's `colorToken`, falling back to slate for an unknown token.
    static func categoryColor(for token: String) -> Color {
        switch token.lowercased() {
        case "green": categoryGreen
        case "coral": categoryCoral
        case "teal": categoryTeal
        case "violet": categoryViolet
        case "amber": categoryAmber
        case "cyan": categoryCyan
        case "indigo": categoryIndigo
        default: categorySlate
        }
    }
}

extension Color {
    /// A color that resolves to one value in light mode and another in dark mode.
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// A color from two opaque hex values, `0xRRGGBB`, for light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(light: UIColor(hex: light), dark: UIColor(hex: dark))
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
