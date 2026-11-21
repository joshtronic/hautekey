/// Spotlight's keyboard shortcut as set in System Settings (symbolic hot key 64).
public enum SpotlightShortcut: Equatable, Sendable {
    /// `modifierFlags` uses the same bits as `CGEventFlags` (⌘ = 0x100000).
    case enabled(keyCode: UInt16, modifierFlags: UInt64)
    case disabled

    /// macOS's default when the user never changed the shortcut: ⌘Space.
    public static let fallback = SpotlightShortcut.enabled(keyCode: 49, modifierFlags: 0x100000)

    /// `symbolicHotKeys` is the `AppleSymbolicHotKeys` dictionary from `com.apple.symbolichotkeys`.
    public static func parse(symbolicHotKeys: [String: Any]?) -> SpotlightShortcut {
        guard let entry = symbolicHotKeys?["64"] as? [String: Any] else { return fallback }
        if let enabled = entry["enabled"] as? Bool, !enabled { return .disabled }
        if let enabled = entry["enabled"] as? Int, enabled == 0 { return .disabled }
        guard let value = entry["value"] as? [String: Any],
              let parameters = value["parameters"] as? [Int], parameters.count >= 3,
              let keyCode = UInt16(exactly: parameters[1]), let flags = UInt64(exactly: parameters[2])
        else { return fallback }
        return .enabled(keyCode: keyCode, modifierFlags: flags)
    }
}
