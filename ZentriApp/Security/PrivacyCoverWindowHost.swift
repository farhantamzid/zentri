import SwiftUI

/// Shows the privacy cover in a window of its own, above everything else in the scene.
///
/// A SwiftUI overlay cannot hide a presented sheet, a file picker, or an alert, because those sit
/// above the view that presents them; a transaction's detail sheet would stay readable in the app
/// switcher and behind the lock. A window at alert level covers them all. SwiftUI has no API for a
/// second window on iOS, so this small bridge places a zero-size anchor view in the hierarchy to
/// find its scene, and hosts the cover there while `isPresented` is true.
struct PrivacyCoverWindowHost<Cover: View>: UIViewRepresentable {
    let isPresented: Bool
    @ContentBuilder let cover: () -> Cover

    func makeCoordinator() -> PrivacyCoverWindowController<Cover> {
        PrivacyCoverWindowController()
    }

    func makeUIView(context: Context) -> PrivacyCoverAnchorView {
        let view = PrivacyCoverAnchorView()
        let controller = context.coordinator
        view.onWindowSceneChange = { scene in
            controller.scene = scene
            controller.apply()
        }
        return view
    }

    func updateUIView(_ view: PrivacyCoverAnchorView, context: Context) {
        let controller = context.coordinator
        controller.isPresented = isPresented
        controller.cover = isPresented ? cover() : nil
        controller.scene = view.window?.windowScene
        controller.apply()
    }

    static func dismantleUIView(_ view: PrivacyCoverAnchorView, coordinator: PrivacyCoverWindowController<Cover>) {
        coordinator.isPresented = false
        coordinator.apply()
    }
}
