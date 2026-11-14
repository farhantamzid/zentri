import SwiftUI

/// The first screen: what Zentri does, and the privacy statement behind it.
struct WelcomeStepView: View {
    var body: some View {
        OnboardingStepLayout(
            "Welcome to Zentri",
            message: "Zentri turns the bank messages you share with it into a clear picture of your money."
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                OnboardingFeatureRow(
                    symbolName: "iphone",
                    title: "On-device only",
                    detail: "Messages, transactions, and rules stay on this iPhone."
                )
                OnboardingFeatureRow(
                    symbolName: "person.crop.circle.badge.xmark",
                    title: "No account",
                    detail: "There is nothing to sign up for and nowhere to log in."
                )
                OnboardingFeatureRow(
                    symbolName: "chart.bar.xaxis",
                    title: "No analytics",
                    detail: "Zentri collects no usage data and sends nothing anywhere."
                )
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: .rect(cornerRadius: Theme.Radius.card))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Privacy"))
        }
    }
}

#Preview {
    ScrollView {
        WelcomeStepView()
    }
    .background { Theme.canvas.ignoresSafeArea() }
}
