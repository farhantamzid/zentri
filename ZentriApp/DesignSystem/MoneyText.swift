import SwiftUI
import ZentriCore

extension MoneyFormat {
    /// The formatting used until settings are available: the app's default currency and grouping.
    static let defaultValue = MoneyFormat(
        currencyCode: AppSettings.defaultValue.currencyCode,
        grouping: AppSettings.defaultValue.numberGrouping
    )
}

extension EnvironmentValues {
    /// The live money formatting, set at the root from the current settings.
    ///
    /// The shared constant default keeps the entry stable when no root has set it, which the
    /// onboarding and recovery screens rely on.
    @Entry var moneyFormat: MoneyFormat = .defaultValue
}

/// An amount formatted with the app's currency and number grouping.
///
/// The formatting comes from the environment, so a settings change re-renders every amount
/// without each screen reading `AppSettings`. Amounts use tabular digits so columns line up and a
/// changing balance does not jitter; the numeric transition is skipped when Reduce Motion is on.
struct MoneyText: View {
    /// Which part of a money value to show.
    enum Kind {
        /// The amount with its currency symbol, e.g. `-$1,234.50`.
        case currency
        /// The grouped amount without a symbol, for counts and shares.
        case number
    }

    private let amount: Decimal
    private let kind: Kind

    @Environment(\.moneyFormat) private var moneyFormat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ amount: Decimal, kind: Kind = .currency) {
        self.amount = amount
        self.kind = kind
    }

    var body: some View {
        Text(text)
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
    }

    private var text: String {
        switch kind {
        case .currency: moneyFormat.currencyString(from: amount)
        case .number: moneyFormat.numberString(from: amount)
        }
    }
}

#Preview("Currencies") {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        MoneyText(1_234_567.89)
        MoneyText(1_234_567.89, kind: .number)
    }
    .padding()
    .background(Theme.canvas)
}
