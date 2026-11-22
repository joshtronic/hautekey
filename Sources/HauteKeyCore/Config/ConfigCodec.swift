import Foundation

public enum ConfigError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The file isn't valid JSON. `line` is 1-based when Foundation reports it.
    case syntax(line: Int?, message: String)
    /// The JSON is valid but a value isn't. `field` is a dotted path such as `bindings.w.snap`.
    case invalid(field: String, message: String)

    public var description: String {
        switch self {
        case .syntax(let line?, let message): "Line \(line): \(message)"
        case .syntax(nil, let message): message
        case .invalid(let field, let message): "\(field): \(message)"
        }
    }
}

public enum ConfigCodec {
    public static let supportedVersion = 1

    private static let knownKeys: Set<String> = [
        "version", "hyperKey", "capsLockToControl", "tapAction", "bindings", "restoreSize",
    ]

    public static func decode(_ data: Data) throws(ConfigError) -> Config {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw syntaxError(from: error)
        }
        guard case .object(let root) = JSONValue(foundation: parsed) else {
            throw .invalid(field: "(root)", message: "must be a JSON object")
        }

        var config = Config()
        if let value = root["version"] {
            // Int(exactly:) instead of Int(_:), which traps on huge values like 1e20.
            guard case .number(let n) = value, let version = Int(exactly: n), version >= 1 else {
                throw .invalid(field: "version", message: "must be a whole number starting at 1")
            }
            guard version <= supportedVersion else {
                throw .invalid(field: "version", message: "\(version) is newer than this app supports (\(supportedVersion))")
            }
            config.version = supportedVersion
        }
        if let value = root["hyperKey"] {
            config.hyperKey = try enumValue(value, field: "hyperKey")
        }
        if let value = root["capsLockToControl"] {
            guard case .bool(let flag) = value else {
                throw .invalid(field: "capsLockToControl", message: "must be true or false")
            }
            config.capsLockToControl = flag
        }
        if let value = root["tapAction"] {
            config.tapAction = try tapAction(value)
        }
        if let value = root["bindings"] {
            config.bindings = try bindings(value)
        }
        if let value = root["restoreSize"] {
            config.restoreSize = try restoreSize(value)
        }
        config.extra = root.filter { !knownKeys.contains($0.key) }
        return config
    }

    public static func encode(_ config: Config) -> Data {
        var root = config.extra
        root["version"] = .number(Double(config.version))
        root["hyperKey"] = .string(config.hyperKey.rawValue)
        root["capsLockToControl"] = .bool(config.capsLockToControl)
        root["tapAction"] = tapActionJSON(config.tapAction)
        root["bindings"] = .object(Dictionary(uniqueKeysWithValues: config.bindings.map { key, binding in
            switch binding {
            case .app(let id): (key.rawValue, .object(["app": .string(id)]))
            case .snap(let action): (key.rawValue, .object(["snap": .string(action.rawValue)]))
            }
        }))
        root["restoreSize"] = .object([
            "width": .number(config.restoreSize.width),
            "height": .number(config.restoreSize.height),
        ])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        // Encoding a JSONValue tree can't fail.
        var data = try! encoder.encode(JSONValue.object(root))
        data.append(0x0A)
        return data
    }

    // MARK: - Decoding helpers

    private static func syntaxError(from error: Error) -> ConfigError {
        let nsError = error as NSError
        let text = (nsError.userInfo[NSDebugDescriptionErrorKey] as? String) ?? nsError.localizedDescription
        var line: Int?
        if let range = text.range(of: #"line (\d+)"#, options: .regularExpression) {
            line = Int(text[range].dropFirst("line ".count))
        }
        return .syntax(line: line, message: text)
    }

    private static func enumValue<E: RawRepresentable & CaseIterable>(
        _ value: JSONValue, field: String
    ) throws(ConfigError) -> E where E.RawValue == String {
        guard case .string(let raw) = value, let result = E(rawValue: raw) else {
            let options = E.allCases.map(\.rawValue).joined(separator: ", ")
            throw .invalid(field: field, message: "must be one of: \(options)")
        }
        return result
    }

    private static func string(_ value: JSONValue?, field: String) throws(ConfigError) -> String {
        guard case .string(let s)? = value, !s.isEmpty else {
            throw .invalid(field: field, message: "must be a non-empty string")
        }
        return s
    }

    private static func tapAction(_ value: JSONValue) throws(ConfigError) -> TapAction {
        guard case .object(let object) = value else {
            throw .invalid(field: "tapAction", message: "must be an object")
        }
        guard case .string(let type)? = object["type"] else {
            throw .invalid(field: "tapAction.type", message: "must be spotlight, app, or keys")
        }
        switch type {
        case "spotlight":
            return .spotlight
        case "app":
            return .app(bundleID: try string(object["bundleId"], field: "tapAction.bundleId"))
        case "keys":
            guard case .number(let code)? = object["keyCode"], code >= 0, code <= 127, code == code.rounded() else {
                throw .invalid(field: "tapAction.keyCode", message: "must be a key code from 0 to 127")
            }
            guard UInt16(code) != KeyCodes.f18 else {
                // The Hyper key is F18 internally; sending it would trigger the tap again, forever.
                throw .invalid(field: "tapAction.keyCode", message: "can't be the Hyper key itself")
            }
            var modifiers = Set<KeyModifier>()
            if let raw = object["modifiers"] {
                guard case .array(let items) = raw else {
                    throw .invalid(field: "tapAction.modifiers", message: "must be a list")
                }
                for item in items {
                    let modifier: KeyModifier = try enumValue(item, field: "tapAction.modifiers")
                    modifiers.insert(modifier)
                }
            }
            return .keys(keyCode: UInt16(code), modifiers: modifiers)
        default:
            throw .invalid(field: "tapAction.type", message: "must be spotlight, app, or keys")
        }
    }

    private static func bindings(_ value: JSONValue) throws(ConfigError) -> [BindableKey: KeyBinding] {
        guard case .object(let object) = value else {
            throw .invalid(field: "bindings", message: "must be an object")
        }
        var result: [BindableKey: KeyBinding] = [:]
        for rawKey in object.keys.sorted() {
            let field = "bindings.\(rawKey)"
            guard let key = BindableKey(rawKey) else {
                throw .invalid(field: field, message: "keys must be a single character 0–9 or A–Z")
            }
            guard result[key] == nil else {
                throw .invalid(field: "bindings.\(key.rawValue)", message: "is listed twice (keys aren't case-sensitive)")
            }
            guard case .object(let entry) = object[rawKey]! else {
                throw .invalid(field: field, message: "must be an object with \"app\" or \"snap\"")
            }
            switch (entry["app"], entry["snap"]) {
            case (let app?, nil):
                result[key] = .app(bundleID: try string(app, field: "\(field).app"))
            case (nil, let snap?):
                result[key] = .snap(try enumValue(snap, field: "\(field).snap"))
            default:
                throw .invalid(field: field, message: "must have exactly one of \"app\" or \"snap\"")
            }
        }
        return result
    }

    private static func restoreSize(_ value: JSONValue) throws(ConfigError) -> RestoreSize {
        guard case .object(let object) = value else {
            throw .invalid(field: "restoreSize", message: "must be an object")
        }
        func fraction(_ name: String, default fallback: Double) throws(ConfigError) -> Double {
            guard let raw = object[name] else { return fallback }
            guard case .number(let n) = raw, (0.1...1.0).contains(n) else {
                throw .invalid(field: "restoreSize.\(name)", message: "must be between 0.1 and 1.0")
            }
            return n
        }
        return RestoreSize(
            width: try fraction("width", default: RestoreSize.default.width),
            height: try fraction("height", default: RestoreSize.default.height)
        )
    }

    // MARK: - Encoding helpers

    private static func tapActionJSON(_ action: TapAction) -> JSONValue {
        switch action {
        case .spotlight:
            .object(["type": .string("spotlight")])
        case .app(let id):
            .object(["type": .string("app"), "bundleId": .string(id)])
        case .keys(let code, let modifiers):
            .object([
                "type": .string("keys"),
                "keyCode": .number(Double(code)),
                "modifiers": .array(modifiers.map(\.rawValue).sorted().map(JSONValue.string)),
            ])
        }
    }
}

extension ConfigError {
    /// The 1-based line in `text` the error points at, for highlighting in an editor.
    /// Field errors are located by finding each key of the dotted path in order.
    public func line(in text: String) -> Int? {
        switch self {
        case .syntax(let line, _):
            return line
        case .invalid(let field, _):
            var searchStart = text.startIndex
            var found: String.Index?
            for segment in field.split(separator: ".") {
                guard let range = text.range(of: "\"\(segment)\"", range: searchStart..<text.endIndex) else { break }
                found = range.lowerBound
                searchStart = range.upperBound
            }
            guard let found else { return nil }
            return text[..<found].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
        }
    }
}
