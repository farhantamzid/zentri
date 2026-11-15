import SwiftUI

/// Chooses what Categories shows: nothing yet, the failure, the empty state, or the list.
struct CategoriesStateView: View {
    let model: CategoriesModel
    let onRename: @MainActor (CategoryListItem) -> Void
    let onDelete: @MainActor (CategoryListItem) -> Void
    let onReorder: @MainActor ([UUID]) -> Void

    var body: some View {
        switch model.loadState {
        case .loading:
            Color.clear
        case .failed:
            SettingsFailureState(title: "Can't show your categories", onRetry: model.refresh)
        case .loaded:
            if model.categories.isEmpty {
                ContentUnavailableView(
                    "No categories",
                    systemImage: "square.grid.2x2",
                    description: Text("Add a category to sort your spending.")
                )
            } else {
                CategoriesList(
                    categories: model.categories,
                    onRename: onRename,
                    onDelete: onDelete,
                    onReorder: onReorder
                )
            }
        }
    }
}
