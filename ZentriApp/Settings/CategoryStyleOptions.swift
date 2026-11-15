import Foundation

/// The icons and colors a new category can be given.
///
/// The colors are the eight palette tokens the asset catalog defines, so every category stays inside
/// the accessible palette; the icons include every seeded category's symbol.
enum CategoryStyleOptions {
    /// The SF Symbols offered for a category.
    static let symbolNames = [
        "tag", "cart", "fork.knife", "cup.and.saucer", "car", "bus", "airplane", "bag", "tshirt", "gift",
        "house", "bolt", "phone", "wifi", "heart", "cross.case", "dumbbell", "film", "gamecontroller",
        "book", "graduationcap", "pawprint", "leaf", "wrench.and.screwdriver", "banknote", "creditcard",
        "arrow.up.right", "arrow.left.arrow.right", "ellipsis",
    ]

    /// The palette tokens offered for a category, in the order the picker shows them.
    static let colorTokens = ["green", "coral", "teal", "violet", "amber", "cyan", "indigo", "slate"]

    /// The name a person hears and reads for a palette token.
    static func colorName(for token: String) -> LocalizedStringResource {
        switch token {
        case "green": "Green"
        case "coral": "Coral"
        case "teal": "Teal"
        case "violet": "Violet"
        case "amber": "Amber"
        case "cyan": "Cyan"
        case "indigo": "Indigo"
        default: "Slate"
        }
    }
}
