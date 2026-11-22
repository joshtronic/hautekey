import Foundation

/// Carries per-Mac settings over when the app's bundle ID (and so its defaults domain) changes.
public enum DefaultsMigration {
    /// Copies each key that has a value in `old` but none in `new`. Existing values win.
    public static func copyMissing(keys: [String], from old: UserDefaults, to new: UserDefaults) {
        for key in keys where new.object(forKey: key) == nil {
            if let value = old.object(forKey: key) { new.set(value, forKey: key) }
        }
    }
}
