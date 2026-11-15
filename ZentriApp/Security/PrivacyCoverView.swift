import SwiftUI

/// What covers Zentri while it is locked, or while it is off screen with the lock on.
///
/// Off screen it shows only the app's name, which is what the app switcher's snapshot keeps. Locked,
/// it offers the way back in for each state: Unlock while waiting, Try Again after a failed or
/// cancelled check, and — on a device that cannot check its owner — an explanation with the choice
/// to turn the lock off, so the person is never stranded and the lock never asks in a loop. It
/// scrolls, so the largest accessibility text sizes keep every control reachable.
struct PrivacyCoverView: View {
    let lock: AppLockController
    /// Turns the lock off; offered only on a device that cannot check its owner.
    let onTurnOff: () -> Void

    var body: some View {
        ScrollView {
            if lock.isLocked {
                ContentUnavailableView {
                    Label("Zentri is locked", systemImage: "lock.fill")
                } description: {
                    Text(message)
                        .accessibilityIdentifier("lock.message")
                } actions: {
                    PrivacyCoverActions(lock: lock, onTurnOff: onTurnOff)
                }
            } else {
                ContentUnavailableView("Zentri", systemImage: "lock.fill")
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.center, for: .alignment)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Theme.canvas.ignoresSafeArea() }
        .tint(Theme.accent)
        .accessibilityIdentifier("lock.cover")
    }

    private var message: LocalizedStringResource {
        switch lock.status {
        case .ready, .authenticating:
            "Unlock with Face ID to see your finances."
        case .failed:
            "Face ID didn't unlock Zentri. Try again."
        case .unavailable:
            lock.turnOffFailed
                ? "Zentri couldn't turn the lock off. Try again."
                : "This iPhone has no Face ID or passcode set up, so Zentri can't check it's you. Set one up in the Settings app, or turn the lock off."
        }
    }
}

#Preview("Locked") {
    PrivacyCoverView(lock: AppLockController(biometric: LocalAuthenticationService(), faceIDEnabled: true), onTurnOff: {})
}

#Preview("Covered") {
    PrivacyCoverView(lock: AppLockController(biometric: LocalAuthenticationService()), onTurnOff: {})
}
