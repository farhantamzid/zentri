import SwiftUI

/// The Back and Continue controls pinned under every onboarding step.
///
/// Both buttons keep a 44-point target, the primary action stays in the same place on every step,
/// and a commit failure is reported here rather than inside a step so it cannot scroll out of view.
/// At accessibility text sizes the two buttons stack instead of squeezing one another, so the
/// Continue label never hyphenates.
struct OnboardingFooter: View {
    private let canGoBack: Bool
    private let canContinue: Bool
    private let errorMessage: LocalizedStringResource?
    private let onBack: () -> Void
    private let onContinue: () -> Void

    init(
        canGoBack: Bool,
        canContinue: Bool,
        errorMessage: LocalizedStringResource? = nil,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.canGoBack = canGoBack
        self.canContinue = canContinue
        self.errorMessage = errorMessage
        self.onBack = onBack
        self.onContinue = onContinue
    }

    var body: some View {
        let backButton = Button(action: onBack) {
            Text("Back")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 22)
                .frame(minHeight: 50)
                .background(Theme.fill, in: .capsule)
        }
        .buttonStyle(PressableStyle(scale: 0.95))
        .accessibilityIdentifier("onboarding.back")

        let continueButton = Button(action: onContinue) {
            Text("Continue")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(AccentCapsuleButtonStyle())
        .disabled(!canContinue)
        .accessibilityIdentifier("onboarding.continue")

        VStack(spacing: Theme.Spacing.sm) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.spending)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.md) {
                    if canGoBack {
                        backButton
                    }
                    continueButton
                }
                VStack(spacing: Theme.Spacing.sm) {
                    if canGoBack {
                        backButton
                    }
                    continueButton
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 14)
        .padding(.bottom, Theme.Spacing.sm)
    }
}

#Preview {
    OnboardingFooter(canGoBack: true, canContinue: false, onBack: {}, onContinue: {})
}
