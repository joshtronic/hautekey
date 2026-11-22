import AppKit
import os

/// Opens apps the way clicking their Dock icon does: launches them if needed, brings them
/// forward, and sends a reopen so apps with no open windows make one. Never hides anything.
@MainActor
final class AppLauncher {
    private let log = Logger(subsystem: "com.joshtronic.hautekey", category: "launch")

    func isInstalled(bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    /// Returns false if no app with that bundle ID is installed.
    @discardableResult
    func open(bundleID: String) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [log] _, error in
            if let error {
                log.error("couldn't open \(bundleID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return true
    }
}
