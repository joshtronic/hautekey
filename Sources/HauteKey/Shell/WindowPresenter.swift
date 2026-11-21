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

    func showSettings() {
        settingsWindow = show(settingsWindow, title: "Haute Key Settings", content: settingsView)
    }

    func showOnboarding() {
        onboardingWindow = show(onboardingWindow, title: "Set Up Haute Key", content: onboardingView)
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
        NSApp.activate()
        return window
    }
}
