import Foundation
import IOKit.hid

/// Calls back when a keyboard is connected, so the key mapping can be re-applied to it.
/// Also fires once for keyboards already connected when it starts.
@MainActor
final class KeyboardWatcher {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private let onKeyboardConnected: @MainActor () -> Void
    private var pending: DispatchWorkItem?
    private var isRunning = false

    init(onKeyboardConnected: @escaping @MainActor () -> Void) {
        self.onKeyboardConnected = onKeyboardConnected
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let matching: [String: Int] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
            guard let context else { return }
            let watcher = Unmanaged<KeyboardWatcher>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.keyboardMatched() }
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        pending?.cancel()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    /// Debounced: plugging in a dock can announce several keyboards at once.
    private func keyboardMatched() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.onKeyboardConnected() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
}
