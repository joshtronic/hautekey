/// HID usage values for the system-wide `UserKeyMapping` (the mechanism behind `hidutil`).
/// Usages are `0x700000000 | usage ID` from the HID keyboard usage page.
public enum HIDMapping {
    public static let f18Usage: UInt64 = 0x70000006D
    public static let leftControlUsage: UInt64 = 0x7000000E0
    public static let capsLockUsage: UInt64 = 0x700000039

    public static func usage(for key: HyperKey) -> UInt64 {
        switch key {
        case .rightCommand: 0x7000000E7
        case .rightOption: 0x7000000E6
        case .rightControl: 0x7000000E4
        case .capsLock: capsLockUsage
        }
    }

    public static func pairs(hyperKey: HyperKey, capsLockToControl: Bool) -> [(src: UInt64, dst: UInt64)] {
        var result = [(src: usage(for: hyperKey), dst: f18Usage)]
        if capsLockToControl && hyperKey != .capsLock {
            result.append((src: capsLockUsage, dst: leftControlUsage))
        }
        return result
    }

    /// The argument for `hidutil property --set`. An empty list clears all mappings.
    public static func hidutilJSON(_ pairs: [(src: UInt64, dst: UInt64)]) -> String {
        let entries = pairs.map {
            #"{"HIDKeyboardModifierMappingSrc":\#($0.src),"HIDKeyboardModifierMappingDst":\#($0.dst)}"#
        }
        return #"{"UserKeyMapping":["# + entries.joined(separator: ",") + "]}"
    }
}
