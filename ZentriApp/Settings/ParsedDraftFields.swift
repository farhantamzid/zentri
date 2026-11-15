import SwiftUI
import ZentriCore

/// The fields a parse extracted, one labeled row each, for the rule editor and the tester.
///
/// Values are shown as the parser read them — plain numbers rather than currency — because the
/// question here is whether the rule captured the right text.
struct ParsedDraftFields: View {
    let draft: TransactionDraft
    /// A prefix for the rows' identifiers, so UI tests can tell the tester's sides apart.
    let identifierPrefix: String

    var body: some View {
        LabeledContent("Amount") {
            Text(draft.amount, format: .number)
                .monospacedDigit()
        }
        .accessibilityIdentifier("\(identifierPrefix).amount")

        LabeledContent("Direction") {
            Text(draft.direction.displayName)
        }

        LabeledContent("Merchant") {
            Text(draft.merchant)
        }
        .accessibilityIdentifier("\(identifierPrefix).merchant")

        LabeledContent("Balance") {
            if let balance = draft.balanceAfter {
                Text(balance, format: .number)
                    .monospacedDigit()
            } else {
                Text("Not in message")
            }
        }

        LabeledContent("Date") {
            if let occurredAt = draft.occurredAt {
                Text(occurredAt, format: .dateTime.day().month().year().hour().minute())
            } else {
                Text("Not in message")
            }
        }

        if let reference = draft.reference {
            LabeledContent("Reference") {
                Text(reference)
            }
        }
    }
}
