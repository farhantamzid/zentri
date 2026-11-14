import SwiftUI

/// The screen for the step the model is on.
///
/// The flow owns the chrome — progress, Back, Continue — so each step is only its own content.
struct OnboardingStepView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        switch model.step {
        case .welcome:
            WelcomeStepView()
        case .currency:
            CurrencyStepView(model: model)
        case .account:
            AccountStepView(model: model)
        case .parser:
            ParserStepView(model: model)
        case .rules:
            RulesStepView(onContinue: model.advance)
        case .shortcuts:
            ShortcutsStepView()
        case .faceID:
            FaceIDStepView(model: model)
        }
    }
}
