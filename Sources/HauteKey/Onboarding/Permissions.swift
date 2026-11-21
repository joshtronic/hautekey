import AppKit
import ApplicationServices

/// The two privacy permissions Haute Key needs. Only the user can grant them, in System Settings.
enum Permissions {
    /// Needed to move other apps' windows and to swallow key presses.
    static var accessibility: Bool { AXIsProcessTrusted() }

    /// Needed to see key presses at all.
    static var inputMonitoring: Bool { CGPreflightListenEventAccess() }

    static var allGranted: Bool { accessibility && inputMonitoring }

    /// Shows macOS's own prompts, which also add the app to both lists in System Settings.
    static func requestAll() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        _ = CGRequestListenEventAccess()
    }

    static let accessibilitySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    static let inputMonitoringSettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
}
