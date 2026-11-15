import SwiftUI
import ZentriCore

/// One archived message: when it arrived, the start of its text, its status and engine, and the
/// error when it failed.
struct RawMessageRow: View {
    let message: RawMessageListItem

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(message.status.displayName)
                } icon: {
                    Image(systemName: message.status.systemImage)
                }
                .font(.subheadline)
                .foregroundStyle(message.status == .failed ? Theme.spending : Theme.secondaryInk)
                Spacer()
                Text(message.receivedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            Text(message.text)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            if let engine = message.engine {
                Text(engine.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            if let error = message.errorDescription {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(2)
            }
        }
        .frame(minHeight: Theme.Layout.minimumTapTarget)
        .accessibilityElement(children: .combine)
    }
}
