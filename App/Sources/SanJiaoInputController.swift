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
        // Input-method processes are often killed without a terminate callback;
        // persist any pending (< flushEvery) learning now.
        try? LexiconBootstrap.shared.store?.flush()
    }

    public override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown, var c = composer else { return false }
        let isModified = !event.modifierFlags
            .intersection([.command, .control, .option])
            .isEmpty
        guard let evt = KeyTranslator.translate(text: event.charactersIgnoringModifiers,
                                                isModified: isModified,
                                                state: c.state) else {
            return false
        }
        let effects = c.handle(evt)
        self.composer = c
        apply(effects: effects, composer: c, client: sender)
        switch c.state {
        case .empty:
            return !effects.contains { if case .passthrough = $0 { return true } else { return false } }
        case .composing, .selecting:
            return true
        }
    }

    /// Mouse selection in the IMKCandidates panel.
    public override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard var c = composer, let text = candidateString?.string else { return }
        let effects = c.handle(.pickCharacter(text))
        self.composer = c
        apply(effects: effects, composer: c, client: client())
    }

    private func apply(effects: [ComposerEffect], composer: Composer, client: Any!) {
        guard let client = client as? IMKTextInput else { return }
        for fx in effects {
            switch fx {
            case .commit(let entry):
                client.insertText(entry.character, replacementRange: NSRange(location: NSNotFound, length: 0))
                // Learning is keyed by the entry's full 6-digit code — the same
                // key Ranker.score queries — never by the (possibly partial)
                // typed buffer.
                if let store = LexiconBootstrap.shared.store {
                    store.bump(code: entry.code, character: entry.character)
                }
            case .passthrough:
                break // we return false from handle() so system delivers it
            case .beep:
                NSSound.beep()
            }
        }
        let stateAfter = composer.state

        // Update marked text — the typed code stays visible while composing
        // AND while the candidate window is open.
        if let buf = stateAfter.displayBuffer {
            let attr = NSAttributedString(string: buf,
                attributes: [.foregroundColor: NSColor.secondaryLabelColor,
                             .underlineStyle: NSUnderlineStyle.single.rawValue])
            client.setMarkedText(attr,
                selectionRange: NSRange(location: buf.count, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0))
        } else {
            client.setMarkedText("",
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0))
        }

        // Show/hide candidate panel. Only the current page is handed over, so
        // the panel's numbering always matches the composer's .pick indexing.
        // IMKit delivers events on the main thread; assumeIsolated makes that
        // contract explicit for the MainActor-bound panel.
        let visible = composer.visibleCandidates
        MainActor.assumeIsolated {
            switch stateAfter {
            case .selecting:
                CandidatePanel.shared.show(entries: visible)
            case .empty, .composing:
                CandidatePanel.shared.hide()
            }
        }
    }

    public override func menu() -> NSMenu! {
        let m = NSMenu()
        m.addItem(withTitle: "偏好設定…", action: #selector(openPrefs), keyEquivalent: "")
        return m
    }

    @objc private func openPrefs() {
        MainActor.assumeIsolated {
            PreferencesWindow.shared.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
