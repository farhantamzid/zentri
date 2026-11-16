import SwiftUI

/// What stands out about the month, one sentence per observation, each beside an accent tile.
///
/// The screen leaves the card out when there is nothing to say, which only happens for a month with
/// income and no spending.
struct InsightsObservationsCard: View {
    let observations: [InsightsObservation]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ForEach(observations, id: \.self) { observation in
                InsightsObservationRow(observation: observation)
            }
        }
        .glassCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Observations"))
    }
}

#Preview {
    InsightsObservationsCard(
        observations: [
            .categoryChange(categoryName: "Dining", wholePercent: -24),
            .peakDay(date: .now, ratio: 3.2),
            .topMerchant(merchant: "Grab", transactionCount: 14),
        ]
    )
    .padding()
    .ambientBackground()
}
