import CoreGraphics
import Foundation
import HauteKeyCore

/// Opens Spotlight by pressing whatever shortcut it's set to in System Settings.
final class SpotlightLauncher {
    func currentShortcut() -> SpotlightShortcut {
        let domain = "com.apple.symbolichotkeys" as CFString
        CFPreferencesAppSynchronize(domain)
        let hotKeys = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, domain) as? [String: Any]
        return SpotlightShortcut.parse(symbolicHotKeys: hotKeys)
    }

    /// Returns the shortcut it found, so callers can warn when Spotlight's shortcut is off.
    @discardableResult
    func open() -> SpotlightShortcut {
        let shortcut = currentShortcut()
        if case .enabled(let keyCode, let flags) = shortcut {
            KeyPoster.post(keyCode: keyCode, flags: CGEventFlags(rawValue: flags))
        }
        return shortcut
    }
}
