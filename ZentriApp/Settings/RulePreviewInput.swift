import Foundation
import ZentriCore

/// Everything the rule editor's live preview depends on.
///
/// The editor restarts its debounced preview whenever this value changes, which also cancels the
/// preview that was waiting or running for the previous value.
struct RulePreviewInput: Hashable, Sendable {
    let pattern: String
    let direction: Direction
    let dateFormat: String
    let isCaseInsensitive: Bool
    let dotMatchesNewlines: Bool
    let sampleText: String
}
