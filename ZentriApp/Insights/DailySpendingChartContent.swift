import Charts
import SwiftUI

/// The daily bars, the selected day's callout, and the month's summary.
///
/// Touching or dragging across the chart selects a day and labels its bar with the date and amount;
/// the selection stays after the finger lifts, and touching the same day again clears it. Every bar
/// announces its day and amount, the chart offers VoiceOver an audio graph and data table, and the
/// summary beneath it says the month's total and highest day in words.
struct DailySpendingChartContent: View {
    let data: DailySpendingChartData

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 180
    @State private var touchedDate: Date?
    @State private var selectedDay: Date?

    var body: some View {
        let selected = selectedDay.flatMap(data.point(containing:))
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Chart {
                ForEach(data.points) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Spent", point.amount)
                    )
                    .foregroundStyle(Theme.spending)
                    .opacity(selected == nil || selected?.date == point.date ? 1 : 0.35)
                    .cornerRadius(Theme.Spacing.xs / 2)
                    .accessibilityLabel(Text(point.dayText))
                    .accessibilityValue(Text(point.amountText))
                }
                if let selected {
                    RuleMark(x: .value("Day", selected.date, unit: .day))
                        .foregroundStyle(Theme.secondaryInk.opacity(0.4))
                        .annotation(
                            position: .top,
                            spacing: Theme.Spacing.xs,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            ChartSelectionLabel(title: Text(selected.dayText), amountText: selected.amountText)
                        }
                        .accessibilityHidden(true)
                }
            }
            .chartXSelection(value: $touchedDate)
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
            .frame(height: chartHeight)
            .chartReveal()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Daily spending")
            .accessibilityChartDescriptor(data.descriptor)
            .accessibilityIdentifier("insights.dailyChart")
            .onChange(of: touchedDate, updateSelection)
            .sensoryFeedback(.selection, trigger: selectedDay)

            Text(data.summary)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .accessibilityIdentifier("insights.dailyChart.summary")
        }
    }

    private func updateSelection(from oldValue: Date?, to newValue: Date?) {
        selectedDay = ChartSelectionRule.selection(
            current: selectedDay,
            touched: newValue.flatMap(data.point(containing:))?.date,
            touchBegan: oldValue == nil
        )
    }
}
