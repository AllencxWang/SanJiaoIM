import XCTest
@testable import SanJiaoCore

final class ComposerTests: XCTestCase {
    private func lex() -> Lexicon {
        Lexicon(loaded: LoadedLexicon(
            entries: [
                CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
                CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
            ],
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
        XCTAssertEqual(fx, [.commit("一")])
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
        XCTAssertEqual(fx, [.commit("一")])
        XCTAssertEqual(c.state, .empty)
    }
}
