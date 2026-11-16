import SwiftUI
import ZentriCore

/// The selected month's spending, one bar per day, with a day picked out by touch.
///
/// This view only formats the month once, from the environment's money format and locale, and hands
/// the result to ``DailySpendingChartContent``; it re-renders when the month or the format changes,
/// never while a person drags across the bars.
struct DailySpendingChart: View {
    let days: [DailySpend]
    /// The month's spend, which is also the sum of `days`.
    let total: Decimal

    @Environment(\.moneyFormat) private var moneyFormat
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily spending")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if total > 0, !days.isEmpty {
                    Text("Avg \(moneyFormat.wholeCurrencyString(from: total / Decimal(days.count))) a day")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            if total > 0 {
                DailySpendingChartContent(
                    data: DailySpendingChartData(
                        days: days,
                        total: total,
                        moneyFormat: moneyFormat,
                        locale: locale,
                        calendar: calendar
                    )
                )
            } else {
                ContentUnavailableView("No spending to chart", systemImage: "chart.bar")
            }
        }
        .glassCard()
    }
}

#Preview {
    DailySpendingChart(
        days: (0..<30).map { offset in
            DailySpend(date: .now.addingTimeInterval(Double(offset - 29) * 86_400), amount: Decimal(offset % 4 * 12))
        },
        total: 540
    )
    .padding()
    .ambientBackground()
}
