import Foundation
import Observation
import ZentriCore

/// The actions the transaction detail offers, run through ``TransactionMutationService``.
///
/// The detail reads the stored transaction directly — it is observable, so an edit shows at once —
/// and writes only through the service, which validates, saves, and refreshes the widgets. After
/// every successful change the model calls `onMutation`, which the app wires to `AppState.mutate()`
/// so the list and the Overview reload.
@MainActor
@Observable
final class TransactionDetailModel {
    /// The transaction on screen.
    let transaction: ZentriCore.Transaction
    /// Counts successful changes, which is what the save haptic watches.
    private(set) var changeCount = 0
    /// Whether the last change failed, which the screen reports in an alert.
    var isShowingFailure = false
    /// Whether this merchant's rule was created, so the offer turns into a confirmation.
    private(set) var hasCreatedRule = false
    /// Whether the transaction is being or has been deleted. A deleted model must not be read, so
    /// the screen stops drawing it before the delete starts.
    private(set) var isDeleted = false

    @ObservationIgnored private let service: TransactionMutationService
    @ObservationIgnored private let onMutation: @MainActor () -> Void

    init(
        transaction: ZentriCore.Transaction,
        service: TransactionMutationService,
        onMutation: @escaping @MainActor () -> Void
    ) {
        self.transaction = transaction
        self.service = service
        self.onMutation = onMutation
    }

    /// The transfer flag, as a toggle sets it.
    var isTransfer: Bool {
        get { transaction.isTransfer }
        set {
            guard newValue != transaction.isTransfer else { return }
            Task { await setTransfer(newValue) }
        }
    }

    /// The category, as the picker sets it; a change is marked as the person's choice.
    var categoryID: UUID? {
        get { transaction.category?.id }
        set {
            guard newValue != transaction.category?.id else { return }
            Task { await setCategory(newValue) }
        }
    }

    /// Whether the person chose the category, which is when "Always categorize…" is offered.
    var offersCategoryRule: Bool {
        transaction.categorySource == .manual && transaction.category != nil
    }

    /// The edit the editor starts from.
    var currentEdit: TransactionEdit {
        TransactionEdit(transaction)
    }

    func setTransfer(_ isTransfer: Bool) async {
        _ = await run { try await service.setTransfer(transaction, isTransfer: isTransfer) }
    }

    func setCategory(_ categoryID: UUID?) async {
        hasCreatedRule = false
        _ = await run { try await service.setCategory(transaction, categoryID: categoryID) }
    }

    /// Creates a rule that files every future transaction from this merchant in its category.
    func alwaysCategorizeMerchant() async {
        guard let categoryID = transaction.category?.id else { return }
        let merchant = transaction.merchantDisplay
        hasCreatedRule = await run {
            try await service.alwaysCategorize(merchant: merchant, categoryID: categoryID)
        }
    }

    /// Applies the editor's changes. The error is rethrown so the editor can stay open.
    func save(_ edit: TransactionEdit) async throws {
        try await service.save(edit, existing: transaction)
        changeCount += 1
        onMutation()
    }

    /// Deletes the transaction, keeping its raw message.
    ///
    /// - Returns: Whether the delete succeeded, so the screen knows to close.
    func delete() async -> Bool {
        isDeleted = true
        do {
            try await service.delete(transaction)
            onMutation()
            return true
        } catch {
            isDeleted = false
            isShowingFailure = true
            return false
        }
    }

    /// Runs one change, then counts it and tells the app, or reports that it failed.
    private func run(_ change: () async throws -> Void) async -> Bool {
        do {
            try await change()
            changeCount += 1
            onMutation()
            return true
        } catch {
            isShowingFailure = true
            return false
        }
    }
}
