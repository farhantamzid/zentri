import SwiftUI

/// The month the screen shows, with previous and next arrows and a way back to this month.
///
/// The arrows keep their names for VoiceOver while drawing only their symbols. Every control's
/// label is at least 44 points tall (and the arrows 44 wide), inside the button, so the whole target
/// answers a tap rather than only the glyph. "Next month" is disabled on this month, since a month that has not
/// started has nothing to show; "This month" is disabled when it is already showing.
struct InsightsMonthSelector: View {
    let month: Date
    let isShowingThisMonth: Bool
    let onPrevious: @MainActor () -> Void
    let onNext: @MainActor () -> Void
    let onThisMonth: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                arrows
                Spacer(minLength: Theme.Spacing.sm)
                thisMonthButton
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                arrows
                thisMonthButton
            }
        }
        .sensoryFeedback(.selection, trigger: month)
    }

    private var arrows: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button(action: onPrevious) {
                Label("Previous Month", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: Theme.Layout.minimumTapTarget, minHeight: Theme.Layout.minimumTapTarget)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier("insights.previousMonth")

            Text(month, format: .dateTime.month(.wide).year())
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("insights.month")

            Button(action: onNext) {
                Label("Next Month", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: Theme.Layout.minimumTapTarget, minHeight: Theme.Layout.minimumTapTarget)
                    .contentShape(.rect)
            }
            .disabled(isShowingThisMonth)
            .accessibilityIdentifier("insights.nextMonth")
        }
    }

    private var thisMonthButton: some View {
        Button(action: onThisMonth) {
            Text("This Month")
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.bordered)
        .disabled(isShowingThisMonth)
            .accessibilityIdentifier("insights.thisMonth")
    }
}

#Preview {
    InsightsMonthSelector(
        month: .now,
        isShowingThisMonth: true,
        onPrevious: {},
        onNext: {},
        onThisMonth: {}
    )
    .padding()
    .background(Theme.canvas)
}
