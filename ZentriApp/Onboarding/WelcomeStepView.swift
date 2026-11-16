import SwiftUI

/// The first screen: what Zentri does, and the privacy statement behind it.
struct WelcomeStepView: View {
    var body: some View {
        OnboardingStepLayout(
            "Welcome to Zentri",
            message: "Zentri turns the bank messages you share with it into a clear picture of your money."
            ,
            leading: { ZentriMark().riseIn(delay: 0.1) }
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
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface()
            .riseIn(delay: 0.2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Privacy"))
        }
    }
}

/// The app's mark: a white "Z" on a deep teal tile.
struct ZentriMark: View {
    var body: some View {
        Text(verbatim: "Z")
            .font(.system(size: 40, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 76, height: 76)
            .background(
                LinearGradient(
                    colors: [Color(light: 0x147A73, dark: 0x147A73), Color(light: 0x0E5F5A, dark: 0x0E5F5A)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: Color(light: 0x0E5F5A, dark: 0x0E5F5A).opacity(0.5), radius: 15, y: 14)
            .accessibilityHidden(true)
    }
}

#Preview {
    ScrollView {
        WelcomeStepView()
    }
    .ambientBackground()
}
