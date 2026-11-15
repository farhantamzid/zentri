import Foundation
import Testing
@testable import ZentriApp

private enum SaveFailure: Error {
    case unwritable
}

private func url(_ text: String) throws -> URL {
    try #require(URL(string: text))
}

/// The Face ID lock: when it locks, covers, asks, and lets a held deep link through.
@MainActor
@Suite
struct AppLockControllerTests {
    @Test func withFaceIDOffTheAppStartsAndStaysUnlocked() async {
        let biometric = StubBiometrics()
        let lock = AppLockController(biometric: biometric, faceIDEnabled: false)

        #expect(!lock.isLocked)
        #expect(!lock.isCovering(sceneIsActive: true))
        // Leaving the screen neither covers nor locks an app the person never asked to lock.
        #expect(!lock.isCovering(sceneIsActive: false))
        lock.lockIfNeeded()
        await lock.sceneDidBecomeActive()

        #expect(!lock.isLocked)
        #expect(biometric.authenticateCount == 0)
    }

    @Test func withFaceIDOnTheAppStartsLockedAndASuccessfulCheckUnlocksIt() async {
        let biometric = StubBiometrics(results: [true])
        let lock = AppLockController(biometric: biometric, faceIDEnabled: true)

        #expect(lock.isLocked)
        #expect(lock.isCovering(sceneIsActive: true))

        await lock.sceneDidBecomeActive()

        #expect(!lock.isLocked)
        #expect(lock.status == .ready)
        #expect(!lock.isCovering(sceneIsActive: true))
        #expect(biometric.authenticateCount == 1)
    }

    @Test func aFailedOrCancelledCheckStaysLockedAndOnlyARetryAsksAgain() async {
        let biometric = StubBiometrics(results: [false, true])
        let lock = AppLockController(biometric: biometric, faceIDEnabled: true)

        await lock.sceneDidBecomeActive()
        #expect(lock.isLocked)
        #expect(lock.status == .failed)

        // The Face ID sheet makes the scene inactive and active again; that must not prompt again, or a
        // cancel would bring the sheet straight back.
        await lock.sceneDidBecomeActive()
        #expect(biometric.authenticateCount == 1)
        #expect(lock.isLocked)

        // The retry button asks again.
        await lock.unlock()
        #expect(biometric.authenticateCount == 2)
        #expect(!lock.isLocked)
    }

    @Test func backgroundingLocksWhenFaceIDIsOnAndTheNextReturnAsksAgain() async {
        let biometric = StubBiometrics()
        let lock = AppLockController(biometric: biometric, faceIDEnabled: true)
        await lock.sceneDidBecomeActive()
        #expect(!lock.isLocked)

        // Inactive (the app switcher) covers without locking; the snapshot never shows data.
        #expect(lock.isCovering(sceneIsActive: false))
        #expect(!lock.isLocked)

        lock.lockIfNeeded()
        #expect(lock.isLocked)
        #expect(lock.isCovering(sceneIsActive: true))

        await lock.sceneDidBecomeActive()
        #expect(biometric.authenticateCount == 2)
        #expect(!lock.isLocked)
    }

    @Test func aDeviceThatCannotCheckItsOwnerShowsTheUnavailableStateWithoutLooping() async throws {
        let biometric = StubBiometrics(isAvailable: false)
        let lock = AppLockController(biometric: biometric, faceIDEnabled: true)

        await lock.sceneDidBecomeActive()
        #expect(lock.status == .unavailable)
        #expect(lock.isLocked)

        await lock.sceneDidBecomeActive()
        await lock.unlock()
        #expect(biometric.authenticateCount == 0)
        #expect(lock.status == .unavailable)

        // The way out: turning the lock off, which saves the setting first.
        var saved = 0
        await lock.turnOff { saved += 1 }
        #expect(saved == 1)
        #expect(!lock.faceIDEnabled)
        #expect(!lock.isLocked)
    }

    @Test func turningTheLockOffFromTheLockScreenNeedsTheUnavailableStateAndASuccessfulSave() async {
        let available = AppLockController(biometric: StubBiometrics(results: [false]), faceIDEnabled: true)
        await available.sceneDidBecomeActive()
        #expect(available.status == .failed)

        // A device that can check its owner never offers a way around the check.
        await available.turnOff { Issue.record("Turning off must not save while a check is possible.") }
        #expect(available.isLocked)
        #expect(available.faceIDEnabled)

        let unavailable = AppLockController(biometric: StubBiometrics(isAvailable: false), faceIDEnabled: true)
        await unavailable.sceneDidBecomeActive()
        await unavailable.turnOff { throw SaveFailure.unwritable }
        #expect(unavailable.isLocked)
        #expect(unavailable.faceIDEnabled)
        #expect(unavailable.turnOffFailed)
    }

    @Test func aDeepLinkThatArrivesWhileLockedIsHeldUntilUnlock() async throws {
        let lock = AppLockController(biometric: StubBiometrics(), faceIDEnabled: true)
        let link = try url("zentri://insights")

        #expect(lock.holdIfLocked(link))
        // Nothing is handed out while the lock is up.
        #expect(lock.takePendingURL() == nil)

        await lock.sceneDidBecomeActive()
        #expect(lock.takePendingURL() == link)
        // Delivered once.
        #expect(lock.takePendingURL() == nil)

        // An unlocked app opens links straight away.
        #expect(!lock.holdIfLocked(try url("zentri://overview")))
        #expect(lock.takePendingURL() == nil)
    }

    @Test func turningFaceIDOnDoesNotLockUntilTheAppLeavesAndTurningItOffUnlocks() {
        let lock = AppLockController(biometric: StubBiometrics(), faceIDEnabled: false)

        // The person just passed Face ID to turn it on; locking them out at once would be pointless.
        lock.faceIDEnabled = true
        #expect(!lock.isLocked)
        lock.lockIfNeeded()
        #expect(lock.isLocked)

        lock.faceIDEnabled = false
        #expect(!lock.isLocked)
        #expect(!lock.isCovering(sceneIsActive: false))
    }

    @Test func aCheckThatFinishesAfterTheAppLockedAgainIsIgnored() async {
        let biometric = StubBiometrics(results: [true])
        let lock = AppLockController(biometric: biometric, faceIDEnabled: true)
        // The app goes to the background while the Face ID sheet is up.
        biometric.duringAuthentication = { lock.lockIfNeeded() }

        await lock.sceneDidBecomeActive()

        #expect(lock.isLocked)
        #expect(lock.status == .ready)
    }
}
