import SwiftUI

/// The backup folder's name, or why there is none to show.
struct BackupFolderStateText: View {
    let state: BackupFolderState

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
        case .none:
            Text("None chosen")
        case .chosen(let name):
            Text(verbatim: name)
        case .failed:
            Text("Needs choosing again")
                .foregroundStyle(Theme.spending)
        }
    }
}
