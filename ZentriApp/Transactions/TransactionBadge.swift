import SwiftUI

/// A small labelled marker on a transaction, such as Transfer or Manual.
struct TransactionBadge: View {
    let title: LocalizedStringResource
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.footnote)
        .foregroundStyle(Theme.secondaryInk)
    }
}
