import SwiftUI

/// The status filter: segments when they fit, a menu when the text is too large for them.
struct RawMessageFilterPicker: View {
    @Binding var filter: RawMessageFilter
    let counts: [RawMessageFilter: Int]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Picker("Status", selection: $filter) {
                ForEach(RawMessageFilter.allCases) { filter in
                    Text(filter.title)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker("Status", selection: $filter) {
                ForEach(RawMessageFilter.allCases) { filter in
                    Text("\(Text(filter.title)) (\(counts[filter] ?? 0))")
                        .tag(filter)
                }
            }
            .pickerStyle(.menu)
        }
        .frame(minHeight: Theme.Layout.minimumTapTarget)
        .accessibilityIdentifier("inbox.filter")
    }
}
