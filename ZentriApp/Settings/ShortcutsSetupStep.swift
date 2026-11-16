import Foundation

/// The five steps of building the Shortcuts automation that hands bank messages to Zentri.
///
/// iOS does not let an app create the automation, so the guide walks through it in the Shortcuts
/// app's own words.
enum ShortcutsSetupStep: Int, CaseIterable, Identifiable, Sendable {
    case newAutomation = 1
    case sender
    case runImmediately
    case addAction
    case passText

    var id: Int { rawValue }

    /// The step's position, shown beside it.
    var number: Int { rawValue }

    /// What to do in the Shortcuts app.
    var instruction: LocalizedStringResource {
        switch self {
        case .newAutomation:
            LocalizedStringResource(
                "In Shortcuts, open Automation, tap New Automation, and choose Message.",
                comment: "Shortcuts setup step 1. Automation, New Automation, and Message are Shortcuts app labels."
            )
        case .sender:
            LocalizedStringResource(
                "Choose your bank as the sender. If it sends from a name such as MYBANK that you can't save as a contact, leave the sender empty and choose Message Contains with a word every bank message includes, such as the bank's name.",
                comment: "Shortcuts setup step 2. Message Contains is a Shortcuts app option."
            )
        case .runImmediately:
            LocalizedStringResource(
                "Choose Run Immediately, so the automation runs without asking you each time.",
                comment: "Shortcuts setup step 3. Run Immediately is a Shortcuts app option."
            )
        case .addAction:
            LocalizedStringResource(
                "Add the Capture Bank SMS action from Zentri.",
                comment: "Shortcuts setup step 4. Capture Bank SMS is Zentri's action name."
            )
        case .passText:
            LocalizedStringResource(
                "Set SMS Text to the message's Content. You can also choose an account, the sender, and the message date.",
                comment: "Shortcuts setup step 5. SMS Text is the action's parameter; Content is the Shortcuts variable."
            )
        }
    }
}
