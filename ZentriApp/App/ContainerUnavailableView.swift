import SwiftUI

/// The screen shown when the app cannot open its SwiftData container.
struct ContainerUnavailableView: View {
    private let retry: @MainActor () -> Void

    init(retry: @escaping @MainActor () -> Void) {
        self.retry = retry
    }

    var body: some View {
        ContentUnavailableView {
            Label("Storage unavailable", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Zentri could not open its database on this device.")
        } actions: {
            Button("Try Again", action: retry)
                .prominentButtonStyle()
                .controlSize(.large)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Theme.canvas.ignoresSafeArea() }
    }
}
