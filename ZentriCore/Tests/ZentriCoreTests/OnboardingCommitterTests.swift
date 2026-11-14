import Foundation
import SwiftData
import Testing
@testable import ZentriCore

// `Category` is qualified as `ZentriCore.Category` because Foundation imports the Objective-C
// runtime's `Category` typedef, which makes the bare name ambiguous outside the module.

/// A settings repository that keeps its document in memory and counts the writes it receives.
///
/// The committer has to write the settings document before its SwiftData save and put the previous
/// document back when that save fails, so the tests need to see both the stored value and the
/// writes. The lock keeps the type `Sendable`, which ``SettingsRepository`` requires.
private final class TestSettingsRepository: SettingsRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var document: AppSettings?
    private var writeCount = 0

    func load() throws -> AppSettings? {
        lock.withLock { document }
    }

    func save(_ settings: AppSettings) throws {
        lock.withLock {
            document = settings
            writeCount += 1
        }
    }

    func remove() throws {
        lock.withLock { document = nil }
    }

    /// The stored document, read without throwing so assertions stay short.
    var storedSettings: AppSettings? {
        lock.withLock { document }
    }

    /// How many times ``save(_:)`` has been called.
    var writes: Int {
        lock.withLock { writeCount }
    }
}

/// The failure a test's save handler throws to prove the committer rolls back.
private struct UnwritableStore: Error {}

/// The committer with its save made to fail, and a repository to inspect afterwards.
@MainActor
private func makeFailingCommitter(
    repository: TestSettingsRepository
) -> OnboardingCommitter {
    var committer = OnboardingCommitter(settingsRepository: repository)
    committer.saveHandler = { _ in throw UnwritableStore() }
    return committer
}

/// The settings a test commits when it only cares about the rows the committer writes.
private func selectedSettings() -> AppSettings {
    var settings = AppSettings.defaultValue
    settings.currencyCode = "BDT"
    settings.numberGrouping = .indian
    settings.parserMode = .rules
    return settings
}

@Test @MainActor func commitCreatesTheAccountCheckpointSeedsAndSettings() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let repository = TestSettingsRepository()
    let committer = OnboardingCommitter(settingsRepository: repository)

    let account = try committer.commit(
        settings: selectedSettings(),
        accountName: "Everyday",
        institutionName: "Bank",
        openingBalance: 1_000_000,
        faceIDEnabled: false,
        context: context
    )

    #expect(account.name == "Everyday")
    #expect(account.institutionName == "Bank")
    #expect(account.sortOrder == 0)
    #expect(try context.fetchCount(FetchDescriptor<Account>()) == 1)

    let checkpoints = try context.fetch(FetchDescriptor<BalanceCheckpoint>())
    #expect(checkpoints.count == 1)
    let checkpoint = try #require(checkpoints.first)
    #expect(checkpoint.amount == 1_000_000)
    #expect(checkpoint.source == .opening)
    #expect(checkpoint.account.id == account.id)

    #expect(try context.fetchCount(FetchDescriptor<ZentriCore.Category>()) == 12)
    let rules = try context.fetch(FetchDescriptor<CategorizationRule>())
    #expect(rules.count == 5)

    let stored = try #require(repository.storedSettings)
    #expect(stored.currencyCode == "BDT")
    #expect(stored.numberGrouping == .indian)
    #expect(stored.parserMode == .rules)
    #expect(stored.faceIDEnabled == false)
}

@Test @MainActor func commitAppliesTheFaceIDParameterToTheSettingsItPersists() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let repository = TestSettingsRepository()
    let committer = OnboardingCommitter(settingsRepository: repository)

    try committer.commit(
        settings: selectedSettings(),
        accountName: "Everyday",
        institutionName: nil,
        openingBalance: 0,
        faceIDEnabled: true,
        context: context
    )

    let stored = try #require(repository.storedSettings)
    #expect(stored.faceIDEnabled)
}

@Test @MainActor func commitSavesExactlyOnce() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let repository = TestSettingsRepository()
    var committer = OnboardingCommitter(settingsRepository: repository)
    var saves = 0
    committer.saveHandler = { context in
        saves += 1
        try context.save()
    }

    try committer.commit(
        settings: selectedSettings(),
        accountName: "Everyday",
        institutionName: nil,
        openingBalance: 500,
        faceIDEnabled: false,
        context: context
    )

    #expect(saves == 1)
}

@Test @MainActor func commitTrimsTheNameAndDropsABlankInstitution() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let committer = OnboardingCommitter(settingsRepository: TestSettingsRepository())

    let account = try committer.commit(
        settings: .defaultValue,
        accountName: "  Everyday  ",
        institutionName: "   ",
        openingBalance: 0,
        faceIDEnabled: false,
        context: context
    )

    #expect(account.name == "Everyday")
    #expect(account.institutionName == nil)
    #expect(try context.fetchCount(FetchDescriptor<BalanceCheckpoint>()) == 1)
}

@Test @MainActor func commitOrdersTheFirstAccountAfterTheExistingOnes() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    context.insert(Account(name: "Old", sortOrder: 4, createdAt: .now))
    try context.save()
    let committer = OnboardingCommitter(settingsRepository: TestSettingsRepository())

    let account = try committer.commit(
        settings: .defaultValue,
        accountName: "Everyday",
        institutionName: nil,
        openingBalance: 0,
        faceIDEnabled: false,
        context: context
    )

    #expect(account.sortOrder == 5)
}

@Test @MainActor func commitSeedsIdempotentlySoARepeatedSeedAddsNothing() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let committer = OnboardingCommitter(settingsRepository: TestSettingsRepository())

    try committer.commit(
        settings: .defaultValue,
        accountName: "Everyday",
        institutionName: nil,
        openingBalance: 0,
        faceIDEnabled: false,
        context: context
    )
    try SeedData.insert(into: context)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<ZentriCore.Category>()) == 12)
    #expect(try context.fetchCount(FetchDescriptor<CategorizationRule>()) == 5)
}

@Test @MainActor func failedSaveLeavesNoRowsAndRemovesTheSettingsDocument() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let repository = TestSettingsRepository()
    let committer = makeFailingCommitter(repository: repository)

    #expect(throws: UnwritableStore.self) {
        try committer.commit(
            settings: selectedSettings(),
            accountName: "Everyday",
            institutionName: "Bank",
            openingBalance: 1_000_000,
            faceIDEnabled: true,
            context: context
        )
    }

    // A second context sees only what reached the store, so it proves the rollback wrote nothing.
    let verification = ModelContext(container)
    #expect(try verification.fetchCount(FetchDescriptor<Account>()) == 0)
    #expect(try verification.fetchCount(FetchDescriptor<BalanceCheckpoint>()) == 0)
    #expect(try verification.fetchCount(FetchDescriptor<ZentriCore.Category>()) == 0)
    #expect(try verification.fetchCount(FetchDescriptor<CategorizationRule>()) == 0)
    // There was no document before the commit, so the rollback removes the one it wrote.
    #expect(repository.storedSettings == nil)
}

@Test @MainActor func failedSaveRestoresThePreviousSettingsDocument() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let repository = TestSettingsRepository()
    let previous = AppSettings.defaultValue
    try repository.save(previous)
    let committer = makeFailingCommitter(repository: repository)

    #expect(throws: UnwritableStore.self) {
        try committer.commit(
            settings: selectedSettings(),
            accountName: "Everyday",
            institutionName: nil,
            openingBalance: 1_000_000,
            faceIDEnabled: true,
            context: context
        )
    }

    #expect(repository.storedSettings == previous)
}
