import Foundation

public enum ComposerState: Equatable, Sendable {
    case empty
    case composing(buffer: String)
    case selecting(buffer: String, candidates: [CharEntry], page: Int)

    /// The typed code to show as marked text — visible both while composing
    /// and while the candidate window is open.
    public var displayBuffer: String? {
        switch self {
        case .empty:                          return nil
        case .composing(let buf):             return buf
        case .selecting(let buf, _, _):       return buf
        }
    }
}

public enum ComposerEvent: Equatable, Sendable {
    case digit(Character)        // 0-9
    case space
    case enter
    case backspace
    case escape
    case pick(Int)               // 1-based candidate index within visible page
    case pickCharacter(String)   // candidate chosen by its text (mouse click in panel)
    case nextPage
    case prevPage
    case passthrough(Character)  // a-z A-Z etc.
}

public enum ComposerEffect: Equatable, Sendable {
    case commit(CharEntry)       // emit entry.character to client; entry.code keys frequency learning
    case passthrough(Character)  // forward key to system
    case beep                    // buffer full / invalid pick
}
