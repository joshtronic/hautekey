import Foundation

/// Tells a file watcher which change event was the app's own save. One-shot: the next change
/// after a save is checked once, so a later revert to the same bytes still reloads.
public struct OwnWriteFilter: Sendable {
    private var lastOwnWrite: Data?

    public init() {}

    public mutating func noteOwnWrite(_ data: Data) {
        lastOwnWrite = data
    }

    public mutating func shouldIgnore(_ data: Data) -> Bool {
        defer { lastOwnWrite = nil }
        return data == lastOwnWrite
    }
}
