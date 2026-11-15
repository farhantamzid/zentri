import Foundation
import Observation
import SwiftData
import ZentriCore

/// The Accounts screens' data and actions: every account with its balance, and the changes the
/// person can make through ``AccountMutationService``.
///
/// The model reads the store only in ``refresh()``. Every change goes through the service, which
/// validates, saves, and refreshes the widgets; the model then reads again and calls `onMutation`,
/// which the app wires to `AppState.mutate()` so the Overview and Transactions reload. A refused
/// change is rethrown so the sheet or screen that asked can say why.
@MainActor
@Observable
final class AccountsModel {
    /// How far the last read got. Empty lists only mean "no accounts" once loaded.
    private(set) var loadState = SettingsLoadState.loading
    /// The accounts that count toward the combined balance, in display order.
    private(set) var activeAccounts: [AccountListItem] = []
    /// The archived accounts, in display order.
    private(set) var archivedAccounts: [AccountListItem] = []

    @ObservationIgnored private var storedAccounts: [UUID: Account] = [:]
    @ObservationIgnored private let fetchAccounts: @MainActor () throws -> [Account]
    @ObservationIgnored private let service: AccountMutationService
    @ObservationIgnored private let onMutation: @MainActor () -> Void

    /// Creates the model over the supplied context.
    convenience init(
        context: ModelContext,
        service: AccountMutationService,
        onMutation: @escaping @MainActor () -> Void
    ) {
        self.init(
            fetchAccounts: { try context.fetch(FetchDescriptor<Account>()) },
            service: service,
            onMutation: onMutation
        )
    }

    /// Creates the model over a supplied read, which is how a test makes the read throw.
    init(
        fetchAccounts: @escaping @MainActor () throws -> [Account],
        service: AccountMutationService,
        onMutation: @escaping @MainActor () -> Void
    ) {
        self.fetchAccounts = fetchAccounts
        self.service = service
        self.onMutation = onMutation
    }

    /// Whether the store holds any account at all, archived or not.
    var hasAccounts: Bool {
        !activeAccounts.isEmpty || !archivedAccounts.isEmpty
    }

    /// Reads every account again. A read that throws becomes ``SettingsLoadState/failed`` with no
    /// rows, never an empty list.
    func refresh() {
        do {
            let accounts = try fetchAccounts()
                .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
            storedAccounts = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let items = accounts.map(Self.item(from:))
            activeAccounts = items.filter { !$0.isArchived }
            archivedAccounts = items.filter(\.isArchived)
            loadState = .loaded
        } catch {
            storedAccounts = [:]
            activeAccounts = []
            archivedAccounts = []
            loadState = .failed
        }
    }

    /// The account with this identity, active or archived.
    func account(id: UUID) -> AccountListItem? {
        activeAccounts.first { $0.id == id } ?? archivedAccounts.first { $0.id == id }
    }

    /// Adds an account with its opening balance.
    func create(name: String, institutionName: String, openingBalance: Decimal) async throws {
        try await service.create(name: name, institutionName: institutionName, openingBalance: openingBalance)
        didMutate()
    }

    /// Renames an account and replaces its institution.
    func rename(id: UUID, name: String, institutionName: String) async throws {
        guard let account = storedAccounts[id] else { return }
        try await service.rename(account, name: name, institutionName: institutionName)
        didMutate()
    }

    /// Records the account's balance at a date, as a manual checkpoint.
    func setBalance(id: UUID, amount: Decimal, at date: Date) async throws {
        guard let account = storedAccounts[id] else { return }
        try await service.setBalance(account: account, amount: amount, at: date)
        didMutate()
    }

    /// Takes the account out of the combined balance, or puts it back.
    func setArchived(_ isArchived: Bool, id: UUID) async throws {
        guard let account = storedAccounts[id] else { return }
        if isArchived {
            try await service.archive(account)
        } else {
            try await service.unarchive(account)
        }
        didMutate()
    }

    private func didMutate() {
        refresh()
        onMutation()
    }

    private static func item(from account: Account) -> AccountListItem {
        AccountListItem(
            id: account.id,
            name: account.name,
            institutionName: account.institutionName,
            // The same shared calculation the Overview hero uses, one account at a time.
            balance: BalanceCalculator.combined(accounts: [account]),
            asOf: account.checkpoints.map(\.recordedAt).max(),
            isArchived: account.archivedAt != nil
        )
    }
}
