import Foundation

/// The check that must pass before the Face ID lock is turned on, wherever it is turned on.
///
/// Settings › Appearance and onboarding both use it, so nobody can switch the lock on — and lock
/// themselves out — on a device that cannot check them, or without passing the check once.
/// Turning the lock off needs no check: the person is already in the app.
@MainActor
struct FaceIDActivation {
    let biometric: any BiometricAuthenticating

    /// Runs the check. Returns `nil` when the lock may turn on, or why it may not.
    func confirm() async -> LocalizedStringResource? {
        guard biometric.canAuthenticate() else {
            return "Set up Face ID or a passcode in the Settings app to lock Zentri."
        }
        guard await biometric.authenticate() else {
            return "Face ID didn't confirm it's you, so the lock is still off."
        }
        return nil
    }
}
