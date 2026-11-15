import Foundation
import ZentriCore

extension CategoryTotal {
    /// The category's share of the period's spend for display, e.g. `25%` or `33.3%`.
    ///
    /// `share` is already scaled to 100, so it is divided back down for the percent format style,
    /// which expects a fraction.
    var formattedShare: String {
        (share / 100).formatted(.percent.precision(.fractionLength(0...1)))
    }
}
