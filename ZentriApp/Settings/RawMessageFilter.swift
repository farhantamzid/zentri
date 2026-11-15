import Foundation
import ZentriCore

/// The inbox's status filters.
enum RawMessageFilter: String, CaseIterable, Identifiable, Sendable {
    case failed
    case ignored
    case parsed
    case duplicate

    var id: Self { self }

    /// The segment's title.
    var title: LocalizedStringResource {
        switch self {
        case .failed: "Failed"
        case .ignored: "Ignored"
        case .parsed: "Parsed"
        case .duplicate: "Duplicate"
        }
    }

    /// Whether a message with `status` belongs under this filter.
    ///
    /// Messages an interruption left pending are shown with the failures: they have not become
    /// transactions either, and the launch retry or a reprocess is what moves them on.
    func includes(_ status: ParseStatus) -> Bool {
        switch self {
        case .failed: status == .failed || status == .processing
        case .ignored: status == .ignored
        case .parsed: status == .parsed
        case .duplicate: status == .duplicate
        }
    }
}
