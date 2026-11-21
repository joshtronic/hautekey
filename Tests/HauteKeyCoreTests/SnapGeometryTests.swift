import CoreGraphics
import Testing
@testable import HauteKeyCore

private let u = CGRect(x: 0, y: 38, width: 1728, height: 1079)

private func frame(_ action: SnapAction, _ usable: CGRect = u) -> CGRect {
    SnapGeometry.frame(for: action, usable: usable, restoreSize: .default)
}

@Test func leftHalfSpecExample() {
    #expect(frame(.leftHalf) == CGRect(x: 0, y: 38, width: 864, height: 1079))
}

@Test func rightHalfSpecExample() {
    #expect(frame(.rightHalf) == CGRect(x: 864, y: 38, width: 864, height: 1079))
}

@Test func maximizeEqualsUsable() {
    #expect(frame(.maximize) == u)
}

@Test func oddWidthHalvesCoverExactly() {
    let odd = CGRect(x: 0, y: 38, width: 1727, height: 1079)
    #expect(frame(.leftHalf, odd) == CGRect(x: 0, y: 38, width: 863, height: 1079))
    #expect(frame(.rightHalf, odd) == CGRect(x: 863, y: 38, width: 864, height: 1079))
}

@Test func halvesOnOffsetDisplay() {
    let external = CGRect(x: -1920, y: 262, width: 1920, height: 1055)
    #expect(frame(.rightHalf, external) == CGRect(x: -960, y: 262, width: 960, height: 1055))
}

@Test func reasonableSizeCentered() {
    let small = CGRect(x: 0, y: 38, width: 1000, height: 500)
    #expect(frame(.restore, small) == CGRect(x: 200, y: 138, width: 600, height: 300))
}

@Test func cocoaToAXOnPrimary() {
    let ax = SnapGeometry.axRect(fromCocoa: CGRect(x: 0, y: 0, width: 1728, height: 1079), primaryHeight: 1117)
    #expect(ax == CGRect(x: 0, y: 38, width: 1728, height: 1079))
}

@Test func cocoaToAXDisplayLeftOfPrimary() {
    let ax = SnapGeometry.axRect(fromCocoa: CGRect(x: -1920, y: -200, width: 1920, height: 1055), primaryHeight: 1117)
    #expect(ax == CGRect(x: -1920, y: 262, width: 1920, height: 1055))
}

@Test func cocoaToAXDisplayAbovePrimary() {
    let ax = SnapGeometry.axRect(fromCocoa: CGRect(x: 0, y: 1117, width: 2560, height: 1415), primaryHeight: 1117)
    #expect(ax == CGRect(x: 0, y: -1415, width: 2560, height: 1415))
}

private let displays = [CGRect(x: -1920, y: 262, width: 1920, height: 1055), u]

@Test func displayIndexPrefersLargestOverlap() {
    #expect(SnapGeometry.displayIndex(for: CGRect(x: -600, y: 300, width: 800, height: 600), displays: displays) == 0)
    #expect(SnapGeometry.displayIndex(for: CGRect(x: -300, y: 300, width: 800, height: 600), displays: displays) == 1)
}

@Test func displayIndexFallsBackToNearest() {
    #expect(SnapGeometry.displayIndex(for: CGRect(x: 5000, y: 0, width: 100, height: 100), displays: displays) == 1)
}

@Test func displayIndexEmptyIsNil() {
    #expect(SnapGeometry.displayIndex(for: u, displays: []) == nil)
}

@Test func rightAnchorWithMinWidth() {
    let origin = SnapGeometry.anchoredOrigin(for: .rightHalf, actualSize: CGSize(width: 1000, height: 1079), target: frame(.rightHalf))
    #expect(origin == CGPoint(x: 728, y: 38))
}

@Test func leftAnchorWithMinWidth() {
    let origin = SnapGeometry.anchoredOrigin(for: .leftHalf, actualSize: CGSize(width: 1000, height: 800), target: frame(.leftHalf))
    #expect(origin == CGPoint(x: 0, y: 38))
}

@Test func restoreAnchorCenters() {
    let target = CGRect(x: 346, y: 254, width: 1036, height: 647)
    let origin = SnapGeometry.anchoredOrigin(for: .restore, actualSize: CGSize(width: 900, height: 700), target: target)
    #expect(origin == CGPoint(x: 414, y: 227))
}

@Test func restoreUsesRememberedWhenOnScreen() {
    let remembered = CGRect(x: 100, y: 100, width: 900, height: 700)
    let result = SnapGeometry.restoreFrame(remembered: remembered, usable: u, allUsable: displays, restoreSize: .default)
    #expect(result == remembered)
}

@Test func restoreFallsBackWhenRememberedOffScreen() {
    let remembered = CGRect(x: 5000, y: 5000, width: 900, height: 700)
    let result = SnapGeometry.restoreFrame(remembered: remembered, usable: u, allUsable: displays, restoreSize: .default)
    #expect(result == CGRect(x: 346, y: 254, width: 1036, height: 647))
}

@Test func restoreWithoutHistoryIsReasonableSize() {
    let result = SnapGeometry.restoreFrame(remembered: nil, usable: u, allUsable: displays, restoreSize: .default)
    #expect(result == frame(.restore))
}
