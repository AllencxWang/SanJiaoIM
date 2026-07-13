import Cocoa
import SanJiaoCore

/// The IMKit calls the controller depends on, mirrored 1:1 so a fake can
/// record the exact call sequence in tests. Conformances: IMKTextInput
/// (via TextInputAdapter) and CandidatePanel.
@MainActor
protocol TextClient {
    func insertText(_ text: String)
    func setMarkedText(_ text: NSAttributedString, selectionRange: NSRange)
    func clearMarkedText()
}

@MainActor
protocol CandidateUI {
    func show(entries: [CharEntry])
    func hide()
}

/// Translates Composer effects + resulting state into client calls.
/// Order matters: commits land before the marked text is cleared, so the
/// user never sees a committed character trailed by leftover code digits.
@MainActor
struct EffectApplicator {
    let text: TextClient
    let candidates: CandidateUI
    let onCommit: (CharEntry) -> Void
    let beep: () -> Void

    func apply(effects: [ComposerEffect],
               state: ComposerState,
               visibleCandidates: [CharEntry]) {
        for fx in effects {
            switch fx {
            case .commit(let entry):
                text.insertText(entry.character)
                // Learning is keyed by the entry's full 6-digit code — the same
                // key Ranker.score queries — never by the (possibly partial)
                // typed buffer.
                onCommit(entry)
            case .passthrough:
                break // handle() returns false so the system delivers it
            case .beep:
                beep()
            }
        }

        // Update marked text — the typed code stays visible while composing
        // AND while the candidate window is open.
        if let buf = state.displayBuffer {
            let attr = NSAttributedString(string: buf,
                attributes: [.foregroundColor: NSColor.secondaryLabelColor,
                             .underlineStyle: NSUnderlineStyle.single.rawValue])
            text.setMarkedText(attr,
                selectionRange: NSRange(location: buf.count, length: 0))
        } else {
            text.clearMarkedText()
        }

        // Only the current page is handed over, so the panel's numbering
        // always matches the composer's .pick indexing.
        switch state {
        case .selecting:
            candidates.show(entries: visibleCandidates)
        case .empty, .composing:
            candidates.hide()
        }
    }
}
