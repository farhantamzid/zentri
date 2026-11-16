import SwiftUI
import ZentriCore

/// The last seven days of spending, one bar per day; tapping a bar picks it out and labels its
/// amount.
///
/// The bars grow in with a springy stagger the first time the card appears. Every bar announces its
/// own day and amount, so VoiceOver can move through the week bar by bar, and the chart offers an
/// audio graph and data table (VoiceOver's Chart Details) — every day and its spend — for a person
/// who would rather hear the numbers than the shape. With Reduce Motion on, the bars are simply
/// there.
struct SevenDayChart: View {
    private let days: [DailySpend]

    @Environment(\.moneyFormat) private var moneyFormat
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: Int?

    /// The tallest bar's height; the design's bars top out at 110 points.
    private let maxBarHeight: CGFloat = 104

    init(days: [DailySpend]) {
        self.days = days
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last seven days")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                MoneyText(total)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .foregroundStyle(Theme.ink)

            if days.contains(where: { $0.amount > 0 }) {
                let data = SevenDayChartData(days: days, moneyFormat: moneyFormat, locale: locale)
                bars
                    .padding(.top, 10)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Spending, last seven days")
                    .accessibilityValue(data.weekTable)
                    .accessibilityChartDescriptor(data.descriptor)
            } else {
                ContentUnavailableView("No spending in the last seven days", systemImage: "chart.bar")
            }
        }
        .glassCard()
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var total: Decimal {
        days.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var selectedIndex: Int {
        selected ?? days.count - 1
    }

    private func isLast(_ index: Int) -> Bool {
        index == days.count - 1
    }

    private var bars: some View {
        let maxAmount = max(days.map(\.amount).max() ?? 0, 0.01)
        return HStack(alignment: .bottom, spacing: 12) {
            ForEach(days.indices, id: \.self) { index in
                let day = days[index]
                let isOn = index == selectedIndex
                let fraction = CGFloat(NSDecimalNumber(decimal: day.amount / maxAmount).doubleValue)
                Button {
                    withAnimation(Theme.Motion.snap) {
                        selected = index
                    }
                } label: {
                    VStack(spacing: 6) {
                        // The amount is drawn as an overlay of a fixed-height slot, so a long figure
                        // can spill past its narrow column without widening the chart.
                        Color.clear
                            .frame(height: 14)
                            .overlay(alignment: isLast(index) ? .bottomTrailing : .bottom) {
                                MoneyText(day.amount)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .opacity(isOn ? 1 : 0)
                                    .offset(y: isOn ? 0 : 6)
                            }
                        BarFill(
                            height: fraction * maxBarHeight + 6,
                            color: isOn ? Theme.accent : Theme.accentSoft,
                            delay: Double(index) * 0.045,
                            animate: !reduceMotion
                        )
                        Text(day.date, format: .dateTime.weekday(.narrow))
                            .font(.caption)
                            .fontWeight(isOn ? .bold : .regular)
                            .foregroundStyle(isOn ? Theme.ink : Theme.tertiaryInk)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).month(.abbreviated).day()))
                .accessibilityValue(Text(moneyFormat.currencyString(from: day.amount)))
            }
        }
        // The chart's labels are annotations on a fixed-height drawing; past this size they would
        // crowd the bars out, and VoiceOver reads every bar's day and amount in full regardless.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(height: 154)
    }
}

/// One bar, which springs to its height after a stagger.
private struct BarFill: View {
    let height: CGFloat
    let color: Color
    let delay: Double
    let animate: Bool

    @State private var shownHeight: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .frame(height: shownHeight)
            .animation(.easeOut(duration: 0.3), value: color)
            .onAppear { grow(to: height) }
            .onChange(of: height) { _, newValue in grow(to: newValue) }
    }

    private func grow(to target: CGFloat) {
        guard animate else {
            shownHeight = target
            return
        }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.68).delay(delay)) {
            shownHeight = target
        }
    }
}

#Preview {
    SevenDayChart(
        days: (0..<7).map { offset in
            DailySpend(date: .now.addingTimeInterval(Double(offset - 6) * 86_400), amount: Decimal([34, 12, 61, 53, 8, 88, 82][offset]))
        }
    )
    .padding()
    .ambientBackground()
}
