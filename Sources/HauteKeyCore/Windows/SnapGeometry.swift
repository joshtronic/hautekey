import CoreGraphics

/// Window frame math. All rects use Accessibility (Quartz) coordinates: origin at the top-left
/// of the primary display, y growing down. Displays left of or above the primary have negative
/// coordinates.
public enum SnapGeometry {
    /// Converts an `NSScreen` frame (Cocoa: bottom-left origin, y up) to AX coordinates.
    public static func axRect(fromCocoa rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - (rect.minY + rect.height), width: rect.width, height: rect.height)
    }

    /// The display holding most of the window; if it's on none, the one nearest its center.
    public static func displayIndex(for window: CGRect, displays: [CGRect]) -> Int? {
        let overlaps = displays.enumerated().map { index, display -> (Int, CGFloat) in
            let overlap = window.intersection(display)
            return (index, overlap.isNull ? 0 : overlap.width * overlap.height)
        }
        if let best = overlaps.max(by: { $0.1 < $1.1 }), best.1 > 0 {
            return best.0
        }
        let center = CGPoint(x: window.midX, y: window.midY)
        return displays.indices.min { lhs, rhs in
            distanceSquared(center, displays[lhs]) < distanceSquared(center, displays[rhs])
        }
    }

    /// The target frame. For `.restore` this is the centered "reasonable size" frame.
    public static func frame(for action: SnapAction, usable: CGRect, restoreSize: RestoreSize) -> CGRect {
        let half = (usable.width / 2).rounded(.down)
        switch action {
        case .maximize:
            return usable
        case .leftHalf:
            return CGRect(x: usable.minX, y: usable.minY, width: half, height: usable.height)
        case .rightHalf:
            return CGRect(x: usable.minX + half, y: usable.minY, width: usable.width - half, height: usable.height)
        case .restore:
            let width = (usable.width * restoreSize.width).rounded(.down)
            let height = (usable.height * restoreSize.height).rounded(.down)
            return CGRect(
                x: usable.minX + ((usable.width - width) / 2).rounded(.down),
                y: usable.minY + ((usable.height - height) / 2).rounded(.down),
                width: width,
                height: height
            )
        }
    }

    /// Where to put a window that ended up a different size than the target (min/max size),
    /// keeping it against the target's anchored edge.
    public static func anchoredOrigin(for action: SnapAction, actualSize: CGSize, target: CGRect) -> CGPoint {
        let centeredX = target.minX + ((target.width - actualSize.width) / 2).rounded(.down)
        let centeredY = target.minY + ((target.height - actualSize.height) / 2).rounded(.down)
        switch action {
        case .leftHalf: return CGPoint(x: target.minX, y: target.minY)
        case .rightHalf: return CGPoint(x: target.maxX - actualSize.width, y: target.minY)
        case .maximize: return CGPoint(x: centeredX, y: target.minY)
        case .restore: return CGPoint(x: centeredX, y: centeredY)
        }
    }

    /// The remembered frame if it's still on a display, otherwise the reasonable-size frame.
    public static func restoreFrame(
        remembered: CGRect?, usable: CGRect, allUsable: [CGRect], restoreSize: RestoreSize
    ) -> CGRect {
        if let remembered, allUsable.contains(where: { $0.contains(CGPoint(x: remembered.midX, y: remembered.midY)) }) {
            return remembered
        }
        return frame(for: .restore, usable: usable, restoreSize: restoreSize)
    }

    private static func distanceSquared(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY
        return dx * dx + dy * dy
    }
}
