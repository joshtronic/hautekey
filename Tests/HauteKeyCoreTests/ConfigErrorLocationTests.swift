import Testing
@testable import HauteKeyCore

private let text = """
{
  "bindings" : {
    "1" : { "app" : "org.mozilla.firefox" },
    "w" : {
      "snap" : "quarter"
    }
  },
  "hyperKey" : "leftCommand",
  "tapAction" : { "type" : "launchpad" }
}
"""

@Test func syntaxErrorUsesItsLine() {
    #expect(ConfigError.syntax(line: 4, message: "x").line(in: text) == 4)
}

@Test func syntaxErrorWithoutLineIsNil() {
    #expect(ConfigError.syntax(line: nil, message: "x").line(in: text) == nil)
}

@Test func invalidNestedFieldFindsDeepestKey() {
    #expect(ConfigError.invalid(field: "bindings.w.snap", message: "x").line(in: text) == 5)
}

@Test func invalidTopLevelFieldFindsKey() {
    #expect(ConfigError.invalid(field: "hyperKey", message: "x").line(in: text) == 8)
}

@Test func invalidFieldOnSameLineAsParent() {
    #expect(ConfigError.invalid(field: "tapAction.type", message: "x").line(in: text) == 9)
}

@Test func invalidBindingKeyFindsKey() {
    #expect(ConfigError.invalid(field: "bindings.1", message: "x").line(in: text) == 3)
}

@Test func unknownFieldFallsBackToDeepestFound() {
    #expect(ConfigError.invalid(field: "bindings.w.nothing", message: "x").line(in: text) == 4)
    #expect(ConfigError.invalid(field: "(root)", message: "x").line(in: text) == nil)
}
