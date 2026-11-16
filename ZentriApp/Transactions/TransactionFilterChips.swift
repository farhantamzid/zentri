import SwiftUI
import ZentriCore

/// The quick filters above the list: everything, spending, income, or one category.
///
/// A chip changes only the direction and category; the account, dates, and search the filter sheet
/// or search field set stay as they are. The selected chip fills with the accent, and the change
/// springs between chips.
struct TransactionFilterChips: View {
    let filter: TransactionFilter
    let categories: [TransactionCategoryOption]
    let onChange: @MainActor (TransactionFilter) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                chip(Text("All"), isOn: filter.direction == nil && filter.categoryID == nil) {
                    $0.direction = nil
                    $0.categoryID = nil
                }
                chip(Text("Spending"), isOn: filter.direction == .debit && filter.categoryID == nil) {
                    $0.direction = .debit
                    $0.categoryID = nil
                }
                chip(Text("Income"), isOn: filter.direction == .credit && filter.categoryID == nil) {
                    $0.direction = .credit
                    $0.categoryID = nil
                }
                ForEach(categories) { category in
                    chip(
                        Text(verbatim: category.name),
                        dot: Theme.categoryColor(for: category.colorToken),
                        isOn: filter.categoryID == category.id
                    ) {
                        $0.direction = nil
                        $0.categoryID = category.id
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: filter.categoryID)
        .sensoryFeedback(.selection, trigger: filter.direction)
    }

    private func chip(
        _ title: Text,
        dot: Color? = nil,
        isOn: Bool,
        change: @escaping (inout TransactionFilter) -> Void
    ) -> some View {
        Button {
            var next = filter
            change(&next)
            withAnimation(Theme.Motion.snap) {
                onChange(next)
            }
        } label: {
            HStack(spacing: 6) {
                if let dot {
                    Circle()
                        .fill(isOn ? Theme.onAccent : dot)
                        .frame(width: 8, height: 8)
                }
                title
            }
            .font(.subheadline.weight(isOn ? .semibold : .medium))
            .foregroundStyle(isOn ? Theme.onAccent : Theme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(isOn ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.glass), in: .capsule)
            .overlay { Capsule().strokeBorder(isOn ? Theme.accent : Theme.glassBorder) }
            .contentShape(.capsule)
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
