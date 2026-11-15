/// Where the lock screen is in unlocking.
enum AppLockStatus: Equatable, Sendable {
    /// Waiting for a check; the lock asks on its own when the app becomes active.
    case ready
    /// The Face ID sheet is up.
    case authenticating
    /// The last check failed or was cancelled; the lock screen offers a retry.
    case failed
    /// The device has neither biometrics nor a passcode, so no check can pass; the lock screen says
    /// so and offers to turn the lock off instead of asking again.
    case unavailable
}
