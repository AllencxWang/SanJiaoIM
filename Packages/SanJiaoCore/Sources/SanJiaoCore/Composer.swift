import Foundation

public struct Composer: Sendable {
    public private(set) var state: ComposerState = .empty
    private let lexicon: Lexicon
    private let ranker: Ranker?
    public let pageSize = 10

    public init(lexicon: Lexicon, ranker: Ranker? = nil) {
        self.lexicon = lexicon
        self.ranker = ranker
    }

    /// The slice of candidates on the current page — exactly what the candidate
    /// window should display, so on-screen numbering always matches `.pick(n)`.
    public var visibleCandidates: [CharEntry] {
        guard case .selecting(_, let cands, let page) = state else { return [] }
        let start = page * pageSize
        guard start < cands.count else { return [] }
        return Array(cands[start..<min(start + pageSize, cands.count)])
    }

    @discardableResult
    public mutating func handle(_ event: ComposerEvent) -> [ComposerEffect] {
        switch (state, event) {
        case (.empty, .digit(let d)):
            state = .composing(buffer: String(d))
            return []

        case (.empty, .passthrough(let c)):
            return [.passthrough(c)]

        // With nothing composed these keys are not ours — forward them so the
        // controller reports the event as unhandled and the system delivers it.
        case (.empty, .space):      return [.passthrough(" ")]
        case (.empty, .enter):      return [.passthrough("\r")]
        case (.empty, .backspace):  return [.passthrough("\u{7F}")]
        case (.empty, .escape):     return [.passthrough("\u{1B}")]
        case (.empty, .prevPage):   return [.passthrough(",")]
        case (.empty, .nextPage):   return [.passthrough(".")]
        case (.empty, .pick), (.empty, .pickCharacter): return []

        case (.composing(let buf), .digit(let d)):
            // Buffer is already full (kept after a no-match, spec §3.2) — reject
            // further digits so it can never exceed codeLength.
            guard buf.count < LexiconFormat.codeLength else { return [.beep] }
            let next = buf + String(d)
            if next.count == LexiconFormat.codeLength {
                return enterSelecting(lookup: next, typed: next)
            }
            state = .composing(buffer: next)
            return []

        case (.composing(let buf), .space):
            return enterSelecting(lookup: buf, typed: buf)

        case (.composing(let buf), .enter):
            let padded = buf + String(repeating: "0", count: max(0, LexiconFormat.codeLength - buf.count))
            return enterSelecting(lookup: padded, typed: buf)

        case (.composing(let buf), .backspace):
            let next = String(buf.dropLast())
            state = next.isEmpty ? .empty : .composing(buffer: next)
            return []

        case (.composing, .escape):
            state = .empty
            return []

        case (.composing, .passthrough(let c)):
            state = .empty
            return [.passthrough(c)]

        case (.composing, .pick), (.composing, .pickCharacter),
             (.composing, .nextPage), (.composing, .prevPage):
            return []

        case (.selecting(_, let cands, let page), .pick(let n)):
            let idx = page * pageSize + (n - 1)
            guard idx >= 0, idx < cands.count else { return [.beep] }
            let picked = cands[idx]
            state = .empty
            return [.commit(picked)]

        case (.selecting, .pickCharacter(let ch)):
            // Mouse selection: the panel displays visibleCandidates, so match there.
            guard let picked = visibleCandidates.first(where: { $0.character == ch }) else {
                return [.beep]
            }
            state = .empty
            return [.commit(picked)]

        case (.selecting(_, let cands, let page), .space):
            let idx = page * pageSize
            guard idx < cands.count else { return [.beep] }
            state = .empty
            return [.commit(cands[idx])]

        case (.selecting(let buf, let cands, let page), .nextPage):
            let maxPage = max(0, (cands.count - 1) / pageSize)
            let p = min(page + 1, maxPage)
            state = .selecting(buffer: buf, candidates: cands, page: p)
            return []

        case (.selecting(let buf, let cands, let page), .prevPage):
            state = .selecting(buffer: buf, candidates: cands, page: max(page - 1, 0))
            return []

        case (.selecting(let buf, _, _), .backspace):
            let trimmed = String(buf.dropLast())
            state = trimmed.isEmpty ? .empty : .composing(buffer: trimmed)
            return []

        case (.selecting, .escape):
            state = .empty
            return []

        case (.selecting(_, let cands, let page), .passthrough(let c)):
            let idx = page * pageSize
            var out: [ComposerEffect] = []
            if idx < cands.count { out.append(.commit(cands[idx])) }
            out.append(.passthrough(c))
            state = .empty
            return out

        case (.selecting, .enter):
            return [] // no-op; require explicit pick

        case (.selecting, .digit):
            return [.beep] // in selecting mode digits should have been routed as .pick
        }
    }

    /// `lookup` is the code queried against the lexicon (possibly zero-padded);
    /// `typed` is what the user actually entered — it is what the state keeps
    /// (so Backspace edits the real input) and what the miss-fallback searches
    /// (padding zeros are not part of the user's intent, typed zeros are).
    private mutating func enterSelecting(lookup: String, typed: String) -> [ComposerEffect] {
        var cands: [CharEntry]
        if lookup.count == LexiconFormat.codeLength {
            cands = lexicon.exact(code: lookup)
            if cands.isEmpty {
                cands = lexicon.prefix(code: typed)
            }
        } else {
            cands = lexicon.prefix(code: lookup)
        }
        if let r = ranker { cands = r.rank(cands, buffer: lookup) }
        if cands.isEmpty {
            // Spec §3.2: keep buffer, signal "no match", allow user to Backspace.
            state = .composing(buffer: typed)
            return [.beep]
        }
        state = .selecting(buffer: typed, candidates: cands, page: 0)
        return []
    }
}
