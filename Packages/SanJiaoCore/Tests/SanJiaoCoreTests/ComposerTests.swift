import XCTest
@testable import SanJiaoCore

final class ComposerTests: XCTestCase {
    private let yi = CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0)
    private let ding = CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1)

    private func lex() -> Lexicon {
        Lexicon(loaded: LoadedLexicon(
            entries: [yi, ding],
            index: ["100301": [0], "100302": [1]]
        ))
    }

    func testDigitFromEmptyMovesToComposing() {
        var c = Composer(lexicon: lex())
        let fx = c.handle(.digit("1"))
        XCTAssertEqual(c.state, .composing(buffer: "1"))
        XCTAssertEqual(fx, [])
    }

    func testSixthDigitAutoTransitionsToSelecting() {
        var c = Composer(lexicon: lex())
        _ = c.handle(.digit("1")); _ = c.handle(.digit("0")); _ = c.handle(.digit("0"))
        _ = c.handle(.digit("3")); _ = c.handle(.digit("0")); _ = c.handle(.digit("1"))
        guard case .selecting(let buf, let cands, _) = c.state else {
            return XCTFail("expected selecting, got \(c.state)")
        }
        XCTAssertEqual(buf, "100301")
        XCTAssertEqual(cands.first?.character, "一")
    }

    func testSpaceCommitsFirstCandidate() {
        var c = Composer(lexicon: lex())
        for ch in "100301" { _ = c.handle(.digit(ch)) }
        let fx = c.handle(.space)
        XCTAssertEqual(fx, [.commit(yi)])
        XCTAssertEqual(c.state, .empty)
    }

    func testEnterPadsZerosAndCommits() {
        var c = Composer(lexicon: lex())
        _ = c.handle(.digit("1")); _ = c.handle(.digit("0")); _ = c.handle(.digit("0"))
        _ = c.handle(.digit("3"))
        _ = c.handle(.enter) // pads to 100300 → no exact match → fallback to prefix "1003"
        guard case .selecting(_, let cands, _) = c.state else {
            return XCTFail("expected selecting")
        }
        XCTAssertFalse(cands.isEmpty)
    }

    func testEscapeFromComposingReturnsToEmpty() {
        var c = Composer(lexicon: lex())
        _ = c.handle(.digit("1"))
        _ = c.handle(.escape)
        XCTAssertEqual(c.state, .empty)
    }

    func testBackspaceFromSelectingReturnsToComposing() {
        var c = Composer(lexicon: lex())
        for ch in "100301" { _ = c.handle(.digit(ch)) }
        _ = c.handle(.backspace)
        XCTAssertEqual(c.state, .composing(buffer: "10030"))
    }

    func testPassthroughFromEmpty() {
        var c = Composer(lexicon: lex())
        let fx = c.handle(.passthrough("a"))
        XCTAssertEqual(fx, [.passthrough("a")])
    }

    func testPassthroughFromComposingDropsBuffer() {
        var c = Composer(lexicon: lex())
        _ = c.handle(.digit("1"))
        let fx = c.handle(.passthrough("a"))
        XCTAssertEqual(fx, [.passthrough("a")])
        XCTAssertEqual(c.state, .empty)
    }

    func testPickInSelectingCommits() {
        var c = Composer(lexicon: lex())
        for ch in "100301" { _ = c.handle(.digit(ch)) }
        let fx = c.handle(.pick(1))
        XCTAssertEqual(fx, [.commit(yi)])
        XCTAssertEqual(c.state, .empty)
    }

    // Richer fixture for paging + multi-candidate tests
    private func multiLex() -> Lexicon {
        var entries: [CharEntry] = []
        var index: [String: [Int]] = [:]
        // 15 entries all under code "123400"
        for i in 0..<15 {
            let e = CharEntry(code: "123400", character: "字\(i)", layer: .big5F, ordinal: UInt32(i))
            entries.append(e)
            index["123400", default: []].append(i)
        }
        return Lexicon(loaded: LoadedLexicon(entries: entries, index: index))
    }

    func testDisplayBufferShowsTypedCodeWhileComposingAndSelecting() {
        var c = Composer(lexicon: lex())
        XCTAssertNil(c.state.displayBuffer)
        _ = c.handle(.digit("1"))
        XCTAssertEqual(c.state.displayBuffer, "1")
        for ch in "00301" { _ = c.handle(.digit(ch)) }
        guard case .selecting = c.state else { return XCTFail("expected selecting") }
        XCTAssertEqual(c.state.displayBuffer, "100301")
        _ = c.handle(.escape)
        XCTAssertNil(c.state.displayBuffer)
    }

    func testVisibleCandidatesReturnsCurrentPageSlice() {
        var c = Composer(lexicon: multiLex())
        for ch in "123400" { _ = c.handle(.digit(ch)) }
        XCTAssertEqual(c.visibleCandidates.count, 10)
        XCTAssertEqual(c.visibleCandidates.first?.character, "字0")
        _ = c.handle(.nextPage)
        XCTAssertEqual(c.visibleCandidates.count, 5)
        XCTAssertEqual(c.visibleCandidates.first?.character, "字10")
        _ = c.handle(.escape)
        XCTAssertEqual(c.visibleCandidates, [])
    }

    func testPickCharacterCommitsMatchingVisibleCandidate() {
        var c = Composer(lexicon: multiLex())
        for ch in "123400" { _ = c.handle(.digit(ch)) }
        _ = c.handle(.nextPage)
        // Mouse click on "字12" in the candidate window (page 1)
        let fx = c.handle(.pickCharacter("字12"))
        XCTAssertEqual(fx, [.commit(CharEntry(code: "123400", character: "字12", layer: .big5F, ordinal: 12))])
        XCTAssertEqual(c.state, .empty)
    }

    func testPickCharacterUnknownCharacterBeeps() {
        var c = Composer(lexicon: multiLex())
        for ch in "123400" { _ = c.handle(.digit(ch)) }
        let stateBefore = c.state
        let fx = c.handle(.pickCharacter("無"))
        XCTAssertEqual(fx, [.beep])
        XCTAssertEqual(c.state, stateBefore)
    }

    func testNoMatchStaysInComposingWithBeep() {
        var c = Composer(lexicon: lex())
        // "999999" matches nothing in lex()
        for ch in "99999" { _ = c.handle(.digit(ch)) }
        let fx = c.handle(.digit("9"))
        XCTAssertEqual(c.state, .composing(buffer: "999999"))
        XCTAssertEqual(fx, [.beep])
    }

    // Fixture with decoy codes for prefix-fallback tests
    private func fallbackLex() -> Lexicon {
        Lexicon(loaded: LoadedLexicon(
            entries: [
                CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
                CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
                CharEntry(code: "110000", character: "乙", layer: .big5F, ordinal: 2),
                CharEntry(code: "012345", character: "丙", layer: .big5F, ordinal: 3),
            ],
            index: ["100301": [0], "100302": [1], "110000": [2], "012345": [3]]
        ))
    }

    func testEnterFallbackUsesTypedDigitsNotStrippedAtZero() {
        var c = Composer(lexicon: fallbackLex())
        _ = c.handle(.digit("1")); _ = c.handle(.digit("0"))
        _ = c.handle(.enter) // pads to "100000", no exact match → fallback prefix "10"
        guard case .selecting(_, let cands, _) = c.state else {
            return XCTFail("expected selecting, got \(c.state)")
        }
        XCTAssertEqual(cands.map(\.character).sorted(), ["一", "丁"])
        XCTAssertFalse(cands.contains { $0.character == "乙" })
    }

    func testEnterFallbackWorksForZeroLeadingCodes() {
        var c = Composer(lexicon: fallbackLex())
        _ = c.handle(.digit("0")); _ = c.handle(.digit("1"))
        _ = c.handle(.enter) // pads to "010000", no exact match → fallback prefix "01"
        guard case .selecting(_, let cands, _) = c.state else {
            return XCTFail("expected selecting, got \(c.state)")
        }
        XCTAssertEqual(cands.map(\.character), ["丙"])
    }

    func testSelectingAfterEnterKeepsTypedBufferForBackspace() {
        var c = Composer(lexicon: fallbackLex())
        _ = c.handle(.digit("1")); _ = c.handle(.digit("0"))
        _ = c.handle(.enter)
        guard case .selecting(let buf, _, _) = c.state else {
            return XCTFail("expected selecting, got \(c.state)")
        }
        XCTAssertEqual(buf, "10")
        _ = c.handle(.backspace)
        XCTAssertEqual(c.state, .composing(buffer: "1"))
    }

    func testEnterNoMatchKeepsTypedBuffer() {
        var c = Composer(lexicon: fallbackLex())
        _ = c.handle(.digit("3")); _ = c.handle(.digit("9"))
        let fx = c.handle(.enter) // pads to "390000", nothing matches
        XCTAssertEqual(fx, [.beep])
        XCTAssertEqual(c.state, .composing(buffer: "39"))
    }

    func testCommitCarriesFullEntryForFrequencyLearning() {
        var c = Composer(lexicon: fallbackLex())
        // Partial input "10" + Space → prefix candidates → pick 1.
        // The commit must carry the entry (with its full 6-digit code), not just
        // the display text, so frequency learning keys match Ranker lookups.
        _ = c.handle(.digit("1")); _ = c.handle(.digit("0"))
        _ = c.handle(.space)
        guard case .selecting = c.state else {
            return XCTFail("expected selecting, got \(c.state)")
        }
        let fx = c.handle(.pick(1))
        XCTAssertEqual(fx, [.commit(CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0))])
    }

    func testEmptyStateForwardsEditingKeysAsPassthrough() {
        var c = Composer(lexicon: lex())
        XCTAssertEqual(c.handle(.space), [.passthrough(" ")])
        XCTAssertEqual(c.handle(.enter), [.passthrough("\r")])
        XCTAssertEqual(c.handle(.backspace), [.passthrough("\u{7F}")])
        XCTAssertEqual(c.handle(.escape), [.passthrough("\u{1B}")])
        XCTAssertEqual(c.handle(.prevPage), [.passthrough(",")])
        XCTAssertEqual(c.handle(.nextPage), [.passthrough(".")])
        XCTAssertEqual(c.state, .empty)
    }

    func testDigitIntoFullNoMatchBufferBeepsAndKeepsBuffer() {
        var c = Composer(lexicon: lex())
        // "999999" matches nothing → stays composing with a full 6-digit buffer
        for ch in "999999" { _ = c.handle(.digit(ch)) }
        let fx = c.handle(.digit("1"))
        XCTAssertEqual(c.state, .composing(buffer: "999999"))
        XCTAssertEqual(fx, [.beep])
    }

    func testSelectingPassthroughCommitsAndPassesKey() {
        var c = Composer(lexicon: lex())
        for ch in "100301" { _ = c.handle(.digit(ch)) }
        let fx = c.handle(.passthrough("a"))
        XCTAssertEqual(fx, [.commit(yi), .passthrough("a")])
        XCTAssertEqual(c.state, .empty)
    }

    func testSelectingEscapeReturnsToEmpty() {
        var c = Composer(lexicon: lex())
        for ch in "100301" { _ = c.handle(.digit(ch)) }
        _ = c.handle(.escape)
        XCTAssertEqual(c.state, .empty)
    }

    func testSelectingDigitYieldsBeep() {
        var c = Composer(lexicon: lex())
        for ch in "100301" { _ = c.handle(.digit(ch)) }
        let fx = c.handle(.digit("5"))
        XCTAssertEqual(fx, [.beep])
    }

    func testSelectingPagingAcrossTwoPages() {
        var c = Composer(lexicon: multiLex())
        for ch in "123400" { _ = c.handle(.digit(ch)) }
        guard case .selecting(_, let cands, let page0) = c.state else {
            return XCTFail("expected selecting")
        }
        XCTAssertEqual(cands.count, 15)
        XCTAssertEqual(page0, 0)

        _ = c.handle(.nextPage)
        guard case .selecting(_, _, let page1) = c.state else { return XCTFail() }
        XCTAssertEqual(page1, 1)

        // Pick 1 on page 1 should commit the 11th entry (index 10)
        let fx = c.handle(.pick(1))
        XCTAssertEqual(fx, [.commit(CharEntry(code: "123400", character: "字10", layer: .big5F, ordinal: 10))])
        XCTAssertEqual(c.state, .empty)
    }
}
