import SwiftUI

/// The named groups a rule can capture, with an example pattern to start from.
struct RuleGroupCheatSheet: View {
    let onUseExample: @MainActor () -> Void

    @State private var isExpanded = false
    @State private var copiedCount = 0

    var body: some View {
        Section {
            DisclosureGroup("Named groups", isExpanded: $isExpanded) {
                RuleGroupRow(name: "amount", detail: "Required. The amount, such as 1,234.50.")
                RuleGroupRow(name: "merchant", detail: "Who was paid or who paid you.")
                RuleGroupRow(name: "balance", detail: "The balance after the transaction.")
                RuleGroupRow(name: "date", detail: "The transaction date. Add a date format if it isn't common.")
                RuleGroupRow(name: "time", detail: "The time, combined with the date when the format includes it.")
                RuleGroupRow(name: "reference", detail: "A reference number.")

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(RuleEditorModel.examplePattern)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Theme.Spacing.md) {
                            RuleExampleButtons(onCopy: copyExample, onUse: onUseExample)
                        }
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            RuleExampleButtons(onCopy: copyExample, onUse: onUseExample)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            .accessibilityIdentifier("ruleEditor.cheatSheet")
        } footer: {
            Text("Write a group as (?<name>…). Groups other than amount are optional.")
        }
        .sensoryFeedback(.success, trigger: copiedCount)
    }

    private func copyExample() {
        Clipboard.copy(RuleEditorModel.examplePattern)
        copiedCount += 1
    }
}
