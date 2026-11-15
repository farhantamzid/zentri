import Foundation

/// The parsing screens a stack can push: the rule list, the tester, and the inbox.
///
/// The Settings stack and the Overview stack each register these once, so the Overview's health
/// card and an account's detail can push the same screens Settings › Parsing does.
enum ParsingRoute: Hashable, Sendable {
    /// The rule list, for one account or for all of them.
    case rules(accountID: UUID?)
    /// The live tester.
    case tester
    /// The raw-message inbox.
    case inbox
}
