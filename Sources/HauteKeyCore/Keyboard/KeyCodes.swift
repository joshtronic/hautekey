/// macOS virtual key codes (Carbon `kVK_*` from HIToolbox `Events.h`). These are physical
/// positions on a US layout, so bindings follow the key's position on other layouts.
public enum KeyCodes {
    /// The key the Hyper key is remapped to.
    public static let f18: UInt16 = 79

    private static let codes: [String: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
        "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
    ]

    private static let keysByCode: [UInt16: BindableKey] =
        Dictionary(uniqueKeysWithValues: codes.map { (code: $0.value, key: BindableKey($0.key)!) }.map { ($0.code, $0.key) })

    public static func bindableKey(forKeyCode code: UInt16) -> BindableKey? {
        keysByCode[code]
    }

    public static func keyCode(for key: BindableKey) -> UInt16 {
        codes[key.rawValue]!
    }
}
