import Foundation
import SwiftData

/// Rewrites the widget snapshot after the app's data changes.
///
/// The protocol carries no failure: a snapshot that cannot be written leaves the widgets showing
/// their placeholder, and the next refresh replaces it. That is why ingestion can refresh after
/// every outcome without letting a widget problem fail the message.
///
/// A conforming type may be an actor, a `@MainActor` type, or a plain value, so tests can count
/// refreshes without a file system.
public protocol WidgetSnapshotRefresher: Sendable {
    /// Reads the current state and writes a fresh snapshot.
    func refresh() async
}

/// Reads the store and writes the widget snapshot the app and its extension share.
///
/// It is `@MainActor` because it reads the same `ModelContext` the app's screens use, and it is a
/// value so the app can hold one and pass it to ingestion.
@MainActor
public struct LiveWidgetSnapshotRefresher: WidgetSnapshotRefresher {
    private let context: ModelContext
    private let store: any WidgetSnapshotStore
    private let settings: @MainActor @Sendable () -> AppSettings
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    /// Creates the refresher.
    ///
    /// - Parameters:
    ///   - context: The context to read accounts, transactions, checkpoints, and categories from.
    ///   - store: Where the snapshot is written, normally ``FileWidgetSnapshotStore`` over
    ///     ``SharedContainer/widgetSnapshotURL``.
    ///   - settings: The current settings, read on every refresh so a currency change reaches the
    ///     widgets.
    ///   - now: The clock; the snapshot's `generatedAt` and its day boundaries come from it.
    ///   - calendar: The calendar that defines today, this month, and the trend days.
    public init(
        context: ModelContext,
        store: any WidgetSnapshotStore,
        settings: @escaping @MainActor @Sendable () -> AppSettings,
        now: @escaping @Sendable () -> Date,
        calendar: Calendar
    ) {
        self.context = context
        self.store = store
        self.settings = settings
        self.now = now
        self.calendar = calendar
    }

    public func refresh() async {
        do {
            let snapshot = WidgetSnapshotBuilder().build(
                accounts: try context.fetch(FetchDescriptor<Account>()).map(Self.input(from:)),
                transactions: try context.fetch(FetchDescriptor<Transaction>()).map(Self.input(from:)),
                categories: try context.fetch(FetchDescriptor<Category>()).map { category in
                    CategorySnapshot(
                        id: category.id,
                        name: category.name,
                        symbolName: category.symbolName,
                        colorToken: category.colorToken
                    )
                },
                settings: settings(),
                now: now(),
                calendar: calendar
            )
            try store.write(snapshot)
        } catch {
            // A widget document the app could not write is a placeholder on the Home Screen, not a
            // reason to fail the ingestion that asked for the refresh.
        }
    }

    /// An account with the checkpoints its balance rests on.
    private static func input(from account: Account) -> WidgetSnapshotBuilder.AccountInput {
        WidgetSnapshotBuilder.AccountInput(
            id: account.id,
            isArchived: account.archivedAt != nil,
            checkpoints: account.checkpoints.map { checkpoint in
                CheckpointValue(
                    accountID: account.id,
                    amount: checkpoint.amount,
                    recordedAt: checkpoint.recordedAt,
                    createdAt: checkpoint.createdAt
                )
            }
        )
    }

    /// A transaction with the display values the widget rows need.
    private static func input(from transaction: Transaction) -> WidgetSnapshotBuilder.TransactionInput {
        WidgetSnapshotBuilder.TransactionInput(
            id: transaction.id,
            accountID: transaction.account.id,
            amount: transaction.amount,
            direction: transaction.direction,
            occurredAt: transaction.occurredAt,
            recordedAt: transaction.recordedAt,
            merchant: transaction.merchantDisplay,
            categoryID: transaction.category?.id,
            categoryName: transaction.category?.name ?? "",
            symbolName: transaction.category?.symbolName ?? "",
            colorToken: transaction.category?.colorToken ?? "",
            isTransfer: transaction.isTransfer
        )
    }
}
