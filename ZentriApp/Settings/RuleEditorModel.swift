import Foundation
import Observation
import SwiftUI
import ZentriCore

/// The rule editor's fields, the pattern's validation, and the live preview against a sample.
///
/// The pattern is compiled on every change — compiling is cheap and bounded — so the inline error
/// and the Save button follow each keystroke. Matching is not cheap for every pattern, so the
/// preview runs off the main actor through the tester, after a short pause in typing; a newer edit
/// cancels the pending preview and a stale result is discarded.
@MainActor
@Observable
final class RuleEditorModel {
    /// The pattern the "Copy Example" affordance offers.
    static let examplePattern = #"RM(?<amount>[\d.,]+) spent at (?<merchant>.+?) on (?<date>\d{2}/\d{2}/\d{2})"#

    /// How long typing must pause before the preview runs.
    static let previewDelay = Duration.milliseconds(300)

    /// Whether the editor is adding a rule rather than editing one.
    let isCreating: Bool
    /// The accounts the rule can belong to.
    let accounts: [TransactionAccountOption]

    var accountID: UUID?
    var name: String
    var direction: Direction
    var pattern: String {
        didSet { validatePattern() }
    }
    var dateFormat: String
    var priority: Int
    var isCaseInsensitive: Bool
    var dotMatchesNewlines: Bool
    var isEnabled: Bool
    /// A message to try the pattern on; it is never saved.
    var sampleText = ""

    /// Why the pattern cannot be saved, or `nil` when it can.
    private(set) var patternError: RegexValidationError?
    /// What the pattern made of the sample, or `nil` when there is nothing to preview.
    private(set) var preview: RulePreview?
    /// The sample with each captured group marked, alongside ``preview``.
    private(set) var highlightedSample: AttributedString?

    @ObservationIgnored private let ruleID: UUID
    @ObservationIgnored private let previewer: @MainActor (ParsingRuleSpec, String) async -> RulePreview

    /// - Parameters:
    ///   - rule: The rule to edit, or `nil` to add one, which starts on, at priority zero, as a debit.
    ///   - defaultAccountID: The account a new rule starts on.
    ///   - accounts: The accounts the picker offers.
    ///   - previewer: Runs one rule against a sample, off the main actor; normally
    ///     `RuleTesterService.preview(rule:text:)`.
    init(
        rule: ParsingRuleListItem?,
        defaultAccountID: UUID?,
        accounts: [TransactionAccountOption],
        previewer: @escaping @MainActor (ParsingRuleSpec, String) async -> RulePreview
    ) {
        isCreating = rule == nil
        self.accounts = accounts
        self.previewer = previewer
        ruleID = rule?.id ?? UUID()
        accountID = rule?.accountID ?? defaultAccountID
        name = rule?.name ?? ""
        direction = rule?.direction ?? .debit
        pattern = rule?.pattern ?? ""
        dateFormat = rule?.dateFormat ?? ""
        priority = rule?.priority ?? 0
        isCaseInsensitive = rule?.isCaseInsensitive ?? true
        dotMatchesNewlines = rule?.dotMatchesNewlines ?? false
        isEnabled = rule?.isEnabled ?? true
        validatePattern()
    }

    /// The rule the form describes, or `nil` while it cannot be saved: the pattern must compile and
    /// have an `amount` group, and the rule needs a name and an account.
    var draft: ParsingRuleDraft? {
        guard patternError == nil,
              let accountID,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return ParsingRuleDraft(
            accountID: accountID,
            name: name,
            direction: direction,
            pattern: pattern,
            dateFormat: dateFormat,
            isCaseInsensitive: isCaseInsensitive,
            dotMatchesNewlines: dotMatchesNewlines,
            priority: priority,
            isEnabled: isEnabled
        )
    }

    /// Whether Save is enabled.
    var canSave: Bool {
        draft != nil
    }

    /// The values the preview depends on.
    var previewInput: RulePreviewInput {
        RulePreviewInput(
            pattern: pattern,
            direction: direction,
            dateFormat: dateFormat,
            isCaseInsensitive: isCaseInsensitive,
            dotMatchesNewlines: dotMatchesNewlines,
            sampleText: sampleText
        )
    }

    /// Fills the pattern with the example, so the person can adapt it.
    func useExamplePattern() {
        pattern = Self.examplePattern
    }

    /// Runs the pattern against the sample after `delay`.
    ///
    /// A pattern that does not compile, or an empty sample, clears the preview at once. The caller
    /// cancels this when the input changes again; a cancelled run never publishes its result.
    func refreshPreview(after delay: Duration = previewDelay) async {
        let input = previewInput
        guard case .success = RegexValidator.validate(pattern: input.pattern),
              !input.sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            preview = nil
            highlightedSample = nil
            return
        }
        do {
            try await Task.sleep(for: delay)
        } catch {
            return
        }
        let spec = ParsingRuleSpec(
            id: ruleID,
            direction: input.direction,
            pattern: input.pattern,
            dateFormat: input.dateFormat,
            isCaseInsensitive: input.isCaseInsensitive,
            dotMatchesNewlines: input.dotMatchesNewlines
        )
        let result = await previewer(spec, input.sampleText)
        guard !Task.isCancelled, input == previewInput else { return }
        preview = result
        highlightedSample = Self.highlighted(input.sampleText, captures: result.captures)
    }

    private func validatePattern() {
        patternError = RegexValidator.validateRule(pattern: pattern)
    }

    /// The sample with every capture underlined and tinted. The fields list repeats the values, so
    /// the highlight is never the only way to read them.
    private static func highlighted(_ text: String, captures: [RuleCapture]) -> AttributedString {
        var attributed = AttributedString(text)
        let characters = attributed.characters
        for capture in captures where capture.range.upperBound <= characters.count {
            let start = characters.index(characters.startIndex, offsetBy: capture.range.lowerBound)
            let end = characters.index(characters.startIndex, offsetBy: capture.range.upperBound)
            attributed[start..<end].backgroundColor = Theme.accent.opacity(0.2)
            attributed[start..<end].underlineStyle = .single
        }
        return attributed
    }
}
