import SwiftUI

/// An icon, a heading, and a sentence, for the short explanation lists onboarding shows.
///
/// The pieces are combined into one VoiceOver element, so a reader hears the heading and its
/// explanation together instead of three unrelated fragments.
struct OnboardingFeatureRow: View {
    private let symbolName: String
    private let title: LocalizedStringResource
    private let detail: LocalizedStringResource

    init(symbolName: String, title: LocalizedStringResource, detail: LocalizedStringResource) {
        self.symbolName = symbolName
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accentSoft, in: .rect(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingFeatureRow(
        symbolName: "iphone",
        title: "On-device only",
        detail: "Messages, transactions, and rules stay on this iPhone."
    )
    .padding()
    .background(Theme.canvas)
}
