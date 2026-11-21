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

    private func isKarabinerRunning() -> Bool {
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier?.hasPrefix("org.pqrs.") == true }) {
            return true
        }
        // The core service is a daemon, not an NSRunningApplication.
        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-x", "Karabiner-Core-Service"]
        pgrep.standardOutput = FileHandle.nullDevice
        pgrep.standardError = FileHandle.nullDevice
        guard (try? pgrep.run()) != nil else { return false }
        pgrep.waitUntilExit()
        return pgrep.terminationStatus == 0
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
