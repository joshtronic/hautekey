/// Builds first-run bindings from the apps pinned in the Dock, like GNOME's Super+number.
public enum DockSeeder {
    private static let numberKeys = Array("1234567890").map { BindableKey(String($0))! }

    /// `persistentApps` is the `persistent-apps` array from the `com.apple.dock` preferences.
    public static func pinnedBundleIDs(persistentApps: [[String: Any]]) -> [String] {
        persistentApps.compactMap { tile in
            guard let data = tile["tile-data"] as? [String: Any],
                  let id = data["bundle-identifier"] as? String,
                  id != "com.apple.finder"
            else { return nil }
            return id
        }
    }

    public static func defaultConfig(pinnedBundleIDs: [String]) -> Config {
        var config = Config()
        for (key, id) in zip(numberKeys, pinnedBundleIDs) {
            config.bindings[key] = .app(bundleID: id)
        }
        config.bindings[BindableKey("w")!] = .snap(.maximize)
        config.bindings[BindableKey("a")!] = .snap(.leftHalf)
        config.bindings[BindableKey("s")!] = .snap(.restore)
        config.bindings[BindableKey("d")!] = .snap(.rightHalf)
        return config
    }
}
