import SwiftUI

/// Owns the privacy cover's window: creates it on the scene when the cover is wanted, and removes
/// it, handing key status back, when it is not.
///
/// The window is key while it shows, so VoiceOver and the keyboard focus move to the lock screen
/// rather than staying on the content beneath it.
@MainActor
final class PrivacyCoverWindowController<Cover: View> {
    var isPresented = false
    var cover: Cover?
    weak var scene: UIWindowScene?

    private var window: UIWindow?
    private var host: UIHostingController<Cover>?
    private weak var previousKeyWindow: UIWindow?

    /// Shows, updates, or removes the window to match `isPresented`, `cover`, and `scene`.
    func apply() {
        guard isPresented, let cover, let scene else {
            dismiss()
            return
        }
        if let window, let host, window.windowScene === scene {
            host.rootView = cover
            return
        }
        dismiss()
        let host = UIHostingController(rootView: cover)
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = host
        previousKeyWindow = scene.keyWindow
        window.makeKeyAndVisible()
        self.window = window
        self.host = host
    }

    private func dismiss() {
        guard let window else { return }
        window.isHidden = true
        self.window = nil
        host = nil
        previousKeyWindow?.makeKey()
        previousKeyWindow = nil
    }
}
