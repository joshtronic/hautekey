import Foundation
import Testing
@testable import HauteKeyCore

private let canonicalSample = """
{
  "bindings" : {
    "1" : {
      "app" : "org.mozilla.firefox"
    },
    "w" : {
      "snap" : "maximize"
    }
  },
  "capsLockToControl" : true,
  "hyperKey" : "rightCommand",
  "restoreSize" : {
    "height" : 0.6,
    "width" : 0.6
  },
  "tapAction" : {
    "type" : "spotlight"
  },
  "version" : 1
}

"""

private func decode(_ json: String) throws(ConfigError) -> Config {
    try ConfigCodec.decode(Data(json.utf8))
}

private func invalidField(_ json: String) -> String? {
    do {
        _ = try decode(json)
        return nil
    } catch {
        if case .invalid(let field, _) = error { return field }
        return nil
    }
}

@Test func roundTripsCanonicalFileByteForByte() throws {
    let data = Data(canonicalSample.utf8)
    let encoded = ConfigCodec.encode(try ConfigCodec.decode(data))
    #expect(String(decoding: encoded, as: UTF8.self) == canonicalSample)
}

@Test func decodesCanonicalValues() throws {
    let c = try decode(canonicalSample)
    #expect(c.hyperKey == .rightCommand)
    #expect(c.capsLockToControl)
    #expect(c.tapAction == .spotlight)
    #expect(c.bindings[BindableKey("1")!] == .app(bundleID: "org.mozilla.firefox"))
    #expect(c.bindings[BindableKey("w")!] == .snap(.maximize))
    #expect(c.restoreSize == .default)
}

@Test func preservesUnknownTopLevelKey() throws {
    let c = try decode(#"{"version":1,"futureThing":{"a":[1,true]}}"#)
    let text = String(decoding: ConfigCodec.encode(c), as: UTF8.self)
    #expect(text.contains(#""futureThing""#))
    #expect(try decode(text) == c)
}

@Test func missingFieldsUseDefaults() throws {
    #expect(try decode("{}") == Config.empty)
}

@Test func uppercaseKeyIsNormalized() throws {
    let c = try decode(#"{"bindings":{"W":{"snap":"maximize"}}}"#)
    #expect(c.bindings[BindableKey("w")!] == .snap(.maximize))
    #expect(String(decoding: ConfigCodec.encode(c), as: UTF8.self).contains(#""w" : {"#))
}

@Test(arguments: [
    (#"{"bindings":{"w":{"snap":"maximize"},"W":{"snap":"maximize"}}}"#, "bindings.w"),
    (#"{"bindings":{"10":{"app":"a.b"}}}"#, "bindings.10"),
    (#"{"bindings":{"f1":{"app":"a.b"}}}"#, "bindings.f1"),
    (#"{"bindings":{"w":{"snap":"quarter"}}}"#, "bindings.w.snap"),
    (#"{"bindings":{"w":{"app":"a.b","snap":"maximize"}}}"#, "bindings.w"),
    (#"{"bindings":{"w":{}}}"#, "bindings.w"),
    (#"{"hyperKey":"leftCommand"}"#, "hyperKey"),
    (#"{"tapAction":{"type":"launchpad"}}"#, "tapAction.type"),
    (#"{"tapAction":{"type":"app"}}"#, "tapAction.bundleId"),
    (#"{"tapAction":{"type":"keys","keyCode":49,"modifiers":["hyper"]}}"#, "tapAction.modifiers"),
    (#"{"restoreSize":{"width":0,"height":0.6}}"#, "restoreSize.width"),
    (#"{"version":2}"#, "version"),
    (#"{"capsLockToControl":"yes"}"#, "capsLockToControl"),
])
func invalidValuesNameTheField(json: String, field: String) {
    #expect(invalidField(json) == field)
}

@Test func syntaxErrorReportsLine() {
    let json = "{\n  \"version\" : 1\n  \"hyperKey\" : \"capsLock\"\n}"
    do {
        _ = try decode(json)
        Issue.record("expected a syntax error")
    } catch {
        guard case .syntax(let line, _) = error else {
            Issue.record("expected .syntax, got \(error)")
            return
        }
        #expect(line == 3)
    }
}

@Test func topLevelArrayIsInvalid() {
    #expect(throws: ConfigError.self) { try decode("[]") }
}

@Test func capsLockHyperDisablesCapsToControl() throws {
    let c = try decode(#"{"hyperKey":"capsLock","capsLockToControl":true}"#)
    #expect(c.effectiveCapsLockToControl == false)
}

@Test func tapActionVariantsRoundTrip() throws {
    var c = Config.empty
    c.tapAction = .keys(keyCode: 49, modifiers: [.option, .command])
    let text = String(decoding: ConfigCodec.encode(c), as: UTF8.self)
    #expect(text.contains(#""modifiers" : ["#))
    #expect(try decode(text) == c)

    c.tapAction = .app(bundleID: "com.raycast.macos")
    #expect(try decode(String(decoding: ConfigCodec.encode(c), as: UTF8.self)) == c)
}

@Test func bindableKeyOrderIsNumbersThenLetters() {
    #expect(BindableKey.all.count == 36)
    #expect(BindableKey.all.first?.rawValue == "1")
    #expect(BindableKey.all[9].rawValue == "0")
    #expect(BindableKey.all.last?.rawValue == "z")
}
