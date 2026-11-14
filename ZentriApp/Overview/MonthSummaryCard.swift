import SwiftUI

/// What this calendar month took in, paid out, and netted.
///
/// The net is the income minus the spend, so the three figures always agree with each other and
/// with the Insights tab, which reads the same month period.
struct MonthSummaryCard: View {
    private let spent: Decimal
    private let received: Decimal
    private let net: Decimal

    init(spent: Decimal, received: Decimal, net: Decimal) {
        self.spent = spent
        self.received = received
        self.net = net
    }

    var body: some View {
        SectionCard("This month") {
            VStack(spacing: Theme.Spacing.sm) {
                SummaryRow("Spent", identifier: "overview.month.spent") {
                    MoneyText(spent)
                        .foregroundStyle(Theme.spending)
                }

                Divider()

                SummaryRow("Received", identifier: "overview.month.received") {
                    MoneyText(received)
                        .foregroundStyle(Theme.income)
                }

                Divider()

                SummaryRow("Net", identifier: "overview.month.net") {
                    MoneyText(net)
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }
}

#Preview {
    MonthSummaryCard(spent: 1_250, received: 5_000, net: 3_750)
        .padding()
        .background(Theme.canvas)
}
