/// Asks the device's owner to prove who they are.
///
/// The app lock and the Face ID toggle talk to this seam rather than to LocalAuthentication, so
/// unit tests can script the answers and UI tests can run with `-UITestMockBiometrics`.
@MainActor
protocol BiometricAuthenticating {
    /// Whether this device can check its owner at all — Face ID, Touch ID, or the device passcode.
    ///
    /// `false` means no check can ever pass, so the lock must not keep asking.
    func canAuthenticate() -> Bool

    /// Runs one check. Returns `true` only when the owner passed it; a failure, a cancel, or an
    /// error is `false`.
    func authenticate() async -> Bool
}
