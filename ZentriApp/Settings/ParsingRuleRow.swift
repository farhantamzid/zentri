import SwiftUI

/// One parsing rule: its name, its pattern, its priority, and whether it is on.
///
/// The row is a button that opens the editor; VoiceOver hears it as one element, with the on/off
/// state and a broken pattern spelled out rather than shown only by dimming.
struct ParsingRuleRow: View {
    let rule: ParsingRuleListItem
    let onEdit: @MainActor (ParsingRuleListItem) -> Void

    var body: some View {
        Button(action: edit) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(rule.name)
                    .foregroundStyle(rule.isEnabled ? Theme.ink : Theme.secondaryInk)
                Text(rule.pattern)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(2)
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                if !rule.isPatternValid {
                    Label("The pattern can't be used. Edit it to fix it.", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(Theme.spending)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Edits the rule."))
        .accessibilityIdentifier("parsingRules.row")
    }

    private var status: LocalizedStringResource {
        rule.isEnabled ? "Priority \(rule.priority)" : "Priority \(rule.priority) · Off"
    }

    private func edit() {
        onEdit(rule)
    }
}
