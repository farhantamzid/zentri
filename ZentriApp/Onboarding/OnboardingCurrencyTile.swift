import SwiftUI
import ZentriCore

/// One currency in the picker: its symbol, its code, and whether it is the chosen one.
///
/// The tile is the button, so the tap target is the whole tile. VoiceOver hears the code and the
/// currency's name, and the selected tile carries the selected trait rather than relying on its
/// border color.
struct OnboardingCurrencyTile: View {
    private let code: String
    private let isSelected: Bool
    private let action: () -> Void

    @Environment(\.locale) private var locale

    init(code: String, isSelected: Bool, action: @escaping () -> Void) {
        self.code = code
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Text(CurrencyCatalog.symbol(for: code))
                    .font(.title3)
                    .foregroundStyle(Theme.ink)
                Text(code)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                isSelected ? Theme.accent.opacity(0.14) : Color.clear,
                in: .rect(cornerRadius: Theme.Radius.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        isSelected ? Theme.accent : Theme.secondaryInk.opacity(0.35),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    // A tick as well as the tint and border, so selection does not rely on color.
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                        .padding(Theme.Spacing.xs)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(code))
        .accessibilityValue(Text(locale.localizedString(forCurrencyCode: code) ?? code))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("onboarding.currency.\(code)")
    }
}

#Preview {
    HStack {
        OnboardingCurrencyTile(code: "BDT", isSelected: true, action: {})
        OnboardingCurrencyTile(code: "USD", isSelected: false, action: {})
    }
    .padding()
    .background(Theme.canvas)
}
