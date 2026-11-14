import SwiftUI

/// A category's symbol and name, tinted with the category's palette color.
///
/// The symbol carries the color while the name stays in ink, so the category is still identifiable
/// without color vision: color is never the only encoding.
struct CategoryBadge: View {
    private let name: String
    private let symbolName: String
    private let colorToken: String

    init(name: String, symbolName: String, colorToken: String) {
        self.name = name
        self.symbolName = symbolName
        self.colorToken = colorToken
    }

    private var color: Color {
        Theme.categoryColor(for: colorToken)
    }

    var body: some View {
        Label {
            Text(name)
                .foregroundStyle(Theme.ink)
        } icon: {
            Image(systemName: symbolName)
                .foregroundStyle(color)
        }
        .font(.subheadline)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(color.opacity(0.14), in: .capsule)
        .overlay { Capsule().strokeBorder(color.opacity(0.3)) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(name))
    }
}

#Preview {
    HStack {
        CategoryBadge(name: "Dining", symbolName: "fork.knife", colorToken: "coral")
        CategoryBadge(name: "Transport", symbolName: "car", colorToken: "teal")
    }
    .padding()
    .background(Theme.canvas)
}
