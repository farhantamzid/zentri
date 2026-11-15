import SwiftUI

/// Chooses what Accounts shows: nothing yet, the failure, the empty state, or the list.
///
/// The blank loading branch is on screen for one frame at most; it has to exist so the view appears
/// and its first read runs.
struct AccountsStateView: View {
    let model: AccountsModel
    let onAdd: @MainActor () -> Void

    var body: some View {
        switch model.loadState {
        case .loading:
            Color.clear
        case .failed:
            SettingsFailureState(title: "Can't show your accounts", onRetry: model.refresh)
        case .loaded:
            if model.hasAccounts {
                AccountsList(active: model.activeAccounts, archived: model.archivedAccounts)
            } else {
                ContentUnavailableView {
                    Label("No accounts", systemImage: "building.columns")
                } description: {
                    Text("Add the bank account Zentri should watch, with the balance it has today.")
                } actions: {
                    Button("Add Account", action: onAdd)
                        .prominentButtonStyle()
                        .controlSize(.large)
                        .frame(minHeight: Theme.Layout.minimumTapTarget)
                }
            }
        }
    }
}
