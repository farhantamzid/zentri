import SwiftUI

/// The common shape of an onboarding step: a scrolling column with a title, an optional
/// explanation, and the step's own controls.
///
/// Every step scrolls, so a long explanation or a large Dynamic Type size never clips content.
struct OnboardingStepLayout<Leading: View, Content: View>: View {
    private let title: LocalizedStringResource
    private let message: LocalizedStringResource?
    private let leading: Leading
    @ContentBuilder let content: Content

    init(
        _ title: LocalizedStringResource,
        message: LocalizedStringResource? = nil,
        @ViewBuilder leading: () -> Leading,
        @ContentBuilder content: () -> Content
    ) {
        self.title = title
        self.message = message
        self.leading = leading()
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                leading
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .kerning(-0.6)
                        .foregroundStyle(Theme.ink)
                    if let message {
                        Text(message)
                            .font(.body)
                            .lineSpacing(2)
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

extension OnboardingStepLayout where Leading == EmptyView {
    init(
        _ title: LocalizedStringResource,
        message: LocalizedStringResource? = nil,
        @ContentBuilder content: () -> Content
    ) {
        self.init(title, message: message, leading: { EmptyView() }, content: content)
    }
}

#Preview {
    OnboardingStepLayout("Welcome to Zentri", message: "Everything stays on this iPhone.") {
        Text(verbatim: "Step content")
    }
    .ambientBackground()
}
