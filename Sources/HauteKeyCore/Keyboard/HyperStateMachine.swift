/// A keyboard or mouse event, reduced to what the Hyper logic needs.
public enum HyperInput: Equatable, Sendable {
    case hyperDown
    case hyperUp
    case keyDown(keyCode: UInt16, isRepeat: Bool)
    case keyUp(keyCode: UInt16)
    case mouseDown
}

public enum HyperAction: Equatable, Sendable {
    case tap
    case binding(BindableKey)
}

/// Whether to swallow the event, and what to run (after the event is handled).
public struct HyperDecision: Equatable, Sendable {
    public var consume: Bool
    public var action: HyperAction?

    public init(consume: Bool, action: HyperAction? = nil) {
        self.consume = consume
        self.action = action
    }

    public static let pass = HyperDecision(consume: false)
    public static let consume = HyperDecision(consume: true)
}

/// Decides tap vs. hold. A tap is Hyper down then up with no key or mouse press in between,
/// however long it was held. Every key pressed while Hyper is held is swallowed, including
/// its key-up, even if Hyper is released first.
public struct HyperStateMachine: Sendable {
    private enum Hold { case none, clean, used }

    private var hold = Hold.none
    private var swallowedKeys = Set<UInt16>()

    public init() {}

    public var isHeld: Bool { hold != .none }

    public mutating func handle(_ input: HyperInput) -> HyperDecision {
        switch input {
        case .hyperDown:
            // Repeated key-downs while held are auto-repeat; they don't start a new hold.
            if hold == .none { hold = .clean }
            return .consume

        case .hyperUp:
            let wasClean = hold == .clean
            hold = .none
            return HyperDecision(consume: true, action: wasClean ? .tap : nil)

        case .keyDown(let code, let isRepeat):
            guard isHeld else { return .pass }
            hold = .used
            swallowedKeys.insert(code)
            guard !isRepeat, let key = KeyCodes.bindableKey(forKeyCode: code) else { return .consume }
            return HyperDecision(consume: true, action: .binding(key))

        case .keyUp(let code):
            return swallowedKeys.remove(code) != nil ? .consume : .pass

        case .mouseDown:
            if isHeld { hold = .used }
            return .pass
        }
    }

    /// Forget everything, for when the event tap stops or restarts.
    public mutating func reset() {
        hold = .none
        swallowedKeys.removeAll()
    }
}
