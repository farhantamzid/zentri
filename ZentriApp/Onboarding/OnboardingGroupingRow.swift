import SwiftUI
import ZentriCore

/// One number-grouping option, shown with the live example it produces for the chosen currency.
///
/// The example comes from `MoneyFormat` rather than a hard-coded string, so Western reads
/// `1,000,000.00` and Indian reads `10,00,000.00` in every language while System follows the device.
/// It sits on its own line so the largest text sizes never have to choose between the option's name
/// and its example, and it scales rather than truncating a digit away.
struct OnboardingGroupingRow: View {
    private let grouping: NumberGrouping
    private let currencyCode: String
    private let isSelected: Bool
    private let action: () -> Void

    @Environment(\.locale) private var locale

    init(grouping: NumberGrouping, currencyCode: String, isSelected: Bool, action: @escaping () -> Void) {
        self.grouping = grouping
        self.currencyCode = currencyCode
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        OnboardingChoiceRow(isSelected: isSelected, action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                Text(example)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .accessibilityIdentifier("onboarding.grouping.\(grouping.rawValue)")
    }

    private var title: LocalizedStringResource {
        switch grouping {
        case .system: "System"
        case .western: "Western"
        case .indian: "Indian"
        }
    }

    private var detail: LocalizedStringResource {
        switch grouping {
        case .system: "Follows this device"
        case .western: "Groups of three digits"
        case .indian: "Three digits, then groups of two"
        }
    }

    private var example: String {
        MoneyFormat(currencyCode: currencyCode, grouping: grouping, locale: locale)
            .numberString(from: 1_000_000)
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.sm) {
        ForEach(NumberGrouping.allCases, id: \.self) { grouping in
            OnboardingGroupingRow(
                grouping: grouping,
                currencyCode: "BDT",
                isSelected: grouping == .indian,
                action: {}
            )
        }
    }
    .padding()
    .background(Theme.canvas)
}
