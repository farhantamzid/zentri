import SwiftUI

/// The lock screen's buttons: Unlock or Try Again, and — only where no check can pass — Turn Off
/// Lock. Each keeps a 44-point target and stacks, so none is squeezed at large text sizes.
struct PrivacyCoverActions: View {
    let lock: AppLockController
    let onTurnOff: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if lock.status == .unavailable {
                Button("Try Again", action: unlock)
                    .buttonStyle(AccentCapsuleButtonStyle())
                    .accessibilityIdentifier("lock.unlock")
                Button("Turn Off Lock", action: onTurnOff)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: Theme.Layout.minimumTapTarget)
                    .accessibilityIdentifier("lock.turnOff")
            } else {
                Button(lock.status == .failed ? "Try Again" : "Unlock", systemImage: "faceid", action: unlock)
                    .buttonStyle(AccentCapsuleButtonStyle())
                    .disabled(lock.status == .authenticating)
                    .accessibilityIdentifier("lock.unlock")
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func unlock() {
        Task { await lock.unlock() }
    }
}
