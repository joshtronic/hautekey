import AppKit
import HauteKeyCore
import SwiftUI

/// A button that records the next key press (with modifiers) as the tap action's key combo.
struct KeyRecorderField: View {
    let keyCode: UInt16?
    let modifiers: Set<KeyModifier>
    let onRecord: (UInt16, Set<KeyModifier>) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(isRecording ? "Press a shortcut…" : title) {
            isRecording ? stopRecording() : startRecording()
        }
        .onDisappear(perform: stopRecording)
    }

    private var title: String {
        guard let keyCode else { return "Record Shortcut" }
        return Self.describe(keyCode: keyCode, modifiers: modifiers)
    }

    static func describe(keyCode: UInt16, modifiers: Set<KeyModifier>) -> String {
        let symbols: [(KeyModifier, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        let prefix = symbols.filter { modifiers.contains($0.0) }.map(\.1).joined()
        let key: String = switch keyCode {
        case 49: "Space"
        case 36: "Return"
        case 48: "Tab"
        default: KeyCodes.bindableKey(forKeyCode: keyCode)?.rawValue.uppercased() ?? "Key \(keyCode)"
        }
        return prefix + key
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            var recorded = Set<KeyModifier>()
            let flags = event.modifierFlags
            if flags.contains(.command) { recorded.insert(.command) }
            if flags.contains(.option) { recorded.insert(.option) }
            if flags.contains(.control) { recorded.insert(.control) }
            if flags.contains(.shift) { recorded.insert(.shift) }
            onRecord(event.keyCode, recorded)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
