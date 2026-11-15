import SwiftUI
import ZentriCore

/// The message's text and what Zentri made of it.
struct RawMessageDetailSections: View {
    let message: RawMessageListItem
    /// What the last reprocess on this screen said, if one ran.
    let outcomeMessage: LocalizedStringResource?

    var body: some View {
        Section("Message") {
            Text(message.text)
                .font(.body.monospaced())
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
                .accessibilityIdentifier("inbox.detail.text")
            if let sender = message.sender {
                LabeledContent("Sender") {
                    Text(sender)
                }
            }
            LabeledContent("Received") {
                Text(message.receivedAt, format: .dateTime.day().month().year().hour().minute())
            }
        }

        Section("Result") {
            LabeledContent("Status") {
                Label {
                    Text(message.status.displayName)
                } icon: {
                    Image(systemName: message.status.systemImage)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("inbox.detail.status")

            if let engine = message.engine {
                LabeledContent("Parsed by") {
                    Text(engine.displayName)
                }
            }
            if message.matchedRuleID != nil {
                LabeledContent("Matched rule") {
                    Text(message.matchedRuleName ?? String(localized: "A rule that no longer exists"))
                }
            }
            if let error = message.errorDescription {
                LabeledContent("Error") {
                    Text(error)
                }
            }
            if let outcomeMessage {
                Text(outcomeMessage)
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("inbox.detail.outcome")
            }
        }
    }
}
