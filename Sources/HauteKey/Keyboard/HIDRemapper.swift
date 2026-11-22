import Foundation
import HauteKeyCore
import os

/// Sets the system-wide HID key mapping (the same mechanism as `hidutil`). Needs no special
/// permission. The mapping lasts until it's cleared, the user logs out, or the Mac restarts.
@MainActor
final class HIDRemapper {
    private let log = Logger(subsystem: "com.joshtronic.hautekey", category: "hid")

    func apply(hyperKey: HyperKey, capsLockToControl: Bool) {
        set(HIDMapping.hidutilJSON(HIDMapping.pairs(hyperKey: hyperKey, capsLockToControl: capsLockToControl)))
    }

    func clear() {
        set(HIDMapping.hidutilJSON([]))
    }

    private func set(_ json: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", json]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                log.error("hidutil exited \(process.terminationStatus) for \(json, privacy: .public)")
            }
        } catch {
            log.error("couldn't run hidutil: \(error.localizedDescription, privacy: .public)")
        }
    }
}
