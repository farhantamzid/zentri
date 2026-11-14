import Foundation
import SwiftData
import ZentriCore

/// The launch-argument switches UI tests use to run the app against throwaway state.
///
/// In `-UITestMode` the app never reads or writes the App Group or the real settings file: the
/// container is in memory, settings come from ``InMemorySettingsRepository``, and the widget
/// snapshot store is inert. The remaining switches decide which fixture state that in-memory store
/// starts in.
enum UITestSupport {
    /// Runs the app against in-memory state instead of the App Group.
    static let modeArgument = "-UITestMode"
    /// Starts with saved fixture settings so the tabs appear instead of onboarding.
    static let skipOnboardingArgument = "-UITestSkipOnboarding"
    /// Seeds the built-in categories and keyword rules.
    static let seedArgument = "-UITestSeed"
    /// Clears the in-memory settings and store state before the test starts.
    static let resetArgument = "-UITestReset"

    /// The settings a UI test starts with when onboarding is skipped.
    static let fixtureSettings = AppSettings.defaultValue

    private static var arguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    /// Whether the app is running for a UI test.
    static var isUITestMode: Bool { arguments.contains(modeArgument) }
    /// Whether the test wants the tabs instead of onboarding.
    static var skipsOnboarding: Bool { arguments.contains(skipOnboardingArgument) }
    /// Whether the test wants the built-in categories and rules.
    static var seedsStore: Bool { arguments.contains(seedArgument) }
    /// Whether the test wants an empty start.
    static var resetsState: Bool { arguments.contains(resetArgument) }

    /// Applies the launch switches to the in-memory container and settings store.
    ///
    /// Fixture state is only ever written to the in-memory objects the caller passes in, so a test
    /// run cannot leak into the App Group or the next launch. The store itself starts empty too
    /// (``ZentriContainer/make(inMemory:)``), so resetting it is a matter of clearing the settings;
    /// a seeding switch is the only way a test gets rows.
    @MainActor
    static func prepare(container: ModelContainer, settingsStore: SettingsStore) throws {
        if resetsState {
            try settingsStore.reset()
        }
        if skipsOnboarding {
            try settingsStore.save(fixtureSettings)
        }
        if seedsStore {
            try SeedData.seed(into: container.mainContext)
        }
    }
}
