import SwiftUI

/// One observation, written as a sentence from the string catalog.
///
/// The symbol is decorative: the sentence says everything, so VoiceOver reads only the sentence.
struct InsightsObservationRow: View {
    let observation: InsightsObservation

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
                .background(Theme.accentSoft, in: .rect(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            sentence
                .font(.subheadline)
                .lineSpacing(2)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("insights.observation")
    }

    private var sentence: Text {
        switch observation {
        case let .categoryChange(categoryName, wholePercent) where wholePercent > 0:
            Text("\(categoryName) is \(wholePercent)% higher than last month.")
        case let .categoryChange(categoryName, wholePercent) where wholePercent < 0:
            Text("\(categoryName) is \(-wholePercent)% lower than last month.")
        case let .categoryChange(categoryName, _):
            // A change that rounds to 0% may still be a fraction of a percent either way.
            Text("\(categoryName) is about the same as last month.")
        case let .peakDay(date, ratio):
            Text("You spent \(ratioText(ratio))× your daily average on \(dayText(date)).")
        case let .topMerchant(merchant, transactionCount):
            Text("\(merchant) is your top merchant with ^[\(transactionCount) transaction](inflect: true).")
        }
    }

    private var symbolName: String {
        switch observation {
        case let .categoryChange(_, wholePercent) where wholePercent > 0: "arrow.up.right"
        case let .categoryChange(_, wholePercent) where wholePercent < 0: "arrow.down.right"
        case .categoryChange: "equal"
        case .peakDay: "calendar"
        case .topMerchant: "storefront"
        }
    }

    /// The ratio with one decimal, e.g. "3.2", in the person's number format.
    private func ratioText(_ ratio: Decimal) -> String {
        ratio.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    /// The day without the year, e.g. "12 Oct" or "Oct 12", in the person's date format.
    private func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }
}
