import Accessibility
import Foundation
import SwiftUI
import ZentriCore

/// The audio graph and data table VoiceOver offers for an Insights chart.
///
/// Every chart is categories along the x-axis and money up the y-axis, so one descriptor shape
/// serves all three. Its strings arrive already localized and formatted, which keeps the descriptor
/// a plain value a test can inspect.
struct InsightsChartDescriptor: AXChartDescriptorRepresentable {
    /// One line of the chart, such as "Spent".
    struct Series: Equatable {
        let name: String
        let points: [Point]
    }

    /// One value: its category, its amount, and the amount as VoiceOver reads it.
    struct Point: Equatable {
        let category: String
        let value: Double
        let valueText: String
    }

    let title: String
    let summary: String
    let xAxisTitle: String
    let categories: [String]
    let yAxisTitle: String
    let series: [Series]
    let moneyFormat: MoneyFormat

    func makeChartDescriptor() -> AXChartDescriptor {
        let largest = series.flatMap(\.points).map(\.value).max() ?? 0
        let format = moneyFormat
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(title: xAxisTitle, categoryOrder: categories),
            yAxis: AXNumericDataAxisDescriptor(
                title: yAxisTitle,
                range: 0...max(largest, 1),
                gridlinePositions: []
            ) { value in
                format.currencyString(from: Decimal(value))
            },
            additionalAxes: [],
            series: series.map { series in
                AXDataSeriesDescriptor(
                    name: series.name,
                    isContinuous: false,
                    dataPoints: series.points.map {
                        AXDataPoint(x: $0.category, y: $0.value, additionalValues: [], label: $0.valueText)
                    }
                )
            }
        )
    }
}
