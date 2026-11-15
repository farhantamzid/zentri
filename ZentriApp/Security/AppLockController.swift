import Foundation
import Observation

/// The optional Face ID lock: whether the app is locked, covered, or open.
///
/// With the setting on, the app starts locked, so nothing is drawn before the first check; it
/// locks again whenever it goes to the background, and it is covered — not locked — while it is
/// merely inactive, so the app-switcher snapshot never shows a balance. Returning to the foreground
/// asks for Face ID once per lock: the Face ID sheet itself makes the scene inactive and active
/// again, and asking on every activation would bring a cancelled sheet straight back. After a
/// failure the lock screen's retry asks again.
///
/// A device that cannot check its owner at all (no biometrics and no passcode) never asks; the lock
/// screen explains and offers to turn the lock off, which is the only way past it and only exists
/// in that state.
///
/// A `zentri://` link that arrives while locked is held here and handed back once, after unlock.
///
/// The lock is a screen-level concern only: Shortcuts captures run without the UI and never consult
/// it.
@MainActor
@Observable
final class AppLockController {
    /// The check the lock and the Face ID toggle use.
    @ObservationIgnored let biometric: any BiometricAuthenticating

    /// Whether the person turned the lock on. Turning it off unlocks at once; turning it on does
    /// not lock until the app next leaves the screen, because turning it on already passed a check.
    var faceIDEnabled: Bool {
        didSet {
            guard !faceIDEnabled else { return }
            isLocked = false
            status = .ready
            turnOffFailed = false
        }
    }

    /// Whether the lock screen is up.
    private(set) var isLocked: Bool
    /// The lock screen's progress.
    private(set) var status: AppLockStatus = .ready
    /// Whether the last attempt to turn the lock off could not save the setting.
    private(set) var turnOffFailed = false

    /// Whether this lock has already asked on its own; reset each time the app locks.
    @ObservationIgnored private var hasPromptedSinceLock = false
    /// Counts locks, so a check that finishes after the app locked again cannot open it.
    @ObservationIgnored private var lockGeneration = 0
    @ObservationIgnored private var pendingURL: URL?

    /// - Parameters:
    ///   - biometric: The device check.
    ///   - faceIDEnabled: The saved setting at launch. When on, the app starts locked.
    init(biometric: any BiometricAuthenticating, faceIDEnabled: Bool = false) {
        self.biometric = biometric
        self.faceIDEnabled = faceIDEnabled
        isLocked = faceIDEnabled
    }

    /// Whether the privacy cover should hide the app: while locked, and — with the lock on — while
    /// the scene is not active, which is when the app switcher takes its snapshot.
    func isCovering(sceneIsActive: Bool) -> Bool {
        isLocked || (faceIDEnabled && !sceneIsActive)
    }

    /// Locks the app as it goes to the background, if the person turned the lock on.
    func lockIfNeeded() {
        guard faceIDEnabled else { return }
        isLocked = true
        status = .ready
        turnOffFailed = false
        hasPromptedSinceLock = false
        lockGeneration += 1
    }

    /// Asks for Face ID the first time the scene becomes active after locking.
    func sceneDidBecomeActive() async {
        guard isLocked, !hasPromptedSinceLock else { return }
        await unlock()
    }

    /// Runs one check and unlocks when it passes; the lock screen's Unlock and retry buttons call
    /// this.
    func unlock() async {
        guard isLocked, status != .authenticating else { return }
        hasPromptedSinceLock = true
        guard biometric.canAuthenticate() else {
            status = .unavailable
            return
        }
        status = .authenticating
        let generation = lockGeneration
        let passed = await biometric.authenticate()
        // The app may have locked again, or the lock been turned off, while the sheet was up.
        guard generation == lockGeneration, isLocked else { return }
        if passed {
            isLocked = false
            status = .ready
        } else {
            status = .failed
        }
    }

    /// Turns the lock off from the lock screen of a device that cannot check its owner.
    ///
    /// - Parameter save: Saves the setting with the lock off. The lock only lifts once it has.
    func turnOff(saving save: @MainActor () async throws -> Void) async {
        guard isLocked, status == .unavailable else { return }
        do {
            try await save()
            faceIDEnabled = false
        } catch {
            turnOffFailed = true
        }
    }

    /// Holds a deep link that arrived while locked. Returns `false` when the app is unlocked and the
    /// caller should open the link itself.
    func holdIfLocked(_ url: URL) -> Bool {
        guard isLocked else { return false }
        pendingURL = url
        return true
    }

    /// The held deep link, once, after the app unlocks.
    func takePendingURL() -> URL? {
        guard !isLocked, let url = pendingURL else { return nil }
        pendingURL = nil
        return url
    }
}
