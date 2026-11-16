import Charts
import SwiftUI

/// The daily bars, the selected day's callout, and the month's summary.
///
/// Touching or dragging across the chart selects a day and labels its bar with the date and amount;
/// the selection stays after the finger lifts, and the next month starts without one. Every bar
/// announces its day and amount, the chart offers VoiceOver an audio graph and data table, and the
/// summary beneath it says the month's total and highest day in words.
struct DailySpendingChartContent: View {
    let data: DailySpendingChartData

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 180
    @State private var touchedDate: Date?
    @State private var selectedDay: Date?

    /// The month's average day, which the dashed line marks.
    private var average: Decimal {
        guard !data.points.isEmpty else { return 0 }
        return data.points.reduce(Decimal.zero) { $0 + $1.amount } / Decimal(data.points.count)
    }

    var body: some View {
        let selected = selectedDay.flatMap(data.point(containing:))
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Chart {
                ForEach(data.points) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Spent", point.amount),
                        width: .ratio(0.78)
                    )
                    .foregroundStyle(barStyle(for: point, selected: selected))
                    .cornerRadius(4)
                    .accessibilityLabel(Text(point.dayText))
                    .accessibilityValue(Text(point.amountText))
                }
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(Theme.accent.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .accessibilityHidden(true)
                if let selected {
                    RuleMark(x: .value("Day", selected.date, unit: .day))
                        .foregroundStyle(Theme.ink.opacity(0.35))
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
                        .foregroundStyle(Theme.tertiaryInk)
                }
            }
            .chartYAxis(.hidden)
            .animation(Theme.Motion.snap, value: selectedDay)
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

    private func barStyle(for point: DailySpendingChartData.Point, selected: DailySpendingChartData.Point?) -> Color {
        guard let selected else { return Theme.accent.opacity(0.67) }
        return selected.date == point.date ? Theme.accent : Theme.accentSoft
    }

    private func updateSelection() {
        selectedDay = ChartSelectionRule.selection(
            current: selectedDay,
            touched: touchedDate.flatMap(data.point(containing:))?.date
        )
    }
}
