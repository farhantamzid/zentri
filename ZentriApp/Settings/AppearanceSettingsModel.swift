import Foundation
import Observation
import ZentriCore

/// Currency and number grouping, as Settings › Appearance changes them.
///
/// Grouping applies the moment it is picked. A new currency is only staged: the screen asks for
/// confirmation first, because the stored amounts stay as they are — only the symbol changes. Saving
/// goes through `apply`, which the app wires to `AppState.updateSettings(_:)` so the widget snapshot
/// follows; every money label re-renders from the observed settings.
@MainActor
@Observable
final class AppearanceSettingsModel {
    /// A currency the person picked and has not confirmed yet.
    var pendingCurrencyCode: String?
    /// Why the last save failed, for the screen's alert.
    var failureMessage: LocalizedStringResource?
    /// Counts saved changes, which the save haptic watches.
    private(set) var savedCount = 0

    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let apply: @MainActor (AppSettings) async throws -> Void

    init(settingsStore: SettingsStore, apply: @escaping @MainActor (AppSettings) async throws -> Void) {
        self.settingsStore = settingsStore
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

    /// Saves the staged currency. Amounts are not converted.
    func confirmCurrencyChange() async {
        guard let pendingCurrencyCode else { return }
        self.pendingCurrencyCode = nil
        var updated = settings
        updated.currencyCode = pendingCurrencyCode
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
