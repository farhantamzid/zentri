import SwiftUI

/// How message ingestion has been going: what last arrived, what last parsed, and what failed.
///
/// The three figures answer the question a missing transaction raises — did the message arrive,
/// and did it read — so a person can tell the automation apart from the parser. The card links to
/// the raw-message inbox, where a failed message can be read and reprocessed.
struct IngestionHealthCard: View {
    private let health: IngestionHealth

    init(health: IngestionHealth) {
        self.health = health
    }

    var body: some View {
        SectionCard("Ingestion health") {
            VStack(spacing: Theme.Spacing.sm) {
                SummaryRow("Last message", identifier: "overview.health.lastMessage") {
                    timestamp(health.lastMessageAt)
                }

                Divider()

                SummaryRow("Last parsed", identifier: "overview.health.lastSuccess") {
                    timestamp(health.lastSuccessAt)
                }

                Divider()

                SummaryRow("Failed messages", identifier: "overview.health.failureCount") {
                    Label {
                        Text(health.failureCount, format: .number)
                            .foregroundStyle(health.failureCount == 0 ? Theme.secondaryInk : Theme.spending)
                    } icon: {
                        Image(systemName: health.failureCount == 0 ? "checkmark.circle" : "exclamationmark.triangle")
                            .foregroundStyle(health.failureCount == 0 ? Theme.income : Theme.spending)
                    }
                }

                Divider()

                NavigationLink(value: ParsingRoute.inbox) {
                    HStack {
                        Label("Open Message Inbox", systemImage: "tray.full")
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(Theme.secondaryInk)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: Theme.Layout.minimumTapTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("overview.health.inbox")
            }
        }
    }

    /// A timestamp, or "Never" when the event has not happened.
    ///
    /// The date goes through `Text`'s format rather than a string so it follows the reader's locale
    /// and clock settings.
    private func timestamp(_ date: Date?) -> Text {
        guard let date else { return Text("Never") }
        return Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
    }
}

#Preview {
    VStack {
        IngestionHealthCard(
            health: IngestionHealth(
                lastMessageAt: .now,
                lastSuccessAt: .now.addingTimeInterval(-3_600),
                failureCount: 1
            )
        )
        IngestionHealthCard(health: IngestionHealth(lastMessageAt: nil, lastSuccessAt: nil, failureCount: 0))
    }
    .padding()
    .background(Theme.canvas)
}
