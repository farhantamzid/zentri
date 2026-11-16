import SwiftUI

/// One headline figure: a small title over a large amount that rolls to each month's value.
///
/// The amount's color repeats what the title already says, so color is never the only cue.
struct InsightsTotalFigure: View {
    let title: LocalizedStringResource
    let amount: Decimal
    let style: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            MoneyText(amount)
                .font(.system(size: 26, weight: .bold))
                .kerning(-0.5)
                .foregroundStyle(style)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(reduceMotion ? .identity : .numericText(value: NSDecimalNumber(decimal: amount).doubleValue))
                .animation(Theme.Motion.settle, value: amount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
