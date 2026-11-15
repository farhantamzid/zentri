/// The check a UI test scripts with `-UITestMockBiometrics success|failure`.
///
/// The simulator has no enrolled face, so UI tests replace LocalAuthentication with this. It always
/// reports a device that can check its owner, and answers after a short pause, as the Face ID sheet
/// would, so a test can see the lock before it lifts.
struct UITestBiometrics: BiometricAuthenticating {
    let succeeds: Bool

    func canAuthenticate() -> Bool {
        true
    }

    func authenticate() async -> Bool {
        try? await Task.sleep(for: .seconds(2))
        return succeeds
    }
}
