import SwiftUI

/// A label on the left and its figure on the right, announced as one statement.
///
/// The month summary and the ingestion health card both pair a name with a number; combining them
/// here keeps the rows aligned and stops VoiceOver from reading a figure without saying what it
/// belongs to. At accessibility text sizes the two would need more width than a phone has, so the
/// row stacks instead of hyphenating its label into unreadable pieces.
struct SummaryRow<Value: View>: View {
    private let title: LocalizedStringResource
    private let identifier: String
    @ContentBuilder private let value: Value

    init(_ title: LocalizedStringResource, identifier: String, @ContentBuilder value: () -> Value) {
        self.title = title
        self.identifier = identifier
        self.value = value()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                label
                Spacer(minLength: Theme.Spacing.sm)
                value
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                label
                value
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var label: some View {
        Text(title)
            .foregroundStyle(Theme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    VStack {
        SummaryRow("Spent", identifier: "preview.spent") {
            MoneyText(1_234.5)
        }
        SummaryRow("Failed messages", identifier: "preview.failures") {
            Text(1, format: .number)
        }
    }
    .padding()
    .background(Theme.canvas)
}
