import SwiftUI

/// The keyword-rules link and the categories, which can be dragged into a new order.
///
/// Tapping a category renames it and swiping deletes it, except `Other`, which only moves.
struct CategoriesList: View {
    let categories: [CategoryListItem]
    let onRename: @MainActor (CategoryListItem) -> Void
    let onDelete: @MainActor (CategoryListItem) -> Void
    let onReorder: @MainActor ([UUID]) -> Void

    var body: some View {
        List {
            Section {
                SettingsLink(destination: .categorizationRules)
            } footer: {
                Text("Keyword rules file a merchant's transactions in a category automatically.")
            }

            Section {
                ForEach(categories) { category in
                    CategoryRow(category: category, onRename: onRename)
                        .swipeActions {
                            // Other is never offered for deletion; the service refuses it too.
                            if !category.isFallback {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    onDelete(category)
                                }
                            }
                        }
                }
                .reorderable()
            } footer: {
                Text("Touch and hold a category to drag it into a new order. Other collects everything no rule matches, so it can't be renamed or deleted.")
            }
        }
        .scrollContentBackground(.hidden)
        .reorderContainer(for: CategoryListItem.self, move: move)
    }

    private func move(_ difference: ReorderDifference<UUID, ReorderableSingleCollectionIdentifier>) {
        var reordered = categories
        difference.apply(to: &reordered)
        onReorder(reordered.map(\.id))
    }
}
