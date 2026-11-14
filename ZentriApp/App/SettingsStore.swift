import Foundation
import Observation
import ZentriCore

/// The app's live settings, read from a repository and observed by every screen that formats money
/// or changes a preference.
///
/// `settings == nil` means nothing has been saved yet, which is what shows onboarding. A stored
/// document that cannot be decoded leaves `loadFailure` set so the shell can offer recovery instead
/// of treating a damaged file as a fresh install.
@MainActor
@Observable
final class SettingsStore {
    /// Why the stored settings could not be read.
    enum LoadFailure: Equatable, Sendable {
        /// The stored document exists but is not decodable settings.
        case unreadable
    }

    /// The current settings, or `nil` when none have been saved.
    private(set) var settings: AppSettings?
    /// The failure from the last `load()`, cleared by a successful load, save, or reset.
    private(set) var loadFailure: LoadFailure?

    private let repository: any SettingsRepository
    private let deleteStoredSettings: @MainActor () throws -> Void

    init(
        repository: any SettingsRepository,
        deleteStoredSettings: @escaping @MainActor () throws -> Void
    ) {
        self.repository = repository
        self.deleteStoredSettings = deleteStoredSettings
    }

    /// Reads the stored settings, recording a failure for the recovery screen.
    func load() throws {
        do {
            settings = try repository.load()
            loadFailure = nil
        } catch {
            settings = nil
            loadFailure = .unreadable
            throw error
        }
    }

    /// Replaces the stored settings.
    func save(_ newSettings: AppSettings) throws {
        try repository.save(newSettings)
        settings = newSettings
        loadFailure = nil
    }

    /// Saves the settings that finish onboarding.
    func completeOnboarding(_ newSettings: AppSettings) throws {
        try save(newSettings)
    }

    /// Deletes the stored settings so the app returns to onboarding.
    func reset() throws {
        try deleteStoredSettings()
        settings = nil
        loadFailure = nil
    }
}
