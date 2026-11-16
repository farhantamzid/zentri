import SwiftUI

/// The small callout a chart shows over the value a person has selected: what it is, and how much,
/// in ink on a dark pill as the design draws it.
struct ChartSelectionLabel: View {
    let title: Text
    /// The amount, already formatted with the app's money format.
    let amountText: String

    var body: some View {
        HStack(spacing: 4) {
            title
                .fontWeight(.bold)
            Text(verbatim: "·")
            Text(amountText)
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(Theme.canvas)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Theme.ink, in: .rect(cornerRadius: 10, style: .continuous))
    }
}
