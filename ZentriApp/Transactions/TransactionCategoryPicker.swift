import SwiftUI

/// Chooses a transaction's category, or none.
struct TransactionCategoryPicker: View {
    @Binding var categoryID: UUID?
    let categories: [TransactionCategoryOption]

    var body: some View {
        Picker("Category", selection: $categoryID) {
            Text("None").tag(UUID?.none)
            ForEach(categories) { category in
                Label(category.name, systemImage: category.symbolName)
                    .tag(Optional(category.id))
            }
        }
        .accessibilityIdentifier("transactions.categoryPicker")
    }
}
