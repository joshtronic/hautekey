import CoreGraphics
import Testing
@testable import HauteKeyCore

private let a = CGRect(x: 10, y: 10, width: 900, height: 700)
private let b = CGRect(x: 0, y: 38, width: 864, height: 1079)
private let c = CGRect(x: 50, y: 60, width: 640, height: 480)

@Test func snapSnapRestoreReturnsOriginal() {
    var memory = RestoreMemory<Int>()
    memory.noteSnap(1, currentFrame: a)
    memory.noteSnap(1, currentFrame: b)
    #expect(memory.take(1) == a)
}

@Test func restoreClearsHistory() {
    var memory = RestoreMemory<Int>()
    memory.noteSnap(1, currentFrame: a)
    _ = memory.take(1)
    memory.noteSnap(1, currentFrame: c)
    #expect(memory.take(1) == c)
}

@Test func takeWithoutHistoryIsNil() {
    var memory = RestoreMemory<Int>()
    #expect(memory.take(1) == nil)
}

@Test func windowsAreTrackedSeparately() {
    var memory = RestoreMemory<Int>()
    memory.noteSnap(1, currentFrame: a)
    memory.noteSnap(2, currentFrame: c)
    #expect(memory.take(2) == c)
    #expect(memory.take(1) == a)
}
