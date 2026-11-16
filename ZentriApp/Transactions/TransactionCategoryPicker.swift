import SwiftUI

/// Chooses a transaction's category from a wrapping group of chips; the chosen one takes its
/// category's color. Tapping the chosen chip again clears the category.
struct TransactionCategoryPicker: View {
    @Binding var categoryID: UUID?
    let categories: [TransactionCategoryOption]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        FlowLayout(spacing: Theme.Spacing.sm) {
            ForEach(categories) { category in
                let isOn = categoryID == category.id
                let color = Theme.categoryColor(for: category.colorToken)
                Button {
                    withAnimation(Theme.Motion.snap) {
                        categoryID = isOn ? nil : category.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: category.symbolName)
                            .symbolVariant(.fill)
                            .font(.footnote)
                            .foregroundStyle(color)
                        Text(verbatim: category.name)
                            .foregroundStyle(Theme.ink)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        isOn ? AnyShapeStyle(color.opacity(colorScheme == .dark ? 0.17 : 0.12)) : AnyShapeStyle(Theme.glass),
                        in: .capsule
                    )
                    .overlay { Capsule().strokeBorder(isOn ? color : Theme.glassBorder) }
                    .scaleEffect(isOn ? 1.04 : 1)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: category.name))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: categoryID)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Category"))
        .accessibilityIdentifier("transactions.categoryPicker")
    }
}
