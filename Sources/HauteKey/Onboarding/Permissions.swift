import AppKit
import ApplicationServices

/// The two privacy permissions Haute Key needs. Only the user can grant them, in System Settings.
enum Permissions {
    /// Needed to move other apps' windows and to swallow key presses.
    static var accessibility: Bool { AXIsProcessTrusted() }

    /// Needed to see key presses at all.
    static var inputMonitoring: Bool { CGPreflightListenEventAccess() }

    static var allGranted: Bool { accessibility && inputMonitoring }

    /// Asking is what adds the app to each list in System Settings. macOS shows its own prompt
    /// the first time; after that these do nothing, so callers also open the Settings page.
    static func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
    }

    static let accessibilitySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    static let inputMonitoringSettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
}
