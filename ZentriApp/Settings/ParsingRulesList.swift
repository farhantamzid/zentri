import SwiftUI

/// The rules, one section per account and direction, with swipe actions on each row.
struct ParsingRulesList: View {
    let model: ParsingRulesModel
    let isReprocessing: Bool
    let onEdit: @MainActor (ParsingRuleListItem) -> Void
    let onToggle: @MainActor (ParsingRuleListItem) -> Void
    let onDelete: @MainActor (ParsingRuleListItem) -> Void
    let onReprocessFailures: @MainActor () -> Void

    var body: some View {
        List {
            if model.offersReprocessFailures {
                ReprocessFailuresSection(
                    failedCount: model.failedMessageCount,
                    isReprocessing: isReprocessing,
                    onReprocess: onReprocessFailures
                )
            }

            ForEach(model.sections) { section in
                Section {
                    ForEach(section.rules) { rule in
                        ParsingRuleRow(rule: rule, onEdit: onEdit)
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
                } header: {
                    Text("\(section.accountName) · \(Text(section.direction.displayName))")
                }
            }

            Section {
            } footer: {
                Text("Rules run from the lowest priority number up, then oldest first. The first rule whose match passes validation wins.")
            }
        }
        .scrollContentBackground(.hidden)
    }
}
