import SwiftUI

/// The optional Face ID lock, off by default.
///
/// Losing the setting would lock the user out of an app they never asked to lock, so it starts off
/// and only turns on when the toggle is tapped and the device's Face ID or passcode check passes.
struct FaceIDStepView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        OnboardingStepLayout(
            "Lock Zentri with Face ID",
            message: "Face ID is optional. It keeps your finances behind the same check you use to unlock your iPhone."
        ) {
            SectionCard {
                Toggle("Require Face ID", isOn: $model.faceIDChoice)
                    .disabled(model.isCheckingFaceID)
                    .frame(minHeight: Theme.Layout.minimumTapTarget)
                    .accessibilityIdentifier("onboarding.faceID.toggle")

                if let message = model.faceIDMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.spending)
                        .accessibilityIdentifier("onboarding.faceID.message")
                }
            }

            Text("iOS checks your face, and Zentri only learns whether the check passed. You can change this later in Settings.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
        }
    }
}

#Preview {
    ScrollView {
        FaceIDStepView(model: OnboardingModel())
    }
    .ambientBackground()
}
