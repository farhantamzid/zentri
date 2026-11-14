import SwiftUI

/// A selectable row on an onboarding step.
///
/// The whole row is the button, so the tap target is at least 44 points tall however long the
/// label runs. The selection is carried by the checkmark and the `isSelected` trait as well as the
/// border, so it does not depend on color alone.
struct OnboardingChoiceRow<Label: View>: View {
    private let isSelected: Bool
    private let action: () -> Void
    @ContentBuilder let label: Label

    init(isSelected: Bool, action: @escaping () -> Void, @ContentBuilder label: () -> Label) {
        self.isSelected = isSelected
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                label
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.accent : Theme.secondaryInk)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(.regularMaterial, in: .rect(cornerRadius: Theme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        isSelected ? Theme.accent : Theme.secondaryInk.opacity(0.35),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .contentShape(.rect(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.sm) {
        OnboardingChoiceRow(isSelected: true, action: {}) {
            VStack(alignment: .leading) {
                Text("Western")
                Text("1,000,000.00")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        OnboardingChoiceRow(isSelected: false, action: {}) {
            Text("Indian")
        }
    }
    .padding()
    .background(Theme.canvas)
}
