import Foundation
import Testing
import ZentriCore
@testable import ZentriApp

private let accountID = UUID()
private let accounts = [TransactionAccountOption(id: accountID, name: "Everyday")]

/// Records the previews the model asked for and answers with a fixed preview.
@MainActor
private final class PreviewRecorder {
    var requests: [(ParsingRuleSpec, String)] = []
    var answer = RulePreview(
        captures: [RuleCapture(name: "amount", value: "42.75", range: 10..<15)],
        result: .transaction(TransactionDraft(direction: .debit, amount: Decimal(string: "42.75") ?? 0, merchant: "Fixture Cafe"))
    )

    func preview(_ spec: ParsingRuleSpec, _ text: String) async -> RulePreview {
        requests.append((spec, text))
        return answer
    }
}

@MainActor
private func makeEditor(rule: ParsingRuleListItem? = nil, recorder: PreviewRecorder = PreviewRecorder()) -> RuleEditorModel {
    RuleEditorModel(rule: rule, defaultAccountID: accountID, accounts: accounts, previewer: recorder.preview)
}

@MainActor
@Test func newRuleCannotBeSavedUntilThePatternHasAnAmountGroup() {
    let editor = makeEditor()
    editor.name = "Card debit"

    #expect(editor.patternError == .emptyPattern)
    #expect(!editor.canSave)

    editor.pattern = #"spent at (?<merchant>.+)"#
    #expect(editor.patternError == .missingAmountGroup)
    #expect(!editor.canSave)

    editor.pattern = #"RM(?<amount>[\d.,]+"#
    if case .invalidSyntax = editor.patternError {} else {
        Issue.record("An unbalanced group was not reported as a syntax error: \(String(describing: editor.patternError))")
    }
    #expect(!editor.canSave)

    editor.pattern = parsingTestPattern
    #expect(editor.patternError == nil)
    #expect(editor.canSave)
}

@MainActor
@Test func saveNeedsANameAndAnAccount() {
    let editor = makeEditor()
    editor.pattern = parsingTestPattern

    #expect(!editor.canSave)
    editor.name = "   "
    #expect(!editor.canSave)
    editor.name = "Card debit"
    #expect(editor.canSave)
    editor.accountID = nil
    #expect(!editor.canSave)
}

@MainActor
@Test func draftCarriesEveryField() throws {
    let editor = makeEditor()
    editor.name = "Card credit"
    editor.direction = .credit
    editor.pattern = parsingTestPattern
    editor.dateFormat = "dd/MM/yy"
    editor.priority = 4
    editor.isCaseInsensitive = false
    editor.dotMatchesNewlines = true
    editor.isEnabled = false

    let draft = try #require(editor.draft)

    #expect(draft == ParsingRuleDraft(
        accountID: accountID,
        name: "Card credit",
        direction: .credit,
        pattern: parsingTestPattern,
        dateFormat: "dd/MM/yy",
        isCaseInsensitive: false,
        dotMatchesNewlines: true,
        priority: 4,
        isEnabled: false
    ))
}

@MainActor
@Test func editingPrefillsTheRule() {
    let rule = ParsingRuleListItem(
        id: UUID(), accountID: accountID, accountName: "Everyday", name: "Old", direction: .credit,
        pattern: parsingTestPattern, dateFormat: "yyyy-MM-dd", isCaseInsensitive: false,
        dotMatchesNewlines: true, priority: 7, isEnabled: false, isPatternValid: true
    )

    let editor = makeEditor(rule: rule)

    #expect(!editor.isCreating)
    #expect(editor.name == "Old")
    #expect(editor.direction == .credit)
    #expect(editor.dateFormat == "yyyy-MM-dd")
    #expect(editor.priority == 7)
    #expect(!editor.isEnabled)
    #expect(editor.canSave)
}

@MainActor
@Test func previewRunsThePatternOnTheSampleAndMarksTheCaptures() async throws {
    let recorder = PreviewRecorder()
    let editor = makeEditor(recorder: recorder)
    editor.pattern = parsingTestPattern
    editor.isCaseInsensitive = false
    editor.sampleText = parsingTestMessage

    await editor.refreshPreview(after: .zero)

    let request = try #require(recorder.requests.first)
    #expect(request.0.pattern == parsingTestPattern)
    #expect(!request.0.isCaseInsensitive)
    #expect(request.1 == parsingTestMessage)
    #expect(editor.preview == recorder.answer)
    let highlighted = try #require(editor.highlightedSample)
    #expect(String(highlighted.characters) == parsingTestMessage)
    #expect(highlighted.runs.contains { $0.underlineStyle != nil })
}

@MainActor
@Test func previewOfABrokenPatternOrEmptySampleClearsWithoutRunning() async {
    let recorder = PreviewRecorder()
    let editor = makeEditor(recorder: recorder)
    editor.pattern = parsingTestPattern
    editor.sampleText = parsingTestMessage
    await editor.refreshPreview(after: .zero)
    #expect(editor.preview != nil)

    editor.pattern = #"RM(?<amount>"#
    await editor.refreshPreview(after: .zero)
    #expect(editor.preview == nil)
    #expect(editor.highlightedSample == nil)

    editor.pattern = parsingTestPattern
    editor.sampleText = "  "
    await editor.refreshPreview(after: .zero)
    #expect(editor.preview == nil)
    #expect(recorder.requests.count == 1)
}

@MainActor
@Test func previewOfAPatternWithoutAnAmountGroupStillShowsCaptures() async {
    let recorder = PreviewRecorder()
    let editor = makeEditor(recorder: recorder)
    editor.pattern = #"spent at (?<merchant>.+)"#
    editor.sampleText = parsingTestMessage

    await editor.refreshPreview(after: .zero)

    #expect(recorder.requests.count == 1)
    #expect(!editor.canSave)
}

@MainActor
@Test func cancelledPreviewIsNotPublished() async {
    let recorder = PreviewRecorder()
    let editor = makeEditor(recorder: recorder)
    editor.pattern = parsingTestPattern
    editor.sampleText = parsingTestMessage

    let task = Task { await editor.refreshPreview(after: .seconds(5)) }
    task.cancel()
    await task.value

    #expect(recorder.requests.isEmpty)
    #expect(editor.preview == nil)
}

@MainActor
@Test func useExampleFillsAPatternThatCanBeSaved() {
    let editor = makeEditor()
    editor.name = "Example"

    editor.useExamplePattern()

    #expect(editor.pattern == RuleEditorModel.examplePattern)
    #expect(editor.canSave)
}
