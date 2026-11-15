import Foundation
import Observation
import ZentriCore

/// Currency, number grouping, and the Face ID lock, as Settings › Appearance changes them.
///
/// Grouping applies the moment it is picked. A new currency is only staged: the screen asks for
/// confirmation first, because the stored amounts stay as they are — only the symbol changes. Saving
/// goes through `apply`, which the app wires to `AppState.updateSettings(_:)` so the widget snapshot
/// follows; every money label re-renders from the observed settings.
///
/// Face ID only turns on after the device's check passes, so nobody can lock themselves out of the
/// app on a device that cannot check them; turning it off needs no check, since the person is
/// already in.
@MainActor
@Observable
final class AppearanceSettingsModel {
    /// A currency the person picked and has not confirmed yet.
    var pendingCurrencyCode: String?
    /// Why the last save failed, for the screen's alert.
    var failureMessage: LocalizedStringResource?
    /// Counts saved changes, which the save haptic watches.
    private(set) var savedCount = 0
    /// Why Face ID could not be turned on, shown under the toggle.
    private(set) var faceIDMessage: LocalizedStringResource?
    /// Whether the check that turns Face ID on is running.
    private(set) var isCheckingFaceID = false

    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let biometric: any BiometricAuthenticating
    @ObservationIgnored private let apply: @MainActor (AppSettings) async throws -> Void

    init(
        settingsStore: SettingsStore,
        biometric: any BiometricAuthenticating,
        apply: @escaping @MainActor (AppSettings) async throws -> Void
    ) {
        self.settingsStore = settingsStore
        self.biometric = biometric
        self.apply = apply
    }

    /// The supported currencies in the order the picker shows them.
    var currencyCodes: [String] { CurrencyCatalog.supportedCurrencyCodes }

    /// The saved settings, or the defaults while none are loaded.
    private var settings: AppSettings {
        settingsStore.settings ?? .defaultValue
    }

    /// The saved currency. Picking a different one stages it for confirmation instead of saving.
    var currencyCode: String {
        get { settings.currencyCode }
        set {
            guard newValue != settings.currencyCode else { return }
            pendingCurrencyCode = newValue
        }
    }

    /// The saved grouping. Picking a different one saves it straight away.
    var numberGrouping: NumberGrouping {
        get { settings.numberGrouping }
        set {
            guard newValue != settings.numberGrouping else { return }
            Task { await setGrouping(newValue) }
        }
    }

    /// Saves a new grouping.
    func setGrouping(_ grouping: NumberGrouping) async {
        var updated = settings
        updated.numberGrouping = grouping
        await save(updated)
    }

    /// Saves the confirmed currency. Amounts are not converted.
    ///
    /// The code is passed in rather than read from ``pendingCurrencyCode``: the confirmation dialog
    /// clears its item before the button's action runs.
    func confirmCurrencyChange(to currencyCode: String) async {
        pendingCurrencyCode = nil
        var updated = settings
        updated.currencyCode = currencyCode
        await save(updated)
    }

    /// The saved lock setting. Turning it on runs the device check first.
    var faceIDEnabled: Bool {
        get { settings.faceIDEnabled }
        set {
            guard newValue != settings.faceIDEnabled, !isCheckingFaceID else { return }
            Task { await setFaceIDEnabled(newValue) }
        }
    }

    /// Saves the lock setting; turning it on saves only after the device check passes.
    func setFaceIDEnabled(_ enabled: Bool) async {
        faceIDMessage = nil
        if enabled {
            guard biometric.canAuthenticate() else {
                faceIDMessage = "Set up Face ID or a passcode in the Settings app to lock Zentri."
                return
            }
            isCheckingFaceID = true
            let passed = await biometric.authenticate()
            isCheckingFaceID = false
            guard passed else {
                faceIDMessage = "Face ID didn't confirm it's you, so the lock is still off."
                return
            }
        }
        var updated = settings
        updated.faceIDEnabled = enabled
        await save(updated)
    }

    /// Drops the staged currency, keeping the saved one.
    func cancelCurrencyChange() {
        pendingCurrencyCode = nil
    }

    private func save(_ updated: AppSettings) async {
        do {
            try await apply(updated)
            savedCount += 1
        } catch {
            failureMessage = "Zentri couldn't save your settings. Try again."
        }
    }
}
