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

    @discardableResult
    public mutating func handle(_ event: ComposerEvent) -> [ComposerEffect] {
        switch (state, event) {
        case (.empty, .digit(let d)):
            state = .composing(buffer: String(d))
            return []

        case (.empty, .passthrough(let c)):
            return [.passthrough(c)]

        case (.empty, _):
            return []

        case (.composing(let buf), .digit(let d)):
            let next = buf + String(d)
            if next.count == LexiconFormat.codeLength {
                return enterSelecting(buffer: next)
            }
            state = .composing(buffer: next)
            return []

        case (.composing(let buf), .space):
            return enterSelecting(buffer: buf)

        case (.composing(let buf), .enter):
            let padded = buf + String(repeating: "0", count: LexiconFormat.codeLength - buf.count)
            return enterSelecting(buffer: padded)

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

        case (.composing, .pick), (.composing, .nextPage), (.composing, .prevPage):
            return []

        case (.selecting(_, let cands, let page), .pick(let n)):
            let idx = page * pageSize + (n - 1)
            guard idx >= 0, idx < cands.count else { return [.beep] }
            let picked = cands[idx]
            state = .empty
            return [.commit(picked.character)]

        case (.selecting(_, let cands, let page), .space):
            let idx = page * pageSize
            guard idx < cands.count else { return [.beep] }
            state = .empty
            return [.commit(cands[idx].character)]

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
            if idx < cands.count { out.append(.commit(cands[idx].character)) }
            out.append(.passthrough(c))
            state = .empty
            return out

        case (.selecting, .enter):
            return [] // no-op; require explicit pick

        case (.selecting, .digit):
            return [.beep] // in selecting mode digits should have been routed as .pick
        }
    }

    private mutating func enterSelecting(buffer: String) -> [ComposerEffect] {
        var cands: [CharEntry]
        if buffer.count == LexiconFormat.codeLength {
            cands = lexicon.exact(code: buffer)
            if cands.isEmpty {
                cands = lexicon.prefix(code: String(buffer.prefix(while: { $0 != "0" })))
            }
        } else {
            cands = lexicon.prefix(code: buffer)
        }
        if let r = ranker { cands = r.rank(cands, buffer: buffer) }
        if cands.isEmpty {
            // Spec §3.2: keep buffer, signal "no match", allow user to Backspace.
            state = .composing(buffer: buffer)
            return [.beep]
        }
        state = .selecting(buffer: buffer, candidates: cands, page: 0)
        return []
    }
}
