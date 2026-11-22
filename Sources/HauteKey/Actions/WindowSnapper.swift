import AppKit
import ApplicationServices
import HauteKeyCore
import os

/// Private but long-stable AX call that returns a window's CGWindowID.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Moves and resizes the frontmost app's focused window using the Accessibility API.
@MainActor
final class WindowSnapper {
    private struct WindowKey: Hashable, Sendable {
        let pid: pid_t
        let id: UInt
    }

    private let log = Logger(subsystem: "dev.hautekey.app", category: "snap")
    private var memory = RestoreMemory<WindowKey>()

    func perform(_ action: SnapAction, restoreSize: RestoreSize) {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let window = focusedWindow(of: app.processIdentifier),
              let current = frame(of: window)
        else { return }

        let displays = usableDisplayFrames()
        guard let index = SnapGeometry.displayIndex(for: current, displays: displays) else { return }
        let usable = displays[index]
        let key = WindowKey(pid: app.processIdentifier, id: windowID(of: window))

        let target: CGRect
        if action == .restore {
            target = SnapGeometry.restoreFrame(
                remembered: memory.take(key), usable: usable, allUsable: displays, restoreSize: restoreSize
            )
        } else {
            memory.noteSnap(key, currentFrame: current)
            target = SnapGeometry.frame(for: action, usable: usable, restoreSize: restoreSize)
        }
        apply(target, to: window, action: action)
    }

    // MARK: - AX helpers

    private func focusedWindow(of pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        // A hung app would otherwise block this (main) thread, and with it all key input, for ~6 s.
        AXUIElementSetMessagingTimeout(app, 0.5)
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
        guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            if error != .noValue { log.info("no focused window (AX error \(error.rawValue))") }
            return nil
        }
        return (value as! AXUIElement)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let origin: CGPoint = axValue(window, kAXPositionAttribute, .cgPoint),
              let size: CGSize = axValue(window, kAXSizeAttribute, .cgSize)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private func axValue<T>(_ element: AXUIElement, _ attribute: String, _ type: AXValueType) -> T? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXValueGetTypeID()
        else { return nil }
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AXValueGetValue(raw as! AXValue, type, pointer) else { return nil }
        return pointer.pointee
    }

    private func set(_ window: AXUIElement, origin: CGPoint) {
        var origin = origin
        if let value = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
    }

    private func set(_ window: AXUIElement, size: CGSize) {
        var size = size
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
    }

    /// Position, size, position again (apps clamp size against the old position), then
    /// re-anchor if the app refused the exact size.
    private func apply(_ target: CGRect, to window: AXUIElement, action: SnapAction) {
        set(window, origin: target.origin)
        set(window, size: target.size)
        set(window, origin: target.origin)
        guard let actual = frame(of: window), actual.size != target.size else { return }
        set(window, origin: SnapGeometry.anchoredOrigin(for: action, actualSize: actual.size, target: target))
    }

    private func windowID(of window: AXUIElement) -> UInt {
        var id = CGWindowID(0)
        if _AXUIElementGetWindow(window, &id) == .success, id != 0 { return UInt(id) }
        return CFHash(window)
    }

    private func usableDisplayFrames() -> [CGRect] {
        let screens = NSScreen.screens
        guard let primaryHeight = screens.first?.frame.height else { return [] }
        return screens.map { SnapGeometry.axRect(fromCocoa: $0.visibleFrame, primaryHeight: primaryHeight) }
    }
}
