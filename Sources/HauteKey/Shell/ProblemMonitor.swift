import AppKit
import Carbon
import Combine
import HauteKeyCore

/// Checks every few seconds for things that stop the Hyper key from working, and makes sure the
/// user hears about new problems even when the menu bar icon is hidden.
@MainActor
final class ProblemMonitor {
    private let model: AppModel
    private let spotlight: SpotlightLauncher
    private let presenter: WindowPresenter
    private var timer: Timer?
    private var subscriptions = Set<AnyCancellable>()

    init(model: AppModel, spotlight: SpotlightLauncher, presenter: WindowPresenter) {
        self.model = model
        self.spotlight = spotlight
        self.presenter = presenter
    }

    func start() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        // Config errors arrive from the file watcher, not the poll; react to both right away.
        model.$configError.combineLatest(model.$detectedProblems)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.surfaceIfHidden() }
            .store(in: &subscriptions)
    }

    private func check() {
        var found: [Problem] = []
        if isKarabinerRunning() { found.append(.karabinerRunning) }
        if IsSecureEventInputEnabled() { found.append(.secureInput) }
        if model.config.tapAction == .spotlight, spotlight.currentShortcut() == .disabled {
            found.append(.spotlightShortcutDisabled)
        }
        if found != model.detectedProblems { model.detectedProblems = found }
    }

    /// Karabiner's system daemon keeps running even after Karabiner is quit, so it isn't a
    /// signal. Karabiner is only active when its per-user agents are loaded.
    private func isKarabinerRunning() -> Bool {
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier?.hasPrefix("org.pqrs.") == true }) {
            return true
        }
        let launchctl = Process()
        let output = Pipe()
        launchctl.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        launchctl.arguments = ["list"]
        launchctl.standardOutput = output
        launchctl.standardError = FileHandle.nullDevice
        guard (try? launchctl.run()) != nil else { return false }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        launchctl.waitUntilExit()
        return String(decoding: data, as: UTF8.self).contains("org.pqrs.service.agent.")
    }

    /// With the icon hidden, open Settings once for each new problem. Secure input is left out:
    /// it turns on in every password field and would pop the window constantly.
    private func surfaceIfHidden() {
        let current = model.problems.filter { $0 != .secureInput }
        let currentIDs = Set(current.map(\.id))
        var shown = model.settings.shownProblemIDs.filter(currentIDs.contains)
        defer { model.settings.shownProblemIDs = shown }
        guard !model.showMenuBarIcon else { return }
        let new = current.filter { !shown.contains($0.id) }
        guard !new.isEmpty else { return }
        shown += new.map(\.id)
        presenter.showSettings()
    }
}
