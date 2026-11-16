import SwiftUI
import ZentriCore

/// The parser engine choice, with a sentence on each and the on-device model's status.
struct ParserStepView: View {
    private let model: OnboardingModel

    init(model: OnboardingModel) {
        self.model = model
    }

    var body: some View {
        OnboardingStepLayout(
            "How should Zentri read messages?",
            message: "This is how a message becomes a transaction. You can change it at any time in Settings, under Parsing."
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(ParserMode.allCases, id: \.self) { mode in
                    OnboardingChoiceRow(isSelected: model.parserMode == mode) {
                        model.parserMode = mode
                    } label: {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(title(for: mode))
                                .font(.body)
                                .foregroundStyle(Theme.ink)
                            Text(detail(for: mode))
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                    }
                    .accessibilityIdentifier("onboarding.parser.\(mode.rawValue)")
                }
            }

            ParserAvailabilityView(availability: model.availability)
        }
    }

    private func title(for mode: ParserMode) -> LocalizedStringResource {
        switch mode {
        case .rules: "Rules"
        case .foundationModels: "Foundation Models"
        case .hybrid: "Hybrid"
        }
    }

    private func detail(for mode: ParserMode) -> LocalizedStringResource {
        switch mode {
        case .rules: "Your own patterns. Fast, predictable, and fully offline."
        case .foundationModels: "Apple Intelligence reads each message. Needs a supported device."
        case .hybrid: "Rules first, then the on-device model when no rule matches."
        }
    }
}

#Preview {
    ScrollView {
        ParserStepView(model: OnboardingModel())
    }
    .ambientBackground()
}
