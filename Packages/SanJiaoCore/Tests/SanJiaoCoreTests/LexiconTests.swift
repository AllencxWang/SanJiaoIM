import XCTest
@testable import SanJiaoCore

final class LexiconTests: XCTestCase {
    private func makeLexicon() -> Lexicon {
        Lexicon(loaded: LoadedLexicon(
            entries: [
                CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
                CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
                CharEntry(code: "100302", character: "七", layer: .big5F, ordinal: 2),
                CharEntry(code: "100302", character: "𡯬", layer: .cjkExt, ordinal: 3),
            ],
            index: ["100301": [0], "100302": [1, 2, 3]]
        ))
    }

    func testExactLookup() {
        let l = makeLexicon()
        let hits = l.exact(code: "100302")
        XCTAssertEqual(hits.map(\.character), ["丁", "七", "𡯬"])
    }

    func testPrefixLookupExpandsMissingDigits() {
        let l = makeLexicon()
        let hits = l.prefix(code: "1003")
        XCTAssertEqual(Set(hits.map(\.character)), Set(["一", "丁", "七", "𡯬"]))
    }

    func testExactReturnsEmptyWhenUnknown() {
        let l = makeLexicon()
        XCTAssertTrue(l.exact(code: "000000").isEmpty)
    }
}
