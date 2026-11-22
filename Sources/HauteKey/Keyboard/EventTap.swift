import CoreGraphics
import HauteKeyCore
import os

/// An active session event tap that turns key and mouse events into `HyperInput`s and drops
/// the ones the handler says to consume. Needs Input Monitoring and Accessibility.
/// Runs on the main run loop, so the handler is called on the main actor.
@MainActor
final class EventTap {
    private let handler: @MainActor (HyperInput) -> HyperDecision
    /// Called when macOS disables the tap; events missed meanwhile (like Hyper's key-up) are lost.
    var onDisabled: @MainActor () -> Void = {}
    private let log = Logger(subsystem: "dev.hautekey.app", category: "tap")
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    init(handler: @escaping @MainActor (HyperInput) -> HyperDecision) {
        self.handler = handler
    }

    var isRunning: Bool { port != nil }

    func start() -> Bool {
        if isRunning { return true }
        let types: [CGEventType] = [.keyDown, .keyUp, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<EventTap>.fromOpaque(context).takeUnretainedValue()
                // Pull out plain values here; CGEvent isn't Sendable.
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                let consume = MainActor.assumeIsolated {
                    tap.shouldConsume(type: type, keyCode: keyCode, isRepeat: isRepeat)
                }
                return consume ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        return true
    }

    func stop() {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(port)
        self.port = nil
        self.source = nil
    }

    private func shouldConsume(type: CGEventType, keyCode: UInt16, isRepeat: Bool) -> Bool {
        let input: HyperInput
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            log.notice("event tap was disabled (\(type.rawValue)); re-enabling")
            onDisabled()
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return false
        case .keyDown where keyCode == KeyCodes.f18:
            input = .hyperDown
        case .keyUp where keyCode == KeyCodes.f18:
            input = .hyperUp
        case .keyDown:
            input = .keyDown(keyCode: keyCode, isRepeat: isRepeat)
        case .keyUp:
            input = .keyUp(keyCode: keyCode)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            input = .mouseDown
        default:
            return false
        }
        return handler(input).consume
    }
}
