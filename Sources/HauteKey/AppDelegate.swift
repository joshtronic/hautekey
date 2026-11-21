import AppKit
import HauteKeyCore
import os
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "dev.hautekey.app", category: "app")
    private let presenter = WindowPresenter()
    private let performer = ActionPerformer(
        appLauncher: AppLauncher(), snapper: WindowSnapper(), spotlight: SpotlightLauncher()
    )
    private var model: AppModel?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if handOffToRunningInstance() { return }

        let file = ConfigFile(url: ConfigFile.defaultURL)
        let (config, error) = loadOrSeedConfig(file)
        let controller = HyperController(config: config) { [unowned self] action, config in
            performer.perform(action, config: config)
        }
        let model = AppModel(file: file, config: config, configError: error, controller: controller)
        self.model = model
        menuBar = MenuBarController(model: model, presenter: presenter)
        presenter.onboardingView = { AnyView(OnboardingView(model: model)) }
        model.onPermissionsMissing = { [presenter] in presenter.showOnboarding() }
        model.onPermissionsGranted = { [presenter] in presenter.closeOnboarding() }
        model.startWatching()
        model.startPermissionPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.controller.stop()
    }

    /// Opening the app again (Finder, Spotlight, `open`) shows Settings; that's the way in
    /// when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        presenter.showSettings()
        return false
    }

    /// If another copy is already running, ask it to show Settings and quit this one.
    private func handOffToRunningInstance() -> Bool {
        let current = NSRunningApplication.current
        guard let bundleID = Bundle.main.bundleIdentifier,
              let other = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                  .first(where: { $0 != current })
        else { return false }
        if let url = other.bundleURL {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        NSApp.terminate(nil)
        return true
    }

    private func loadOrSeedConfig(_ file: ConfigFile) -> (Config, ConfigError?) {
        switch file.load() {
        case .loaded(let config, _):
            return (config, nil)
        case .failed(let error):
            log.error("config error: \(error.description, privacy: .public)")
            return (Config(), error)
        case .missing:
            let dock = UserDefaults(suiteName: "com.apple.dock")?.array(forKey: "persistent-apps") as? [[String: Any]] ?? []
            let config = DockSeeder.defaultConfig(pinnedBundleIDs: DockSeeder.pinnedBundleIDs(persistentApps: dock))
            do {
                try file.save(config)
            } catch {
                log.error("couldn't write config: \(error.localizedDescription, privacy: .public)")
            }
            return (config, nil)
        }
    }
}
