import Foundation
import SwiftData
import Testing
@testable import ZentriCore

/// The instant the tests treat as now.
private let lookupNow = Date(timeIntervalSince1970: 1_800_000_000)

@MainActor
@Test func activeAccountsLeaveOutArchivedOnesAndFollowTheSortOrder() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = container.mainContext
    let savings = Account(name: "Savings", sortOrder: 2, createdAt: lookupNow)
    let everyday = Account(name: "Everyday", sortOrder: 0, createdAt: lookupNow)
    let travel = Account(name: "Travel", sortOrder: 1, createdAt: lookupNow)
    let closed = Account(name: "Closed", sortOrder: -1, createdAt: lookupNow, archivedAt: lookupNow)
    for account in [savings, everyday, travel, closed] {
        context.insert(account)
    }
    try context.save()

    let accounts = try AccountLookup.activeAccounts(in: context)

    #expect(accounts.map(\.name) == ["Everyday", "Travel", "Savings"])
}

@MainActor
@Test func activeAccountsBreakSortOrderTiesByID() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = container.mainContext
    let first = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        name: "B",
        sortOrder: 0,
        createdAt: lookupNow
    )
    let second = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
        name: "A",
        sortOrder: 0,
        createdAt: lookupNow
    )
    context.insert(second)
    context.insert(first)
    try context.save()

    let accounts = try AccountLookup.activeAccounts(in: context)

    #expect(accounts.map(\.id) == [first.id, second.id])
}

@MainActor
@Test func activeAccountsAreEmptyForAnEmptyStore() throws {
    let container = try ZentriContainer.make(inMemory: true)

    #expect(try AccountLookup.activeAccounts(in: container.mainContext).isEmpty)
}

/// A Shortcut keeps the account it was configured with, so resolving an id finds an archived account
/// too: dropping it would let the capture fall back to another account.
@MainActor
@Test func accountsWithIDsFindArchivedAccountsAndSkipUnknownIDs() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = container.mainContext
    let everyday = Account(name: "Everyday", sortOrder: 0, createdAt: lookupNow)
    let closed = Account(name: "Closed", sortOrder: 1, createdAt: lookupNow, archivedAt: lookupNow)
    let other = Account(name: "Other", sortOrder: 2, createdAt: lookupNow)
    for account in [everyday, closed, other] {
        context.insert(account)
    }
    try context.save()

    let accounts = try AccountLookup.accounts(withIDs: [closed.id, UUID(), everyday.id], in: context)

    #expect(accounts.map(\.name) == ["Everyday", "Closed"])
}
