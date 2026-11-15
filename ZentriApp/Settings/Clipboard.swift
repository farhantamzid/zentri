import UIKit

/// Copies text for the person to paste elsewhere.
///
/// SwiftUI has no view-free way to write to the pasteboard, so this is the one place the app uses
/// UIKit for it.
enum Clipboard {
    @MainActor
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
