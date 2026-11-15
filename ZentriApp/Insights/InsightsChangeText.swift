import SwiftUI

/// A category's change since last month, in words and with an arrow: "50% more than last month".
///
/// The words carry the direction, so the arrow is decorative and the meaning never rests on it.
/// The percentage arrives scaled to 100, as `CategoryTotal.changePercent` reports it; `nil` means the
/// previous month had no spend in the category.
struct InsightsChangeText: View {
    let changePercent: Decimal?

    var body: some View {
        Label {
            text
        } icon: {
            Image(systemName: symbolName)
                .accessibilityHidden(true)
        }
        .font(.footnote)
        .foregroundStyle(Theme.secondaryInk)
    }

    private var wholePercent: Int? {
        changePercent?.roundedToWholeNumber
    }

    private var text: Text {
        guard let wholePercent else {
            return Text("Nothing last month")
        }
        if wholePercent > 0 {
            return Text("\(percentText(wholePercent)) more than last month")
        }
        if wholePercent < 0 {
            return Text("\(percentText(-wholePercent)) less than last month")
        }
        return Text("About the same as last month")
    }

    private var symbolName: String {
        guard let wholePercent else { return "sparkle" }
        if wholePercent > 0 { return "arrow.up.right" }
        if wholePercent < 0 { return "arrow.down.right" }
        return "equal"
    }

    /// A whole percentage in the person's number format, e.g. `50%`.
    private func percentText(_ wholePercent: Int) -> String {
        (Decimal(wholePercent) / 100).formatted(.percent.precision(.fractionLength(0)))
    }
}
