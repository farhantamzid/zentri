import SwiftUI

/// The common shape of an onboarding step: a scrolling column with a title, an optional
/// explanation, and the step's own controls.
///
/// Every step scrolls, so a long explanation or a large Dynamic Type size never clips content.
struct OnboardingStepLayout<Content: View>: View {
    private let title: LocalizedStringResource
    private let message: LocalizedStringResource?
    @ContentBuilder let content: Content

    init(
        _ title: LocalizedStringResource,
        message: LocalizedStringResource? = nil,
        @ContentBuilder content: () -> Content
    ) {
        self.title = title
        self.message = message
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.ink)
                    if let message {
                        Text(message)
                            .font(.body)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
    }
}

#Preview {
    OnboardingStepLayout("Welcome to Zentri", message: "Everything stays on this iPhone.") {
        Text("Step content")
    }
    .background { Theme.canvas.ignoresSafeArea() }
}
