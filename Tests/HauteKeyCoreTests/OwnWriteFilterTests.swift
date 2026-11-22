import Foundation
import Testing
@testable import HauteKeyCore

private let a = Data("A".utf8)
private let b = Data("B".utf8)

private func decisions(after ownWrite: Data, events: [Data]) -> [Bool] {
    var filter = OwnWriteFilter()
    filter.noteOwnWrite(ownWrite)
    return events.map { filter.shouldIgnore($0) }
}

@Test func ignoresTheAppsOwnWriteOnce() {
    #expect(decisions(after: a, events: [a]) == [true])
}

@Test func revertingToTheLastOwnWriteIsNotIgnored() {
    // App saves A, user breaks it (B), then restores exactly A with git: that must reload.
    #expect(decisions(after: a, events: [a, b, a]) == [true, false, false])
}

@Test func otherContentIsNeverIgnored() {
    #expect(decisions(after: a, events: [b, a]) == [false, false])
}
