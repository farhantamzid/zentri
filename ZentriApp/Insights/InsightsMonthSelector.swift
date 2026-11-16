import SwiftUI

/// The month the screen shows, with previous and next arrows and a way back to this month.
///
/// The arrows keep their names for VoiceOver while drawing only their symbols. Every control's
/// label is at least 44 points tall (and the arrows 44 wide), inside the button, so the whole target
/// answers a tap rather than only the glyph. "Next month" is disabled on this month, since a month
/// that has not started has nothing to show; "This month" is disabled when it is already showing.
/// The month's name slides in from the side it came from.
struct InsightsMonthSelector: View {
    let month: Date
    let isShowingThisMonth: Bool
    let onPrevious: @MainActor () -> Void
    let onNext: @MainActor () -> Void
    let onThisMonth: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var direction: Edge = .trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) {
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
        HStack(spacing: 2) {
            Button {
                direction = .leading
                withAnimation(Theme.Motion.rise) { onPrevious() }
            } label: {
                Label("Previous Month", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.title2.weight(.medium))
                    .frame(minWidth: 40, minHeight: Theme.Layout.minimumTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(PressableStyle(scale: 0.85))
            .foregroundStyle(Theme.accent)
            .accessibilityIdentifier("insights.previousMonth")

            ZStack {
                Text(month, format: .dateTime.month(.wide).year())
                    .id(month)
                    .transition(
                        reduceMotion
                            ? .identity
                            : .asymmetric(
                                insertion: .move(edge: direction == .leading ? .leading : .trailing).combined(with: .opacity),
                                removal: .opacity
                            )
                    )
            }
            .font(.title3.bold())
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .frame(minWidth: 150)
            .clipped()
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("insights.month")

            Button {
                direction = .trailing
                withAnimation(Theme.Motion.rise) { onNext() }
            } label: {
                Label("Next Month", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .font(.title2.weight(.medium))
                    .frame(minWidth: 40, minHeight: Theme.Layout.minimumTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(PressableStyle(scale: 0.85))
            .foregroundStyle(isShowingThisMonth ? Theme.tertiaryInk : Theme.accent)
            .disabled(isShowingThisMonth)
            .accessibilityIdentifier("insights.nextMonth")
        }
    }

    private var thisMonthButton: some View {
        Button {
            direction = .trailing
            withAnimation(Theme.Motion.rise) { onThisMonth() }
        } label: {
            Text("This Month")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isShowingThisMonth ? Theme.tertiaryInk : Theme.accent)
                .padding(.horizontal, 14)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .background {
                    Capsule()
                        .fill(Theme.glass)
                        .overlay { Capsule().strokeBorder(Theme.glassBorder) }
                        .padding(.vertical, 3)
                }
                .contentShape(.capsule)
        }
        .buttonStyle(PressableStyle())
        .disabled(isShowingThisMonth)
        .accessibilityIdentifier("insights.thisMonth")
    }
}

#Preview {
    InsightsMonthSelector(month: .now, isShowingThisMonth: true, onPrevious: {}, onNext: {}, onThisMonth: {})
        .padding()
        .ambientBackground()
}
