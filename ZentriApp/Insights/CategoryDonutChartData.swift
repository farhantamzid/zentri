import CoreGraphics
import Foundation
import ZentriCore

/// Everything the category donut shows, formatted once per change in the month's categories.
///
/// The donut redraws on every frame of a drag, so each slice's strings, the angle range it covers,
/// the spoken summary, and the audio graph are built here rather than in its body.
struct CategoryDonutChartData {
    /// One category's slice.
    struct Slice: Identifiable {
        let category: CategoryTotal
        /// The slice's size, as the chart plots it.
        let value: Double
        /// Where the slice ends along the donut's running total; it starts where the previous one ends.
        let upperBound: Double
        let amountText: String
        /// The share of the month, e.g. "25%".
        let shareText: String

        var id: String { category.categoryName }
        /// The amount and share as VoiceOver reads them, e.g. "$250.00, 25%".
        var figuresText: String { String(localized: "\(amountText), \(shareText)") }
    }

    let slices: [Slice]
    /// The month's categories in a sentence: which one took the most.
    let summary: String
    let descriptor: InsightsChartDescriptor

    init(categories: [CategoryTotal], moneyFormat: MoneyFormat) {
        var runningTotal = 0.0
        slices = categories.map { category in
            let value = NSDecimalNumber(decimal: category.amount).doubleValue
            runningTotal += value
            return Slice(
                category: category,
                value: value,
                upperBound: runningTotal,
                amountText: moneyFormat.currencyString(from: category.amount),
                shareText: category.formattedShare
            )
        }

        if let largest = slices.first {
            summary = String(localized: "Largest: \(largest.category.categoryName), \(largest.shareText) of spending.")
        } else {
            summary = ""
        }

        descriptor = InsightsChartDescriptor(
            title: String(localized: "Spending by category"),
            summary: summary,
            xAxisTitle: String(localized: "Category"),
            categories: slices.map(\.category.categoryName),
            yAxisTitle: String(localized: "Spent"),
            series: [
                InsightsChartDescriptor.Series(
                    name: String(localized: "Spent"),
                    points: slices.map {
                        InsightsChartDescriptor.Point(
                            category: $0.category.categoryName,
                            value: $0.value,
                            valueText: $0.figuresText
                        )
                    }
                ),
            ],
            moneyFormat: moneyFormat
        )
    }

    /// The slice that covers a position along the donut's running total, as the chart's angle
    /// selection reports it.
    func slice(at angleValue: Double) -> Slice? {
        slices.first { angleValue <= $0.upperBound }
    }

    /// The position along the donut's running total under a tap, or `nil` when the tap is off the
    /// ring — in the hole or outside it.
    ///
    /// The donut fills the largest circle centred in `size`, starts at twelve o'clock, and runs
    /// clockwise, which is how Swift Charts draws a `SectorMark`.
    func angleValue(at location: CGPoint, in size: CGSize, innerRadiusRatio: Double) -> Double? {
        let outerRadius = min(size.width, size.height) / 2
        let dx = location.x - size.width / 2
        let dy = location.y - size.height / 2
        let distance = (dx * dx + dy * dy).squareRoot()
        guard outerRadius > 0, distance >= outerRadius * innerRadiusRatio, distance <= outerRadius else {
            return nil
        }
        // Clockwise from twelve o'clock, in 0..<2π. Screen y grows downwards.
        var angle = atan2(dx, -dy)
        if angle < 0 {
            angle += 2 * .pi
        }
        return angle / (2 * .pi) * (slices.last?.upperBound ?? 0)
    }

    /// The slice for a category name, if the month has it.
    func slice(named name: String) -> Slice? {
        slices.first { $0.id == name }
    }
}
