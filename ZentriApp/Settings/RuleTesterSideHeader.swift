import SwiftUI

/// A tester section's title with how long that side took.
struct RuleTesterSideHeader: View {
    let title: LocalizedStringResource
    let milliseconds: Double?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let milliseconds {
                Text("\(milliseconds, format: .number.precision(.fractionLength(1))) ms")
                    .monospacedDigit()
            }
        }
    }
}
