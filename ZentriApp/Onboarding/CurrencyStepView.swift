import SwiftUI
import ZentriCore

/// Currency and number grouping, with live examples of how each grouping looks.
///
/// The preview amount reads the flow's `\.moneyFormat` override, so it re-formats the moment a
/// currency or grouping changes.
struct CurrencyStepView: View {
    private let model: OnboardingModel

    /// The smallest a currency tile may get, grown with the text so a large Dynamic Type size
    /// drops to fewer columns instead of clipping the code.
    @ScaledMetric(relativeTo: .footnote) private var tileMinimumWidth: CGFloat = 96

    private var currencyColumns: [GridItem] {
        // Capped so the largest text sizes keep two columns rather than one very tall column.
        [GridItem(.adaptive(minimum: min(tileMinimumWidth, 160)), spacing: Theme.Spacing.sm)]
    }

    init(model: OnboardingModel) {
        self.model = model
    }

    var body: some View {
        OnboardingStepLayout(
            "Choose your currency",
            message: "Amounts are shown in this currency everywhere in the app. Changing it later never converts what you have already recorded."
        ) {
            SectionCard("Currency") {
                LazyVGrid(columns: currencyColumns, spacing: Theme.Spacing.sm) {
                    ForEach(model.currencyCodes, id: \.self) { code in
                        OnboardingCurrencyTile(code: code, isSelected: model.currencyCode == code) {
                            model.currencyCode = code
                        }
                    }
                }
            }

            SectionCard("Number grouping") {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(NumberGrouping.allCases, id: \.self) { grouping in
                        OnboardingGroupingRow(
                            grouping: grouping,
                            currencyCode: model.currencyCode,
                            isSelected: model.numberGrouping == grouping
                        ) {
                            model.numberGrouping = grouping
                        }
                    }
                }
            }

            SectionCard("Preview") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    MoneyText(1_000_000)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ink)
                    Text("This is how a balance will look.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        CurrencyStepView(model: OnboardingModel())
    }
    .ambientBackground()
}
