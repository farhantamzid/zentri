import Testing
@testable import ZentriApp

/// The word "Delete All Data" asks for (spec §15 typed confirmation).
@Suite
struct DeleteAllDataConfirmationTests {
    @Test func onlyTheConfirmationWordTurnsDeletionOn() {
        let confirmation = DeleteAllDataConfirmation(word: "DELETE")

        #expect(confirmation.isConfirmed(by: "DELETE"))
        // Spacing and letter case from dictation or the keyboard do not matter.
        #expect(confirmation.isConfirmed(by: "  delete "))
        #expect(!confirmation.isConfirmed(by: ""))
        #expect(!confirmation.isConfirmed(by: "DELET"))
        #expect(!confirmation.isConfirmed(by: "DELETE ALL"))
        #expect(!confirmation.isConfirmed(by: "yes"))
    }

    @Test func theDefaultWordIsDELETEInEnglish() {
        #expect(DeleteAllDataConfirmation().word == "DELETE")
    }
}
