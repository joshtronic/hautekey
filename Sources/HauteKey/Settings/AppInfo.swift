import AppKit
import UniformTypeIdentifiers

/// Name and icon for a bundle ID, and a picker for choosing an app.
@MainActor
enum AppInfo {
    struct Details {
        let name: String
        let icon: NSImage
    }

    /// nil when the app isn't installed on this Mac.
    static func details(for bundleID: String) -> Details? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        return Details(name: name, icon: NSWorkspace.shared.icon(forFile: url.path))
    }

    /// Shows an Open panel in /Applications and returns the chosen app's bundle ID.
    static func chooseApp() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }
}
