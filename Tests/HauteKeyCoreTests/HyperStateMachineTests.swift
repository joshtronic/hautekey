import Testing
@testable import HauteKeyCore

private let w: UInt16 = 13
private let period: UInt16 = 47
private let wKey = BindableKey("w")!

private func run(_ inputs: [HyperInput]) -> [HyperDecision] {
    var machine = HyperStateMachine()
    return inputs.map { machine.handle($0) }
}

private func consumed(_ action: HyperAction? = nil) -> HyperDecision {
    HyperDecision(consume: true, action: action)
}

@Test func quickTapRunsTapOnRelease() {
    #expect(run([.hyperDown, .hyperUp]) == [consumed(), consumed(.tap)])
}

@Test func longHoldWithAutoRepeatStillTaps() {
    let decisions = run([.hyperDown, .hyperDown, .hyperDown, .hyperUp])
    #expect(decisions.filter { $0.action == .tap }.count == 1)
    #expect(decisions.last == consumed(.tap))
    #expect(decisions.allSatisfy { $0.consume })
}

@Test func keyDuringHoldCancelsTap() {
    let decisions = run([.hyperDown, .keyDown(keyCode: w, isRepeat: false), .keyUp(keyCode: w), .hyperUp])
    #expect(decisions.last == consumed())
}

@Test func mouseDuringHoldCancelsTapButPasses() {
    let decisions = run([.hyperDown, .mouseDown, .hyperUp])
    #expect(decisions[1] == .pass)
    #expect(decisions[2] == consumed())
}

@Test func boundKeyEmitsBindingOnce() {
    let decisions = run([
        .hyperDown,
        .keyDown(keyCode: w, isRepeat: false),
        .keyDown(keyCode: w, isRepeat: true),
        .keyDown(keyCode: w, isRepeat: true),
    ])
    #expect(decisions[1] == consumed(.binding(wKey)))
    #expect(decisions[2] == consumed())
    #expect(decisions[3] == consumed())
}

@Test func nonBindableKeyIsSwallowed() {
    #expect(run([.hyperDown, .keyDown(keyCode: period, isRepeat: false)])[1] == consumed())
}

@Test func keyUpAfterHyperReleaseIsSwallowed() {
    let decisions = run([.hyperDown, .keyDown(keyCode: w, isRepeat: false), .hyperUp, .keyUp(keyCode: w)])
    #expect(decisions[3] == consumed())
}

@Test func swallowedKeyUpIsOnlySwallowedOnce() {
    let decisions = run([
        .hyperDown, .keyDown(keyCode: w, isRepeat: false), .keyUp(keyCode: w), .hyperUp,
        .keyDown(keyCode: w, isRepeat: false), .keyUp(keyCode: w),
    ])
    #expect(decisions[4] == .pass)
    #expect(decisions[5] == .pass)
}

@Test func autoRepeatHyperDoesNotResetUsed() {
    let decisions = run([.hyperDown, .keyDown(keyCode: w, isRepeat: false), .hyperDown, .hyperUp])
    #expect(decisions[3] == consumed())
}

@Test func keysPassWhenNotHeld() {
    #expect(run([.keyDown(keyCode: w, isRepeat: false), .keyUp(keyCode: w)]) == [.pass, .pass])
}

@Test func strayHyperUpIsConsumedWithoutTap() {
    #expect(run([.hyperUp]) == [consumed()])
}

@Test func isHeldTracksHyper() {
    var machine = HyperStateMachine()
    _ = machine.handle(.hyperDown)
    #expect(machine.isHeld)
    _ = machine.handle(.hyperUp)
    #expect(!machine.isHeld)
}

@Test func resetForgetsHoldAndSwallowedKeys() {
    var machine = HyperStateMachine()
    _ = machine.handle(.hyperDown)
    _ = machine.handle(.keyDown(keyCode: w, isRepeat: false))
    machine.reset()
    #expect(!machine.isHeld)
    #expect(machine.handle(.keyUp(keyCode: w)) == .pass)
}
