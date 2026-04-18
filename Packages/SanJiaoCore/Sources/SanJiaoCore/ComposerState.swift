import Foundation

public enum ComposerState: Equatable, Sendable {
    case empty
    case composing(buffer: String)
    case selecting(buffer: String, candidates: [CharEntry], page: Int)
}

public enum ComposerEvent: Equatable, Sendable {
    case digit(Character)        // 0-9
    case space
    case enter
    case backspace
    case escape
    case pick(Int)               // 1-based candidate index within visible page
    case nextPage
    case prevPage
    case passthrough(Character)  // a-z A-Z etc.
}

public enum ComposerEffect: Equatable, Sendable {
    case commit(String)          // emit text to client
    case passthrough(Character)  // forward key to system
    case beep                    // buffer full / invalid pick
}
