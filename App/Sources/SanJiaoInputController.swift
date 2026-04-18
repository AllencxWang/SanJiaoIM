import Cocoa
import InputMethodKit
import SanJiaoCore
import os

public class SanJiaoInputController: IMKInputController {
    private let log = Logger(subsystem: "com.sanjiaoim.app", category: "imkit")
    private var composer: Composer?

    public override func activateServer(_ sender: Any!) {
        guard let lex = LexiconBootstrap.shared.lexicon,
              let store = LexiconBootstrap.shared.store else { return }
        let ranker = Ranker(frequencies: store)
        self.composer = Composer(lexicon: lex, ranker: ranker)
    }

    public override func deactivateServer(_ sender: Any!) {
        self.composer = nil
    }

    public override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown, var c = composer else { return false }
        let stateBefore = c.state
        let evt = translate(event, stateBefore: stateBefore)
        let effects = c.handle(evt)
        self.composer = c
        apply(effects: effects, client: sender, stateBefore: stateBefore, stateAfter: c.state)
        switch c.state {
        case .empty:
            return !effects.contains { if case .passthrough = $0 { return true } else { return false } }
        case .composing, .selecting:
            return true
        }
    }

    private func translate(_ event: NSEvent, stateBefore: ComposerState) -> ComposerEvent {
        let s = event.charactersIgnoringModifiers ?? ""
        guard let ch = s.first else { return .passthrough(" ") }
        switch ch {
        case "0"..."9":
            if case .selecting = stateBefore {
                // in selecting mode digits mean pick; '0' means 10th
                let n = Int(String(ch))!
                return .pick(n == 0 ? 10 : n)
            }
            return .digit(ch)
        case " ":              return .space
        case "\r", "\n":       return .enter
        case "\u{7F}", "\u{08}": return .backspace
        case "\u{1B}":         return .escape
        case ",":              return .prevPage
        case ".":              return .nextPage
        default:               return .passthrough(ch)
        }
    }

    private func apply(effects: [ComposerEffect], client: Any!, stateBefore: ComposerState, stateAfter: ComposerState) {
        guard let client = client as? IMKTextInput else { return }
        for fx in effects {
            switch fx {
            case .commit(let text):
                client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
                if let code = currentCode(state: stateBefore),
                   let store = LexiconBootstrap.shared.store {
                    store.bump(code: code, character: text)
                }
            case .passthrough:
                break // we return false from handle() so system delivers it
            case .beep:
                NSSound.beep()
            }
        }
    }

    private func currentCode(state: ComposerState) -> String? {
        if case .selecting(let buf, _, _) = state { return buf }
        return nil
    }
}
