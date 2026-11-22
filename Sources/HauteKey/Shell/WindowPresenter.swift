import AppKit
import SwiftUI

/// Shows the Settings and onboarding windows. Views are supplied later so this doesn't
/// depend on them.
@MainActor
final class WindowPresenter {
    var settingsView: () -> AnyView = { AnyView(Text("Settings").padding(40)) }
    var onboardingView: () -> AnyView = { AnyView(Text("Permissions").padding(40)) }

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    /// A fresh view each time the window opens, so it starts scrolled to the top.
    func showSettings() {
        if let window = settingsWindow, !window.isVisible {
            window.contentViewController = NSHostingController(rootView: settingsView())
        }
        settingsWindow = show(settingsWindow, title: "Haute Key Settings", content: settingsView)
    }

    /// Floats above other windows (System Settings included) so it stays visible while the
    /// user flips the switches; a background app can't reliably bring itself to the front.
    func showOnboarding() {
        let window = show(onboardingWindow, title: "Set Up Haute Key", content: onboardingView)
        window.level = .floating
        window.orderFrontRegardless()
        onboardingWindow = window
    }

    func closeOnboarding() {
        onboardingWindow?.close()
    }

    var isOnboardingVisible: Bool {
        onboardingWindow?.isVisible ?? false
    }

    private func show(_ existing: NSWindow?, title: String, content: () -> AnyView) -> NSWindow {
        let window = existing ?? {
            let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
            window.title = title
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            return window
        }()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate()
        return window
    }
}
