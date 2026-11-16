import SwiftUI

/// What the middle of the category donut says: the selected slice's name, amount, and share, or the
/// month's spend.
///
/// It repeats what the selected slice already announces, so VoiceOver skips it.
struct CategoryDonutCenterLabel: View {
    let slice: CategoryDonutChartData.Slice?
    /// The month's spend, shown when no slice is selected.
    var totalText: String = ""

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
                Text("Spent")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                Text(totalText)
                    .monospacedDigit()
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
        .accessibilityHidden(true)
    }
}
