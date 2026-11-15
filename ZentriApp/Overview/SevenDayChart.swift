import Charts
import SwiftUI
import ZentriCore

/// The last seven days of spending, one bar per day.
///
/// Every bar announces its own day and amount, so VoiceOver can move through the week bar by bar,
/// and the chart offers an audio graph and data table (VoiceOver's Chart Details) — every day and
/// its spend — for a person who would rather hear the numbers than the shape. The reveal follows
/// Reduce Motion: with it on, the chart is simply there.
struct SevenDayChart: View {
    private let days: [DailySpend]

    @Environment(\.moneyFormat) private var moneyFormat
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 160
    @State private var revealed = false

    init(days: [DailySpend]) {
        self.days = days
    }

    var body: some View {
        ChartCard("Last seven days") {
            if days.contains(where: { $0.amount > 0 }) {
                let data = SevenDayChartData(days: days, moneyFormat: moneyFormat, locale: locale)
                chart
                    .frame(height: chartHeight)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : Theme.Spacing.sm)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Spending, last seven days")
                    .accessibilityValue(data.weekTable)
                    .accessibilityChartDescriptor(data.descriptor)
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
