import Foundation

/// Pure key → ComposerEvent mapping, kept in core so it is unit-testable.
/// The IMKit controller extracts (text, modifier presence) from NSEvent and
/// delegates here.
public enum KeyTranslator {
    /// Maps a key press to a composer event.
    ///
    /// - Parameters:
    ///   - text: `charactersIgnoringModifiers` of the event.
    ///   - isModified: true when Command/Control/Option is held — such chords
    ///     are app shortcuts, never composition input.
    ///   - state: current composer state; digits and page keys change meaning
    ///     while selecting.
    /// - Returns: the event to feed the composer, or `nil` when the key is not
    ///   ours and the controller must report the event as unhandled.
    public static func translate(text: String?, isModified: Bool, state: ComposerState) -> ComposerEvent? {
        guard !isModified else { return nil }
        guard let ch = text?.first else { return nil }
        switch ch {
        case "0"..."9":
            if case .selecting = state {
                let n = Int(String(ch))!
                return .pick(n == 0 ? 10 : n)
            }
            return .digit(ch)
        case " ":                return .space
        case "\r", "\n":         return .enter
        case "\u{7F}", "\u{08}": return .backspace
        case "\u{1B}":           return .escape
        case ",":
            if case .selecting = state { return .prevPage }
            return .passthrough(ch)
        case ".":
            if case .selecting = state { return .nextPage }
            return .passthrough(ch)
        default:
            return .passthrough(ch)
        }
    }
}
