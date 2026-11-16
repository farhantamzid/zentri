import SwiftUI

/// What this calendar month took in, paid out, and netted, over a bar of spent against received.
///
/// The net is the income minus the spend, so the three figures always agree with each other and
/// with the Insights tab, which reads the same month period. Each figure rolls into place the first
/// time the card appears.
struct MonthSummaryCard: View {
    private let spent: Decimal
    private let received: Decimal
    private let net: Decimal

    @Environment(\.moneyFormat) private var moneyFormat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    init(spent: Decimal, received: Decimal, net: Decimal) {
        self.spent = spent
        self.received = received
        self.net = net
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("This month")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(Date.now, format: .dateTime.month(.wide))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .foregroundStyle(Theme.ink)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) { figures }
                VStack(alignment: .leading, spacing: Theme.Spacing.md) { figures }
            }
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 14)

            ratioBar
        }
        .glassCard()
        .onAppear {
            guard !appeared else { return }
            withAnimation(Theme.Motion.settle.delay(0.1)) {
                appeared = true
            }
        }
    }

    @ContentBuilder
    private var figures: some View {
        figure("Spent", amount: spent, color: Theme.spending, identifier: "overview.month.spent")
        figure("Received", amount: received, color: Theme.income, identifier: "overview.month.received")
        figure("Net", amount: net, color: Theme.ink, identifier: "overview.month.net")
    }

    private func figure(
        _ title: LocalizedStringResource,
        amount: Decimal,
        color: Color,
        identifier: String
    ) -> some View {
        let shown = appeared || reduceMotion ? amount : 0
        return VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
            MoneyText(shown)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(reduceMotion ? .identity : .numericText(value: NSDecimalNumber(decimal: shown).doubleValue))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(String(localized: title)) \(moneyFormat.currencyString(from: amount))"))
        .accessibilityIdentifier(identifier)
    }

    /// Spent against received as two bars that share the card's width.
    private var ratioBar: some View {
        let total = spent + received
        let spentShare = total > 0 ? NSDecimalNumber(decimal: spent / total).doubleValue : 0
        return GeometryReader { proxy in
            let width = max(0, proxy.size.width - 3)
            HStack(spacing: 3) {
                Capsule()
                    .fill(Theme.spending)
                    .frame(width: appeared || reduceMotion ? width * spentShare : 0)
                Capsule()
                    .fill(Theme.income)
                    .frame(width: appeared || reduceMotion ? width * (total > 0 ? 1 - spentShare : 0) : 0)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

#Preview {
    MonthSummaryCard(spent: 1_250, received: 5_000, net: 3_750)
        .padding()
        .ambientBackground()
}
