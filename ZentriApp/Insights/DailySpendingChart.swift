import Charts
import SwiftUI
import ZentriCore

/// The selected month's spending, one bar per day, with a day picked out by touch.
///
/// Touching or dragging across the chart selects a day and labels its bar with the date and amount.
/// VoiceOver hears every bar's day and amount, and the chart itself reads as a table — the month's
/// total, then every day and its spend — for a person who would rather hear the numbers than the
/// shape.
struct DailySpendingChart: View {
    let days: [DailySpend]
    /// The month's spend, which is also the sum of `days`.
    let total: Decimal

    @Environment(\.moneyFormat) private var moneyFormat
    @Environment(\.calendar) private var calendar
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 180
    @State private var selectedDate: Date?

    var body: some View {
        ChartCard("Daily spending") {
            if total > 0 {
                chart
                    .frame(height: chartHeight)
                    .chartReveal()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Daily spending")
                    .accessibilityValue(monthTable)
                    .accessibilityIdentifier("insights.dailyChart")
                    .sensoryFeedback(.selection, trigger: selectedDay?.date)
            } else {
                ContentUnavailableView("No spending to chart", systemImage: "chart.bar")
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(days, id: \.date) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Spent", day.amount)
                )
                .foregroundStyle(Theme.spending)
                .opacity(selectedDay == nil || selectedDay?.date == day.date ? 1 : 0.35)
                .cornerRadius(Theme.Spacing.xs / 2)
                .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).month(.abbreviated).day()))
                .accessibilityValue(Text(money(day.amount)))
            }
            if let selectedDay {
                RuleMark(x: .value("Day", selectedDay.date, unit: .day))
                    .foregroundStyle(Theme.secondaryInk.opacity(0.4))
                    .annotation(
                        position: .top,
                        spacing: Theme.Spacing.xs,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ChartSelectionLabel(
                            title: Text(selectedDay.date, format: .dateTime.month(.abbreviated).day()),
                            amount: selectedDay.amount
                        )
                    }
                    .accessibilityHidden(true)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
            }
        }
    }

    /// The day under the person's finger, if any.
    private var selectedDay: DailySpend? {
        guard let selectedDate else { return nil }
        return days.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    /// The month as a table reads it: the total, then one day and its spend per line.
    private var monthTable: String {
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
}

#Preview {
    DailySpendingChart(
        days: (0..<30).map { offset in
            DailySpend(date: .now.addingTimeInterval(Double(offset - 29) * 86_400), amount: Decimal(offset % 4 * 12))
        },
        total: 540
    )
    .padding()
    .background(Theme.canvas)
}
