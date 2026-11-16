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
            VStack(spacing: 2) {
                Text(CurrencyCatalog.symbol(for: code))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.ink)
                Text(code)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryInk)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(
                isSelected ? Theme.accentSoft : Theme.glass,
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Theme.glassBorder, lineWidth: 1.5)
            }
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(Theme.Motion.snap, value: isSelected)
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
