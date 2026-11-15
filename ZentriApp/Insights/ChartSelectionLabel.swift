import SwiftUI

/// The small callout a chart shows over the value a person has selected: what it is, and how much.
struct ChartSelectionLabel: View {
    let title: Text
    /// The amount, already formatted with the app's money format.
    let amountText: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
            title
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
            Text(amountText)
                .monospacedDigit()
                .font(.subheadline.bold())
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(.background, in: .rect(cornerRadius: Theme.Spacing.sm))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Spacing.sm)
                .strokeBorder(.separator)
        }
    }
}
