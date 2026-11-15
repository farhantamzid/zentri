import SwiftUI
import ZentriCore

/// What the middle of the category donut says: the selected slice's name, amount, and share, or a
/// prompt to pick one.
///
/// It repeats what the selected slice already announces, so VoiceOver skips it.
struct CategoryDonutCenterLabel: View {
    let category: CategoryTotal?

    var body: some View {
        VStack(spacing: Theme.Spacing.xs / 2) {
            if let category {
                Text(category.categoryName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                MoneyText(category.amount)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(category.formattedShare)
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
