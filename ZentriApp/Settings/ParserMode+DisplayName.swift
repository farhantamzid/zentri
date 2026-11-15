import Foundation
import ZentriCore

extension ParserMode {
    /// The engine's name in the Parsing settings picker.
    var displayName: LocalizedStringResource {
        switch self {
        case .rules: "Rules"
        case .foundationModels: "Foundation Models"
        case .hybrid: "Hybrid"
        }
    }

    /// One sentence on what the engine does.
    var detail: LocalizedStringResource {
        switch self {
        case .rules: "Your own patterns. Fast, predictable, and fully offline."
        case .foundationModels: "Apple Intelligence reads each message. Needs a supported device."
        case .hybrid: "Rules first, then the on-device model when no rule matches."
        }
    }
}
