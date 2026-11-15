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
        AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: seriesDescriptors
        )
    }

    /// Rewrites a descriptor VoiceOver already holds.
    ///
    /// SwiftUI asks for a descriptor once per view identity and afterwards only asks to update it, so
    /// without this a refreshed month or a month's new data would leave the audio graph and its data
    /// table describing what the chart first showed.
    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
        descriptor.title = title
        descriptor.summary = summary
        descriptor.xAxis = xAxis
        descriptor.yAxis = yAxis
        descriptor.series = seriesDescriptors
    }

    private var xAxis: AXCategoricalDataAxisDescriptor {
        AXCategoricalDataAxisDescriptor(title: xAxisTitle, categoryOrder: categories)
    }

    private var yAxis: AXNumericDataAxisDescriptor {
        let largest = series.flatMap(\.points).map(\.value).max() ?? 0
        let format = moneyFormat
        return AXNumericDataAxisDescriptor(title: yAxisTitle, range: 0...max(largest, 1), gridlinePositions: []) { value in
            format.currencyString(from: Decimal(value))
        }
    }

    private var seriesDescriptors: [AXDataSeriesDescriptor] {
        series.map { series in
            AXDataSeriesDescriptor(
                name: series.name,
                isContinuous: false,
                dataPoints: series.points.map {
                    AXDataPoint(x: $0.category, y: $0.value, additionalValues: [], label: $0.valueText)
                }
            )
        }
    }
}
