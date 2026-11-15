import SwiftUI
import WidgetKit

/// Zentri's widgets: four for the Home Screen and one for the Lock Screen.
@main
struct ZentriWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
        TrendWidget()
        RecentTransactionsWidget()
        CategoriesWidget()
        AccessoryBalanceWidget()
    }
}
