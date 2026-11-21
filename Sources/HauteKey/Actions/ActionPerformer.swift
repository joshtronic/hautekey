import AppKit
import HauteKeyCore

/// Runs what a Hyper tap or Hyper+key means under the current config.
@MainActor
final class ActionPerformer {
    private let appLauncher: AppLauncher
    private let snapper: WindowSnapper
    private let spotlight: SpotlightLauncher

    /// Called when a binding (or the tap action, with nil) points at an app that isn't installed.
    var onMissingApp: (BindableKey?) -> Void = { _ in }

    init(appLauncher: AppLauncher, snapper: WindowSnapper, spotlight: SpotlightLauncher) {
        self.appLauncher = appLauncher
        self.snapper = snapper
        self.spotlight = spotlight
    }

    func perform(_ action: HyperAction, config: Config) {
        switch action {
        case .tap:
            switch config.tapAction {
            case .spotlight:
                spotlight.open()
            case .app(let bundleID):
                openApp(bundleID, key: nil)
            case .keys(let keyCode, let modifiers):
                KeyPoster.post(keyCode: keyCode, flags: Self.flags(for: modifiers))
            }
        case .binding(let key):
            switch config.bindings[key] {
            case .app(let bundleID)?:
                openApp(bundleID, key: key)
            case .snap(let snap)?:
                snapper.perform(snap, restoreSize: config.restoreSize)
            case nil:
                break
            }
        }
    }

    private func openApp(_ bundleID: String, key: BindableKey?) {
        if !appLauncher.open(bundleID: bundleID) {
            NSSound.beep()
            onMissingApp(key)
        }
    }

    static func flags(for modifiers: Set<KeyModifier>) -> CGEventFlags {
        var flags = CGEventFlags()
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        return flags
    }
}
