import SwiftUI

/// One category: its icon in its palette color, its name, and how many transactions it holds.
///
/// The row is a button that renames the category. `Other` can't be renamed, so for it the button
/// does nothing and its hint says why.
struct CategoryRow: View {
    let category: CategoryListItem
    let onRename: @MainActor (CategoryListItem) -> Void

    var body: some View {
        Button(action: rename) {
            Label {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(category.name)
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
            } icon: {
                Image(systemName: category.symbolName)
                    .foregroundStyle(Theme.categoryColor(for: category.colorToken))
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(category.isFallback ? Text("Other can't be renamed.") : Text("Renames the category."))
        .accessibilityIdentifier("categories.row")
    }

    private var detail: LocalizedStringResource {
        category.isFallback
            ? "Fallback · ^[\(category.transactionCount) transaction](inflect: true)"
            : "^[\(category.transactionCount) transaction](inflect: true)"
    }

    private func rename() {
        // Other stays tappable so it can still be dragged, but it is never renamed.
        guard !category.isFallback else { return }
        onRename(category)
    }
}

#Preview {
    List {
        CategoryRow(
            category: CategoryListItem(
                id: UUID(),
                name: "Dining",
                symbolName: "fork.knife",
                colorToken: "coral",
                transactionCount: 3,
                isFallback: false
            ),
            onRename: { _ in }
        )
    }
}
