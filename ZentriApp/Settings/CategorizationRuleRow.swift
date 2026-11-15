import SwiftUI

/// One keyword rule: its keyword, the category it files into, its priority, and whether it is on.
///
/// The row is a button that opens the editor; VoiceOver hears it as one element, with the on/off
/// state spelled out rather than shown only by dimming.
struct CategorizationRuleRow: View {
    let rule: CategorizationRuleListItem
    let onEdit: @MainActor (CategorizationRuleListItem) -> Void

    var body: some View {
        Button(action: edit) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(rule.keyword)
                    .font(.body.monospaced())
                    .foregroundStyle(rule.isEnabled ? Theme.ink : Theme.secondaryInk)
                Label {
                    Text(rule.categoryName)
                        .foregroundStyle(Theme.ink)
                } icon: {
                    Image(systemName: rule.symbolName)
                        .foregroundStyle(Theme.categoryColor(for: rule.colorToken))
                }
                .font(.subheadline)
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Edits the rule."))
        .accessibilityIdentifier("rules.row")
    }

    private var status: LocalizedStringResource {
        rule.isEnabled ? "Priority \(rule.priority)" : "Priority \(rule.priority) · Off"
    }

    private func edit() {
        onEdit(rule)
    }
}
