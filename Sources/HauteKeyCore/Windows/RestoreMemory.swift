import CoreGraphics

/// Remembers each window's frame from before the app first snapped it, so restore can put it back.
public struct RestoreMemory<Key: Hashable & Sendable>: Sendable {
    private var frames: [Key: CGRect] = [:]

    public init() {}

    /// Call before a snap. Only the first snap since the last restore is remembered.
    public mutating func noteSnap(_ key: Key, currentFrame: CGRect) {
        if frames[key] == nil { frames[key] = currentFrame }
    }

    /// Returns the remembered frame and forgets it.
    public mutating func take(_ key: Key) -> CGRect? {
        frames.removeValue(forKey: key)
    }
}
