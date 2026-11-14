import SwiftUI

/// The app's design tokens: the spacing scale, corner radii, and asset-catalog palette.
///
/// Views never build colors themselves. Every color below is an asset-catalog color set with
/// light and dark variants, so the warm-neutral canvas, ink text, and teal accent are designed
/// for both appearances instead of being inverted. The category tokens match the values
/// `SeedData` stores on the built-in categories.
enum Theme {
    /// The spacing scale used for padding and stack spacing.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// The corner radii used by cards and the balance hero.
    enum Radius {
        static let card: CGFloat = 20
        static let hero: CGFloat = 28
    }

    /// Layout constants shared by the shell's controls.
    enum Layout {
        /// The minimum size of an interactive control, per the Human Interface Guidelines.
        static let minimumTapTarget: CGFloat = 44
    }

    /// The deep teal accent, applied with `tint` at the app root.
    static let accent = Color("AccentColor")
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
