import SwiftData
import SwiftUI
import ZentriCore

/// The account list, its empty and failure states, the add sheet, and the pushed account detail.
///
/// The content owns the model, so the list survives re-renders; it reads the store when it appears
/// and whenever a mutation anywhere bumps the revision.
struct AccountsContent: View {
    @State private var model: AccountsModel
    @State private var isAdding = false
    @State private var addedCount = 0
    private let dataRevision: Int

    init(
        context: ModelContext,
        service: AccountMutationService,
        dataRevision: Int,
        onMutation: @escaping @MainActor () -> Void
    ) {
        _model = State(initialValue: AccountsModel(context: context, service: service, onMutation: onMutation))
        self.dataRevision = dataRevision
    }

    var body: some View {
        AccountsStateView(model: model, onAdd: startAdding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Account", systemImage: "plus", action: startAdding)
                        .accessibilityIdentifier("accounts.add")
                }
            }
            .onAppear(perform: model.refresh)
            .onChange(of: dataRevision) {
                model.refresh()
            }
            .navigationDestination(for: AccountRoute.self) { route in
                AccountDetailView(model: model, accountID: route.accountID)
            }
            .sheet(isPresented: $isAdding) {
                AccountEditorView(account: nil, onSave: create)
            }
            .sensoryFeedback(.success, trigger: addedCount)
    }

    private func startAdding() {
        isAdding = true
    }

    private func create(name: String, institutionName: String, openingBalance: Decimal?) async throws {
        try await model.create(name: name, institutionName: institutionName, openingBalance: openingBalance ?? 0)
        addedCount += 1
    }
}
