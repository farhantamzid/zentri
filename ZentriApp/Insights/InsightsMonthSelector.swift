import SwiftUI

/// The month the screen shows, with previous and next arrows and a way back to this month.
///
/// The arrows keep their names for VoiceOver while drawing only their symbols, and every control
/// is at least 44 points square. "Next month" is disabled on this month, since a month that has not
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
            Button("Previous Month", systemImage: "chevron.left", action: onPrevious)
                .labelStyle(.iconOnly)
                .frame(minWidth: Theme.Layout.minimumTapTarget, minHeight: Theme.Layout.minimumTapTarget)
                .contentShape(.rect)
                .accessibilityIdentifier("insights.previousMonth")

            Text(month, format: .dateTime.month(.wide).year())
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("insights.month")

            Button("Next Month", systemImage: "chevron.right", action: onNext)
                .labelStyle(.iconOnly)
                .frame(minWidth: Theme.Layout.minimumTapTarget, minHeight: Theme.Layout.minimumTapTarget)
                .contentShape(.rect)
                .disabled(isShowingThisMonth)
                .accessibilityIdentifier("insights.nextMonth")
        }
    }

    private var thisMonthButton: some View {
        Button("This Month", action: onThisMonth)
            .buttonStyle(.bordered)
            .frame(minHeight: Theme.Layout.minimumTapTarget)
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
