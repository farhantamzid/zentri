@testable import ZentriApp

/// A scripted Face ID: whether the device can check its owner, what each check answers, and how
/// many checks ran.
@MainActor
final class StubBiometrics: BiometricAuthenticating {
    var isAvailable: Bool
    /// The answers the next checks give, in order; once used up, every check passes.
    var results: [Bool]
    /// Runs inside a check, before it answers — where a test backgrounds the app mid-prompt.
    var duringAuthentication: (@MainActor () -> Void)?
    private(set) var authenticateCount = 0

    init(isAvailable: Bool = true, results: [Bool] = []) {
        self.isAvailable = isAvailable
        self.results = results
    }

    func canAuthenticate() -> Bool {
        isAvailable
    }

    func authenticate() async -> Bool {
        authenticateCount += 1
        duringAuthentication?()
        return results.isEmpty ? true : results.removeFirst()
    }
}
