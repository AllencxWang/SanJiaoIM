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
        // IMKit delivers events on the main thread; assumeIsolated makes that
        // contract explicit for the MainActor-bound panel and applicator.
        MainActor.assumeIsolated {
            let applicator = EffectApplicator(
                text: TextInputAdapter(client: client),
                candidates: CandidatePanel.shared,
                onCommit: { entry in
                    LexiconBootstrap.shared.store?.bump(code: entry.code, character: entry.character)
                },
                beep: { NSSound.beep() })
            applicator.apply(effects: effects,
                             state: composer.state,
                             visibleCandidates: composer.visibleCandidates)
        }
    }

    /// Bridges the live IMKTextInput client to the testable TextClient seam.
    @MainActor
    private struct TextInputAdapter: TextClient {
        let client: IMKTextInput

        func insertText(_ text: String) {
            client.insertText(text,
                replacementRange: NSRange(location: NSNotFound, length: 0))
        }

        func setMarkedText(_ text: NSAttributedString, selectionRange: NSRange) {
            client.setMarkedText(text,
                selectionRange: selectionRange,
                replacementRange: NSRange(location: NSNotFound, length: 0))
        }

        func clearMarkedText() {
            client.setMarkedText("",
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0))
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
