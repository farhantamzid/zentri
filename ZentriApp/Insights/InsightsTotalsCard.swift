import SwiftUI

/// The selected month's headline: what was spent and what was received, side by side.
///
/// Each figure is one accessibility element that names itself, so VoiceOver reads "Spent, $1,000.00"
/// rather than an unlabelled amount.
struct InsightsTotalsCard: View {
    let spent: Decimal
    let received: Decimal

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                figures
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                figures
            }
        }
        .glassCard()
    }

    @ContentBuilder
    private var figures: some View {
        InsightsTotalFigure(title: "Spent", amount: spent, style: Theme.spending)
            .accessibilityIdentifier("insights.totalSpend")
        InsightsTotalFigure(title: "Received", amount: received, style: Theme.income)
            .accessibilityIdentifier("insights.totalIncome")
    }
}

#Preview {
    InsightsTotalsCard(spent: 1_000, received: 5_000)
        .padding()
        .ambientBackground()
}
