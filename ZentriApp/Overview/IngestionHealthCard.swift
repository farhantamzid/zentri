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
        VStack(alignment: .leading, spacing: 0) {
            Text("Ingestion health")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Theme.Spacing.md)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.sm) { tiles }
                VStack(spacing: Theme.Spacing.sm) { tiles }
            }

            NavigationLink(value: ParsingRoute.inbox) {
                HStack(spacing: 10) {
                    Image(systemName: "tray")
                    Text("Open Message Inbox")
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryInk)
                        .accessibilityHidden(true)
                }
                .font(.callout)
                .foregroundStyle(Theme.accent)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .accessibilityIdentifier("overview.health.inbox")
        }
        .glassCard()
    }

    @ContentBuilder
    private var tiles: some View {
        tile("Last message", value: timestamp(health.lastMessageAt), identifier: "overview.health.lastMessage")
        tile("Last parsed", value: timestamp(health.lastSuccessAt), identifier: "overview.health.lastSuccess")
        failedTile
    }

    private func tile(_ title: LocalizedStringResource, value: Text, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.secondaryInk)
            value
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .background(Theme.fill, in: .rect(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var failedTile: some View {
        let hasFailures = health.failureCount > 0
        return VStack(alignment: .leading, spacing: 3) {
            Text("Failed messages")
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Label {
                Text(health.failureCount, format: .number)
            } icon: {
                Image(systemName: hasFailures ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.footnote)
                    .accessibilityHidden(true)
            }
            .labelStyle(TightLabelStyle())
            .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(hasFailures ? Theme.spending : Theme.income)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .background(hasFailures ? Theme.spendingSoft : Theme.fill, in: .rect(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("overview.health.failureCount")
    }

    /// A timestamp, or "Never" when the event has not happened: the time alone for today, the date
    /// otherwise.
    ///
    /// The date goes through `Text`'s format rather than a string so it follows the reader's locale
    /// and clock settings.
    private func timestamp(_ date: Date?) -> Text {
        guard let date else { return Text("Never") }
        if Calendar.current.isDateInToday(date) {
            return Text(date, format: .dateTime.hour().minute())
        }
        return Text(date, format: .dateTime.month(.abbreviated).day())
    }
}

#Preview {
    NavigationStack {
        VStack {
            IngestionHealthCard(
                health: IngestionHealth(lastMessageAt: .now, lastSuccessAt: .now.addingTimeInterval(-3_600), failureCount: 1)
            )
            IngestionHealthCard(health: IngestionHealth(lastMessageAt: nil, lastSuccessAt: nil, failureCount: 0))
        }
        .padding()
        .ambientBackground()
    }
}
