import AppKit
import Combine
import Foundation
import HauteKeyCore
import os
import ServiceManagement

/// Something the user should know about, shown in the menu and at the top of Settings.
enum Problem: Hashable, Identifiable {
    case configError(String)
    case karabinerRunning
    case secureInput
    case spotlightShortcutDisabled

    var id: String {
        switch self {
        case .configError(let message): "config:\(message)"
        case .karabinerRunning: "karabiner"
        case .secureInput: "secureInput"
        case .spotlightShortcutDisabled: "spotlightOff"
        }
    }

    /// Short form for the menu bar menu; `message` has the full explanation for Settings.
    var title: String {
        switch self {
        case .configError: "Settings file has an error"
        case .karabinerRunning: "Karabiner-Elements is running"
        case .secureInput: "Secure keyboard entry is on"
        case .spotlightShortcutDisabled: "Spotlight's shortcut is off"
        }
    }

    var message: String {
        switch self {
        case .configError(let message):
            "The settings file has an error, so the last working settings are still in use. \(message)"
        case .karabinerRunning:
            "Karabiner-Elements is running and may grab the keyboard first. Quit it from its menu bar icon; if the problem persists, use Karabiner's uninstaller."
        case .secureInput:
            "Another app has turned on secure keyboard entry (a password field or Terminal's Secure Keyboard Entry), so the Hyper key can't work until it's off."
        case .spotlightShortcutDisabled:
            "Spotlight's keyboard shortcut is turned off. Turn it back on in System Settings → Keyboard → Keyboard Shortcuts → Spotlight."
        }
    }
}

/// The app's state: the current config, pause state, and problems. Settings and the menu read it.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var config: Config
    @Published private(set) var configError: ConfigError?
    @Published private(set) var showMenuBarIcon: Bool
    /// Problems found by the problem monitor (everything except config errors).
    @Published var detectedProblems: [Problem] = []
    @Published private(set) var hasAccessibility = Permissions.accessibility
    @Published private(set) var hasInputMonitoring = Permissions.inputMonitoring

    /// Called when permissions go missing (at launch or revoked later) and when they're all back.
    var onPermissionsMissing: () -> Void = {}
    var onPermissionsGranted: () -> Void = {}

    let file: ConfigFile
    let controller: HyperController
    let settings = LocalSettings()
    private let log = Logger(subsystem: "dev.hautekey.app", category: "model")
    private lazy var watcher = ConfigWatcher(file: file) { [unowned self] in reloadFromDisk() }
    private var permissionTimer: Timer?
    /// False while another user's session is in front; the key mapping is system-wide.
    private var isSessionActive = true

    init(file: ConfigFile, config: Config, configError: ConfigError?, controller: HyperController) {
        self.file = file
        self.config = config
        self.configError = configError
        self.controller = controller
        showMenuBarIcon = settings.showMenuBarIcon
    }

    var problems: [Problem] {
        (configError.map { [.configError($0.description)] } ?? []) + detectedProblems
    }

    func startWatching() {
        watcher.start()
    }

    /// Checks permissions now and then every second: starts the Hyper key once both are
    /// granted, and puts the keyboard back to normal if either is revoked.
    func startPermissionPolling() {
        if !Permissions.allGranted {
            onPermissionsMissing()
        }
        checkPermissions()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPermissions() }
        }
    }

    private func checkPermissions() {
        hasAccessibility = Permissions.accessibility
        hasInputMonitoring = Permissions.inputMonitoring
        let granted = hasAccessibility && hasInputMonitoring

        if !granted {
            if controller.isRunning {
                log.notice("a permission was revoked; stopping")
                controller.stop()
                onPermissionsMissing()
            }
            return
        }
        guard isSessionActive, !controller.isRunning, controller.start() else { return }
        if !settings.onboardingDone {
            settings.onboardingDone = true
            do {
                try SMAppService.mainApp.register()
            } catch {
                log.error("couldn't enable launch at login: \(error.localizedDescription, privacy: .public)")
            }
        }
        onPermissionsGranted()
    }

    /// Changes the config and saves it. Refused while the file has an error, so the app never
    /// overwrites a file the user is in the middle of fixing.
    func edit(_ change: (inout Config) -> Void) {
        guard configError == nil else { return }
        var updated = config
        change(&updated)
        guard updated != config else { return }
        do {
            let data = try file.save(updated)
            watcher.noteOwnWrite(data)
            apply(updated)
        } catch {
            log.error("couldn't save config: \(error.localizedDescription, privacy: .public)")
        }
    }

    func reloadFromDisk() {
        switch file.load() {
        case .loaded(let loaded, _):
            configError = nil
            apply(loaded)
        case .failed(let error):
            configError = error
        case .missing:
            // Deleted while running: keep the last good settings. Seeding only happens at launch.
            break
        }
    }

    /// Validates and writes text from the raw editor exactly as typed. Returns the error
    /// instead of saving when the text isn't a valid config.
    func saveRaw(_ text: String) -> ConfigError? {
        let data = Data(text.utf8)
        let parsed: Config
        do {
            parsed = try ConfigCodec.decode(data)
        } catch {
            return error
        }
        do {
            try file.write(data)
        } catch {
            return .syntax(line: nil, message: "Couldn't save: \(error.localizedDescription)")
        }
        watcher.noteOwnWrite(data)
        configError = nil
        apply(parsed)
        return nil
    }

    func revealConfigFile() {
        NSWorkspace.shared.activateFileViewerSelecting([file.resolvedURL()])
    }

    /// Fast user switching: the HID mapping is system-wide, so give the keyboard back while
    /// another user is active, and pick up again on return.
    func setSessionActive(_ active: Bool) {
        isSessionActive = active
        if active { checkPermissions() } else { controller.stop() }
    }

    func setShowMenuBarIcon(_ show: Bool) {
        showMenuBarIcon = show
        settings.showMenuBarIcon = show
    }

    private func apply(_ updated: Config) {
        config = updated
        controller.update(config: updated)
    }
}
