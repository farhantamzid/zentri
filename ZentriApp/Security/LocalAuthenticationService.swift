import Foundation
import LocalAuthentication

/// The device's own check: Face ID, falling back to the passcode.
///
/// The passcode fallback is deliberate. Biometrics alone can lock out after repeated failures, or
/// stop working while the person wears a mask, and the lock must never strand anyone outside their
/// own data. Each call uses a fresh context, so a cancelled prompt never leaves a stale one behind.
struct LocalAuthenticationService: BiometricAuthenticating {
    func canAuthenticate() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        let reason = String(localized: "Unlock Zentri to see your finances.")
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
