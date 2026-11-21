import Testing
@testable import HauteKeyCore

private func tile(_ bundleID: String?) -> [String: Any] {
    var data: [String: Any] = ["file-label": "App"]
    if let bundleID { data["bundle-identifier"] = bundleID }
    return ["tile-data": data, "tile-type": "file-tile"]
}

private let snapDefaults: [BindableKey: KeyBinding] = [
    BindableKey("w")!: .snap(.maximize),
    BindableKey("a")!: .snap(.leftHalf),
    BindableKey("s")!: .snap(.restore),
    BindableKey("d")!: .snap(.rightHalf),
]

@Test func fourteenAppsBindFirstTen() {
    let ids = (0..<14).map { "app\($0)" }
    let config = DockSeeder.defaultConfig(pinnedBundleIDs: ids)
    #expect(config.bindings[BindableKey("1")!] == .app(bundleID: "app0"))
    #expect(config.bindings[BindableKey("9")!] == .app(bundleID: "app8"))
    #expect(config.bindings[BindableKey("0")!] == .app(bundleID: "app9"))
    #expect(config.bindings.values.contains(.app(bundleID: "app10")) == false)
    #expect(config.bindings.count == 14)
}

@Test func fourAppsBindOneToFour() {
    let config = DockSeeder.defaultConfig(pinnedBundleIDs: ["a.1", "a.2", "a.3", "a.4"])
    #expect(config.bindings[BindableKey("4")!] == .app(bundleID: "a.4"))
    for key in ["5", "6", "7", "8", "9", "0"] {
        #expect(config.bindings[BindableKey(key)!] == nil)
    }
}

@Test func emptyDockStillGetsSnapKeys() {
    #expect(DockSeeder.defaultConfig(pinnedBundleIDs: []).bindings == snapDefaults)
}

@Test func otherSettingsAreDefaults() {
    var config = DockSeeder.defaultConfig(pinnedBundleIDs: [])
    config.bindings = [:]
    #expect(config == Config.empty)
}

@Test func skipsFinderAndTilesWithoutBundleID() {
    let apps = [tile("com.apple.finder"), tile(nil), tile("com.tinyspeck.slackmacgap")]
    #expect(DockSeeder.pinnedBundleIDs(persistentApps: apps) == ["com.tinyspeck.slackmacgap"])
}

@Test func keepsDockOrder() {
    let apps = [tile("b.second"), tile("a.first")].reversed().map { $0 }
    #expect(DockSeeder.pinnedBundleIDs(persistentApps: apps) == ["a.first", "b.second"])
}
