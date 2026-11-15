import Charts
import SwiftUI
import ZentriCore

/// The donut, the selected slice's figures, and the way to its transactions.
///
/// Tapping a slice, or pressing and dragging around the donut, names its category, amount, and share
/// in the middle and offers a button to its transactions; the selection stays after the finger
/// lifts, and tapping or pressing the same slice again clears it. Each slice announces its category and figures, the chart offers VoiceOver
/// an audio graph and data table, and the summary beneath it names the largest category in words.
/// The slices follow the ranked list's order and colors, and the list names them, so the chart
/// never relies on color alone.
struct CategoryDonutChartContent: View {
    let data: CategoryDonutChartData
    let onSelect: @MainActor (CategoryTotal) -> Void

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220
    @State private var touchedAngle: Double?
    @State private var selectedName: String?
    @State private var chartSize = CGSize.zero
    /// When the press-driven angle selection last reported a slice. A press that ends without moving
    /// can also end as a tap, which must not undo the selection the press just made.
    @State private var lastPressAt = Date.distantPast

    /// The hole's radius as a fraction of the donut's.
    private let innerRadiusRatio = 0.62

    var body: some View {
        let selected = selectedName.flatMap(data.slice(named:))
        VStack(spacing: Theme.Spacing.md) {
            Chart(data.slices) { slice in
                SectorMark(
                    angle: .value("Amount", slice.value),
                    innerRadius: .ratio(innerRadiusRatio),
                    angularInset: 1.5
                )
                .cornerRadius(Theme.Spacing.xs)
                .foregroundStyle(Theme.categoryColor(for: slice.category.colorToken))
                .opacity(selected == nil || selected?.id == slice.id ? 1 : 0.35)
                .accessibilityLabel(Text(slice.category.categoryName))
                .accessibilityValue(Text(slice.figuresText))
            }
            .chartAngleSelection(value: $touchedAngle)
            .simultaneousGesture(SpatialTapGesture().onEnded(selectSlice))
            .frame(height: chartHeight)
            .onGeometryChange(for: CGSize.self, of: \.size) { chartSize = $0 }
            .overlay {
                CategoryDonutCenterLabel(slice: selected)
                    .frame(maxWidth: chartHeight * 0.45)
            }
            .chartReveal()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Spending by category")
            .accessibilityChartDescriptor(data.descriptor)
            .accessibilityIdentifier("insights.categoryChart")
            .onChange(of: touchedAngle, updateSelection)
            .sensoryFeedback(.selection, trigger: selectedName)

            Text(data.summary)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("insights.categoryChart.summary")

            if let selected, selected.category.categoryID != nil {
                Button(action: showSelected) {
                    Label("Show \(selected.category.categoryName) Transactions", systemImage: "list.bullet")
                        .frame(minHeight: Theme.Layout.minimumTapTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("insights.categoryChart.show")
            }
        }
    }

    private func updateSelection(from oldValue: Double?, to newValue: Double?) {
        if newValue != nil {
            lastPressAt = .now
        }
        selectedName = ChartSelectionRule.selection(
            current: selectedName,
            touched: newValue.flatMap(data.slice(at:))?.id,
            touchBegan: oldValue == nil
        )
    }

    /// The angle selection only answers a press, so a plain tap is resolved from the donut's
    /// geometry; tapping the selected slice again clears it, as a new press does.
    private func selectSlice(_ tap: SpatialTapGesture.Value) {
        guard Date.now.timeIntervalSince(lastPressAt) > 0.5 else { return }
        let angleValue = data.angleValue(at: tap.location, in: chartSize, innerRadiusRatio: innerRadiusRatio)
        guard let slice = angleValue.flatMap(data.slice(at:)) else { return }
        selectedName = ChartSelectionRule.selection(current: selectedName, touched: slice.id, touchBegan: true)
    }

    private func showSelected() {
        guard let category = selectedName.flatMap(data.slice(named:))?.category else { return }
        onSelect(category)
    }
}
