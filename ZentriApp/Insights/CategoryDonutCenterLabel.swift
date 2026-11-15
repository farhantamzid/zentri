import SwiftUI

/// What the middle of the category donut says: the selected slice's name, amount, and share, or a
/// prompt to pick one.
///
/// It repeats what the selected slice already announces, so VoiceOver skips it.
struct CategoryDonutCenterLabel: View {
    let slice: CategoryDonutChartData.Slice?

    var body: some View {
        VStack(spacing: Theme.Spacing.xs / 2) {
            if let slice {
                Text(slice.category.categoryName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                Text(slice.amountText)
                    .monospacedDigit()
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(slice.shareText)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                Text("Tap a slice")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
        .accessibilityHidden(true)
    }
}
