import Foundation

/// The physical key that becomes Hyper.
public enum HyperKey: String, Sendable, CaseIterable {
    case rightCommand, rightOption, rightControl, capsLock
}

public enum SnapAction: String, Sendable, CaseIterable {
    case maximize, leftHalf, rightHalf, restore
}

/// One of the keys 0–9 or A–Z, stored lowercase.
public struct BindableKey: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: String

    public init?(_ string: String) {
        let lower = string.lowercased()
        guard lower.count == 1, let scalar = lower.unicodeScalars.first,
              ("0"..."9").contains(scalar) || ("a"..."z").contains(scalar)
        else { return nil }
        rawValue = lower
    }

    /// Display and settings order: 1…9, 0, a…z (matches the keyboard's number row).
    public static let all: [BindableKey] =
        (Array("1234567890") + Array("abcdefghijklmnopqrstuvwxyz")).map { BindableKey(String($0))! }

    public static func < (lhs: BindableKey, rhs: BindableKey) -> Bool {
        all.firstIndex(of: lhs)! < all.firstIndex(of: rhs)!
    }

    public var description: String { rawValue }
}

public enum Binding: Equatable, Sendable {
    case app(bundleID: String)
    case snap(SnapAction)
}

public enum KeyModifier: String, Sendable, CaseIterable {
    case command, option, control, shift
}

/// What a lone tap of the Hyper key does.
public enum TapAction: Equatable, Sendable {
    case spotlight
    case app(bundleID: String)
    case keys(keyCode: UInt16, modifiers: Set<KeyModifier>)
}

/// Size of a restored window that has no remembered frame, as fractions of the usable area.
public struct RestoreSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let `default` = RestoreSize(width: 0.6, height: 0.6)
}

/// The shareable settings stored in `config.json`. Per-Mac settings live elsewhere.
public struct Config: Equatable, Sendable {
    public var version: Int = 1
    public var hyperKey: HyperKey = .rightCommand
    public var capsLockToControl = false
    public var tapAction: TapAction = .spotlight
    public var bindings: [BindableKey: Binding] = [:]
    public var restoreSize: RestoreSize = .default
    /// Top-level keys this version doesn't recognize, kept so saves don't drop them.
    public var extra: [String: JSONValue] = [:]

    public init() {}

    public static let empty = Config()

    /// Caps lock can't be both Hyper and Control.
    public var effectiveCapsLockToControl: Bool {
        capsLockToControl && hyperKey != .capsLock
    }
}
