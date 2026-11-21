import Foundation
import HauteKeyCore

/// Owns everything that makes the Hyper key work: the HID remap, the event tap, and the
/// tap/hold state machine. Actions run after the event that triggered them is handled.
@MainActor
final class HyperController {
    private(set) var config: Config
    private let perform: @MainActor (HyperAction, Config) -> Void
    private var machine = HyperStateMachine()
    private let remapper = HIDRemapper()
    private lazy var tap = EventTap { [unowned self] input in handle(input) }
    private lazy var watcher = KeyboardWatcher { [unowned self] in applyMapping() }

    private(set) var isRunning = false

    init(config: Config, perform: @escaping @MainActor (HyperAction, Config) -> Void) {
        self.config = config
        self.perform = perform
    }

    /// Returns false if the event tap couldn't be created (usually missing permissions).
    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        guard tap.start() else { return false }
        machine.reset()
        applyMapping()
        watcher.start()
        isRunning = true
        return true
    }

    /// Puts the keyboard back to normal.
    func stop() {
        tap.stop()
        watcher.stop()
        remapper.clear()
        machine.reset()
        isRunning = false
    }

    func update(config newConfig: Config) {
        let needsRemap = newConfig.hyperKey != config.hyperKey
            || newConfig.effectiveCapsLockToControl != config.effectiveCapsLockToControl
        config = newConfig
        if isRunning && needsRemap { applyMapping() }
    }

    private func applyMapping() {
        remapper.apply(hyperKey: config.hyperKey, capsLockToControl: config.effectiveCapsLockToControl)
    }

    private func handle(_ input: HyperInput) -> HyperDecision {
        let decision = machine.handle(input)
        if let action = decision.action {
            let config = config
            DispatchQueue.main.async { [perform] in
                MainActor.assumeIsolated { perform(action, config) }
            }
        }
        return decision
    }
}
