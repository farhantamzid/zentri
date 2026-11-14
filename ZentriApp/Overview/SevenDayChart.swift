import Charts
import SwiftUI
import ZentriCore

/// The last seven days of spending, one bar per day.
///
/// Every bar announces its own day and amount, so VoiceOver can move through the week bar by bar,
/// and the chart itself announces the week as a table — every day and its spend, one row after
/// another — for a person who would rather hear the numbers than the shape. The reveal follows
/// Reduce Motion: with it on, the chart is simply there.
struct SevenDayChart: View {
    private let days: [DailySpend]

    @Environment(\.moneyFormat) private var moneyFormat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 160
    @State private var revealed = false

    init(days: [DailySpend]) {
        self.days = days
    }

    var body: some View {
        ChartCard("Last seven days") {
            if days.contains(where: { $0.amount > 0 }) {
                chart
                    .frame(height: chartHeight)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : Theme.Spacing.sm)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Spending, last seven days")
                    .accessibilityValue(weekTable)
                    .onAppear(perform: reveal)
            } else {
                ContentUnavailableView(
                    "No spending in the last seven days",
                    systemImage: "chart.bar"
                )
            }
        }
    }

    private var chart: some View {
        Chart(days, id: \.date) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Spent", day.amount),
                width: .ratio(0.6)
            )
            .foregroundStyle(Theme.accent)
            .cornerRadius(Theme.Spacing.xs)
            .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).month(.abbreviated).day()))
            .accessibilityValue(Text(money(day.amount)))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
            }
        }
    }

    /// The week as a table reads it: a total, then one day and its spend per line.
    private var weekTable: String {
        let total = days.reduce(Decimal.zero) { $0 + $1.amount }
        let rows = days.map { day in
            String(localized: "\(dayText(day.date)): \(money(day.amount))")
        }
        return ([String(localized: "Total \(money(total))")] + rows).joined(separator: "\n")
    }

    private func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func money(_ amount: Decimal) -> String {
        moneyFormat.currencyString(from: amount)
    }

    private func reveal() {
        guard !revealed else { return }
        if reduceMotion {
            revealed = true
        } else {
            withAnimation(.easeOut(duration: 0.45)) {
                revealed = true
            }
        }
    }
}

#Preview {
    SevenDayChart(
        days: [
            DailySpend(date: .now.addingTimeInterval(-6 * 86_400), amount: 12.5),
            DailySpend(date: .now.addingTimeInterval(-5 * 86_400), amount: 0),
            DailySpend(date: .now.addingTimeInterval(-4 * 86_400), amount: 42),
            DailySpend(date: .now.addingTimeInterval(-3 * 86_400), amount: 8.75),
            DailySpend(date: .now.addingTimeInterval(-2 * 86_400), amount: 0),
            DailySpend(date: .now.addingTimeInterval(-86_400), amount: 19.99),
            DailySpend(date: .now, amount: 7.4),
        ]
    )
    .padding()
    .background(Theme.canvas)
}
