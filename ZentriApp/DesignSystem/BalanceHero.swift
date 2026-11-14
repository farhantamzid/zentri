import SwiftUI

/// The floating balance card: combined balance, when it was read, and today's spend.
///
/// This is the app's only custom glass surface. Data cards use materials instead, so text never
/// sits on glass on glass. When Reduce Transparency is on, the hero drops the glass and draws on a
/// solid semantic background. The amount uses tabular digits and scales down rather than
/// truncating, so it stays legible at large Dynamic Type sizes.
struct BalanceHero: View {
    private let balance: Decimal
    private let asOf: Date
    private let todaySpend: Decimal

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(balance: Decimal, asOf: Date, todaySpend: Decimal) {
        self.balance = balance
        self.asOf = asOf
        self.todaySpend = todaySpend
    }

    var body: some View {
        GlassEffectContainer(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Combined balance")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)

                MoneyText(balance)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("As of \(asOf, format: .dateTime.month(.abbreviated).day().hour().minute())")
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text("Spent today")
                            MoneyText(todaySpend)
                        }
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Spent today")
                            MoneyText(todaySpend)
                        }
                    }
                }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                reduceTransparency ? .identity : .regular,
                in: .rect(cornerRadius: Theme.Radius.hero)
            )
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: Theme.Radius.hero)
                        .fill(.background)
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.hero)
                                .strokeBorder(.separator)
                        }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    BalanceHero(balance: 12_345.67, asOf: .now, todaySpend: 82.4)
        .padding()
        .background(Theme.canvas)
}
