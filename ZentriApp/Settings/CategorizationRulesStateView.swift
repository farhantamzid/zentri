import SwiftUI

/// Chooses what Keyword Rules shows: nothing yet, the failure, the empty state, or the list.
struct CategorizationRulesStateView: View {
    let model: CategorizationRulesModel
    let onAdd: @MainActor () -> Void
    let onEdit: @MainActor (CategorizationRuleListItem) -> Void
    let onToggle: @MainActor (CategorizationRuleListItem) -> Void
    let onDelete: @MainActor (CategorizationRuleListItem) -> Void

    var body: some View {
        switch model.loadState {
        case .loading:
            Color.clear
        case .failed:
            SettingsFailureState(title: "Can't show your keyword rules", onRetry: model.refresh)
        case .loaded:
            if model.rules.isEmpty {
                ContentUnavailableView {
                    Label("No keyword rules", systemImage: "text.magnifyingglass")
                } description: {
                    Text("A rule files every transaction whose merchant contains its keyword in one category.")
                } actions: {
                    Button("Add Rule", action: onAdd)
                        .prominentButtonStyle()
                        .controlSize(.large)
                        .frame(minHeight: Theme.Layout.minimumTapTarget)
                        .disabled(model.categories.isEmpty)
                }
            } else {
                List {
                    Section {
                        ForEach(model.rules) { rule in
                            CategorizationRuleRow(rule: rule, onEdit: onEdit)
                                .swipeActions(edge: .leading) {
                                    Button(
                                        rule.isEnabled ? "Turn Off" : "Turn On",
                                        systemImage: rule.isEnabled ? "pause.circle" : "play.circle"
                                    ) {
                                        onToggle(rule)
                                    }
                                    .tint(Theme.accent)
                                }
                                .swipeActions {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        onDelete(rule)
                                    }
                                }
                        }
                    } footer: {
                        Text("Rules are tried from the lowest priority number up; the first enabled rule whose keyword the merchant contains wins. Matching ignores case.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}
