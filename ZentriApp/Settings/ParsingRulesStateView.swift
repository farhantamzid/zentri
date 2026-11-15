import SwiftUI

/// Chooses what the rule list shows: nothing yet, the failure, the empty state, or the rules.
struct ParsingRulesStateView: View {
    let model: ParsingRulesModel
    let isReprocessing: Bool
    let onAdd: @MainActor () -> Void
    let onEdit: @MainActor (ParsingRuleListItem) -> Void
    let onToggle: @MainActor (ParsingRuleListItem) -> Void
    let onDelete: @MainActor (ParsingRuleListItem) -> Void
    let onReprocessFailures: @MainActor () -> Void

    var body: some View {
        switch model.loadState {
        case .loading:
            Color.clear
        case .failed:
            SettingsFailureState(title: "Can't show your rules", onRetry: model.refresh)
        case .loaded:
            if model.sections.isEmpty {
                ContentUnavailableView {
                    Label("No parsing rules", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("A rule is a pattern that reads one bank's messages into transactions for an account.")
                } actions: {
                    Button("Add Rule", action: onAdd)
                        .prominentButtonStyle()
                        .controlSize(.large)
                        .frame(minHeight: Theme.Layout.minimumTapTarget)
                        .disabled(model.defaultAccountID == nil)
                }
            } else {
                ParsingRulesList(
                    model: model,
                    isReprocessing: isReprocessing,
                    onEdit: onEdit,
                    onToggle: onToggle,
                    onDelete: onDelete,
                    onReprocessFailures: onReprocessFailures
                )
            }
        }
    }
}
