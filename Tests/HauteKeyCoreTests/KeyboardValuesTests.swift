import Foundation
import Testing
@testable import HauteKeyCore

@Test(arguments: [
    ("a", 0), ("s", 1), ("d", 2), ("w", 13), ("q", 12), ("1", 18), ("5", 23), ("0", 29), ("l", 37), ("m", 46),
] as [(String, UInt16)])
func keyCodesMatchCarbon(key: String, code: UInt16) {
    let bindable = BindableKey(key)!
    #expect(KeyCodes.keyCode(for: bindable) == code)
    #expect(KeyCodes.bindableKey(forKeyCode: code) == bindable)
}

@Test func allThirtySixKeysHaveUniqueCodes() {
    #expect(Set(BindableKey.all.map(KeyCodes.keyCode(for:))).count == 36)
}

@Test func nonBindableCodeIsNil() {
    #expect(KeyCodes.bindableKey(forKeyCode: 49) == nil)   // space
    #expect(KeyCodes.bindableKey(forKeyCode: KeyCodes.f18) == nil)
}

@Test func f18KeyCode() {
    #expect(KeyCodes.f18 == 79)
}

@Test func rightCommandMapsToF18Only() {
    let pairs = HIDMapping.pairs(hyperKey: .rightCommand, capsLockToControl: false)
    #expect(pairs.map(\.src) == [0x7000000E7])
    #expect(pairs.map(\.dst) == [0x70000006D])
}

@Test(arguments: [
    (HyperKey.rightOption, 0x7000000E6), (.rightControl, 0x7000000E4), (.capsLock, 0x700000039),
] as [(HyperKey, UInt64)])
func hyperKeyUsages(key: HyperKey, usage: UInt64) {
    #expect(HIDMapping.usage(for: key) == usage)
}

@Test func capsToControlAddsSecondPair() {
    let pairs = HIDMapping.pairs(hyperKey: .rightCommand, capsLockToControl: true)
    #expect(pairs.count == 2)
    #expect(pairs[1].src == 0x700000039)
    #expect(pairs[1].dst == 0x7000000E0)
}

@Test func capsHyperIgnoresCapsToControl() {
    let pairs = HIDMapping.pairs(hyperKey: .capsLock, capsLockToControl: true)
    #expect(pairs.map(\.src) == [0x700000039])
    #expect(pairs.map(\.dst) == [0x70000006D])
}

@Test func hidutilJSONIsValidJSON() throws {
    let json = HIDMapping.hidutilJSON(HIDMapping.pairs(hyperKey: .rightCommand, capsLockToControl: false))
    let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    let mapping = try #require(object?["UserKeyMapping"] as? [[String: Any]])
    #expect((mapping[0]["HIDKeyboardModifierMappingSrc"] as? NSNumber)?.uint64Value == 30064771303)
    #expect((mapping[0]["HIDKeyboardModifierMappingDst"] as? NSNumber)?.uint64Value == 30064771181)
}

@Test func hidutilJSONEmptyClearsMapping() {
    #expect(HIDMapping.hidutilJSON([]) == #"{"UserKeyMapping":[]}"#)
}

@Test func spotlightDefaultWhenMissing() {
    #expect(SpotlightShortcut.parse(symbolicHotKeys: nil) == .fallback)
    #expect(SpotlightShortcut.parse(symbolicHotKeys: [:]) == .fallback)
    #expect(SpotlightShortcut.fallback == .enabled(keyCode: 49, modifierFlags: 0x100000))
}

@Test func spotlightOptionSpace() {
    let hotKeys: [String: Any] = [
        "64": ["enabled": 1, "value": ["parameters": [32, 49, 524288], "type": "standard"]],
    ]
    #expect(SpotlightShortcut.parse(symbolicHotKeys: hotKeys) == .enabled(keyCode: 49, modifierFlags: 524288))
}

@Test func spotlightDisabled() {
    let hotKeys: [String: Any] = [
        "64": ["enabled": false, "value": ["parameters": [32, 49, 1048576], "type": "standard"]],
    ]
    #expect(SpotlightShortcut.parse(symbolicHotKeys: hotKeys) == .disabled)
}
