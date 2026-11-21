import AppKit
import ApplicationServices
import HauteKeyCore
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "dev.hautekey.app", category: "app")
    private let configFile = ConfigFile(url: ConfigFile.defaultURL)
    private let performer = ActionPerformer(
        appLauncher: AppLauncher(), snapper: WindowSnapper(), spotlight: SpotlightLauncher()
    )
    private var controller: HyperController!
    private var statusItem: NSStatusItem!
    private var startTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = loadOrSeedConfig()
        controller = HyperController(config: config) { [unowned self] action, config in
            performer.perform(action, config: config)
        }
        setUpMenu()

        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        _ = CGRequestListenEventAccess()
        startWhenPermitted()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }

    private func loadOrSeedConfig() -> Config {
        switch configFile.load() {
        case .loaded(let config, _):
            return config
        case .failed(let error):
            log.error("config error: \(error.description, privacy: .public)")
            return Config()
        case .missing:
            let dock = UserDefaults(suiteName: "com.apple.dock")?.array(forKey: "persistent-apps") as? [[String: Any]] ?? []
            let config = DockSeeder.defaultConfig(pinnedBundleIDs: DockSeeder.pinnedBundleIDs(persistentApps: dock))
            do {
                try configFile.save(config)
            } catch {
                log.error("couldn't write config: \(error.localizedDescription, privacy: .public)")
            }
            return config
        }
    }

    /// Retries every second until the event tap can be created (permissions granted).
    private func startWhenPermitted() {
        if controller.start() { return }
        startTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.controller.start() else { return }
                self.startTimer?.invalidate()
                self.startTimer = nil
            }
        }
    }

    private func setUpMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "HK"
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Haute Key", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }
}
