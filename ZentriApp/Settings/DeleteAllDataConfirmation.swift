import Foundation

/// The typed confirmation "Delete All Data" asks for, as spec §15 requires for destructive deletion.
///
/// The word is localized, so a person types the word shown in their own language. Surrounding
/// spaces and letter case are ignored: dictation and the keyboard's automatic capitalization should
/// not stand between someone and an action they have clearly confirmed.
struct DeleteAllDataConfirmation {
    /// The word to type.
    let word: String

    init(word: String = String(localized: "DELETE", comment: "The word a person types to confirm deleting all of Zentri's data. Keep it short and in capitals.")) {
        self.word = word
    }

    /// Whether `text` is the confirmation word.
    func isConfirmed(by text: String) -> Bool {
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !typed.isEmpty && typed.compare(word, options: [.caseInsensitive], locale: .current) == .orderedSame
    }
}
