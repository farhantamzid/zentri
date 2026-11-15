import SwiftUI
import ZentriCore

/// Where the transaction came from: the engine, the matched rule, the category's source, and the
/// bank message itself.
struct TransactionDetailSourceSection: View {
    let transaction: ZentriCore.Transaction
    let matchedRuleName: String?

    var body: some View {
        Section("Source") {
            LabeledContent("Parsed by") {
                Text(transaction.parseEngine?.displayName ?? "Unknown")
            }
            if transaction.matchedRuleID != nil {
                LabeledContent("Matched rule") {
                    Text(matchedRuleName ?? String(localized: "A rule that no longer exists"))
                }
            }
            if let source = transaction.categorySource {
                LabeledContent("Category from") {
                    Text(source.displayName)
                }
            }
            if let message = transaction.rawMessage {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Bank message")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                    Text(message.text)
                        .font(.body.monospaced())
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("transactions.detail.rawSMS")
                }
            } else {
                Text("No bank message is linked to this transaction.")
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
    }
}
