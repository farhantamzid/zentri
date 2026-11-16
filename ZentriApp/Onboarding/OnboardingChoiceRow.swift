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

                // A radio: the ring takes the accent and the dot springs in.
                Circle()
                    .strokeBorder(isSelected ? Theme.accent : Theme.tertiaryInk, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 12, height: 12)
                            .scaleEffect(isSelected ? 1 : 0.01)
                    }
                    .animation(Theme.Motion.snap, value: isSelected)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
            .padding(14)
            .glassSurface(cornerRadius: Theme.Radius.group, fill: isSelected ? Theme.accentSoft : Theme.glass, shadow: false)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.group, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 1.5)
            }
            .animation(.easeOut(duration: 0.3), value: isSelected)
            .contentShape(.rect(cornerRadius: Theme.Radius.group))
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
                Text(verbatim: "1,000,000.00")
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
