import SwiftUI

/// One headline figure: a small title over a large amount.
///
/// The amount's color repeats what the title already says, so color is never the only cue.
struct InsightsTotalFigure: View {
    let title: LocalizedStringResource
    let amount: Decimal
    let style: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            MoneyText(amount)
                .font(.title2.bold())
                .foregroundStyle(style)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
