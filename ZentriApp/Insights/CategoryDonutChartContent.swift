import Charts
import SwiftUI
import ZentriCore

/// The donut, the selected slice's figures, and the way to its transactions.
///
/// Tapping a slice, or pressing and dragging around the donut, names its category, amount, and share
/// in the middle and offers a button to its transactions; the selection stays after the finger
/// lifts, a tap in the hole or beside the donut clears it, and the next month starts without one. Each slice announces its category and figures, the chart offers VoiceOver
/// an audio graph and data table, and the summary beneath it names the largest category in words.
/// The slices follow the ranked list's order and colors, and the list names them, so the chart
/// never relies on color alone.
struct CategoryDonutChartContent<Legend: View>: View {
    let data: CategoryDonutChartData
    /// The month's spend without cents, shown in the hole when nothing is selected.
    let totalText: String
    let onSelect: @MainActor (CategoryTotal) -> Void
    let legend: Legend

    /// The donut is a fixed size beside its legend; the ring is the outer 28 percent.
    private let chartHeight: CGFloat = 180
    @State private var touchedAngle: Double?
    @State private var selectedName: String?
    @State private var chartSize = CGSize.zero

    /// The hole's radius as a fraction of the donut's.
    private let innerRadiusRatio = 0.72

    var body: some View {
        let selected = selectedName.flatMap(data.slice(named:))
        VStack(spacing: Theme.Spacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Theme.Spacing.lg) {
                    donut(selected: selected)
                    legend
                        .frame(minWidth: 130)
                }
                VStack(spacing: Theme.Spacing.lg) {
                    donut(selected: selected)
                    legend
                }
            }

            Text(data.summary)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("insights.categoryChart.summary")

            if let selected, selected.category.categoryID != nil {
                Button(action: showSelected) {
                    Label("Show \(selected.category.categoryName) Transactions", systemImage: "list.bullet")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftCapsuleButtonStyle())
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .accessibilityIdentifier("insights.categoryChart.show")
            }
        }
        .animation(Theme.Motion.snap, value: selectedName)
    }

    private func donut(selected: CategoryDonutChartData.Slice?) -> some View {
            Chart(data.slices) { slice in
                SectorMark(
                    angle: .value("Amount", slice.value),
                    innerRadius: .ratio(selected?.id == slice.id ? innerRadiusRatio - 0.08 : innerRadiusRatio),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(Theme.categoryColor(for: slice.category.colorToken))
                .opacity(selected == nil || selected?.id == slice.id ? 1 : 0.35)
                .accessibilityLabel(Text(slice.category.categoryName))
                .accessibilityValue(Text(slice.figuresText))
            }
            .chartAngleSelection(value: $touchedAngle)
            .simultaneousGesture(SpatialTapGesture().onEnded(selectSlice))
            .frame(width: chartHeight, height: chartHeight)
            .onGeometryChange(for: CGSize.self, of: \.size) { chartSize = $0 }
            .overlay {
                CategoryDonutCenterLabel(slice: selected, totalText: totalText)
                    .frame(maxWidth: chartHeight * 0.45)
            }
            .chartReveal()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Spending by category")
            .accessibilityChartDescriptor(data.descriptor)
            .accessibilityIdentifier("insights.categoryChart")
            .onChange(of: touchedAngle, updateSelection)
            .sensoryFeedback(.selection, trigger: selectedName)
    }

    private func updateSelection() {
        selectedName = ChartSelectionRule.selection(
            current: selectedName,
            touched: touchedAngle.flatMap(data.slice(at:))?.id
        )
    }

    /// The angle selection only answers a press, so a plain tap is resolved from the donut's
    /// geometry. A tap on a slice selects it; a tap in the hole or beside the donut clears the
    /// selection. Selecting is idempotent, so a press that also ends as a tap cannot undo itself.
    private func selectSlice(_ tap: SpatialTapGesture.Value) {
        let angleValue = data.angleValue(at: tap.location, in: chartSize, innerRadiusRatio: innerRadiusRatio)
        selectedName = angleValue.flatMap(data.slice(at:))?.id
    }

    private func showSelected() {
        guard let category = selectedName.flatMap(data.slice(named:))?.category else { return }
        onSelect(category)
    }
}
