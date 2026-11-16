import SwiftUI
import ZentriCore

/// Where the transaction came from: the bank message as a chat bubble with the amount and merchant
/// it was read from picked out, then the engine, the matched rule, and the category's source.
struct TransactionDetailSourceSection: View {
    let transaction: ZentriCore.Transaction
    let matchedRuleName: String?

    var body: some View {
        Section {
            if let message = transaction.rawMessage {
                Text(highlighted(message.text))
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 18, bottomLeadingRadius: 6,
                            bottomTrailingRadius: 18, topTrailingRadius: 18,
                            style: .continuous
                        )
                        .fill(Theme.fill)
                    )
                    .accessibilityLabel(Text(message.text))
                    .accessibilityIdentifier("transactions.detail.rawSMS")
            } else {
                Text("No bank message is linked to this transaction.")
                    .foregroundStyle(Theme.secondaryInk)
            }
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
        } header: {
            GroupHeading("Source")
        }
        .riseIn(delay: 0.28)
    }

    /// The message with the first appearance of the amount and of the merchant marked in the accent.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let amount = NSDecimalNumber(decimal: transaction.amount)
        let candidates = [
            amount.stringValue,
            String(format: "%.2f", amount.doubleValue),
            amount.doubleValue.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US"))),
            transaction.merchantRaw,
        ]
        var marked = Set<String>()
        for candidate in candidates where !candidate.isEmpty && !marked.contains(candidate) {
            guard let range = attributed.range(of: candidate, options: .caseInsensitive) else { continue }
            attributed[range].foregroundColor = Theme.accent
            attributed[range].backgroundColor = Theme.accentSoft
            attributed[range].font = .subheadline.weight(.semibold)
            marked.insert(candidate)
        }
        return attributed
    }
}
