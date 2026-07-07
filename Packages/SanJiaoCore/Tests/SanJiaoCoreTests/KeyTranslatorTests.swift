import XCTest
@testable import SanJiaoCore

final class KeyTranslatorTests: XCTestCase {
    private let selecting = ComposerState.selecting(
        buffer: "123400",
        candidates: [CharEntry(code: "123400", character: "字", layer: .big5F, ordinal: 0)],
        page: 0)

    func testModifiedKeysAreNotOurs() {
        // Cmd+1 while selecting must NOT become a pick — nil means "let the system handle it"
        XCTAssertNil(KeyTranslator.translate(text: "1", isModified: true, state: selecting))
        XCTAssertNil(KeyTranslator.translate(text: "c", isModified: true, state: .composing(buffer: "12")))
        XCTAssertNil(KeyTranslator.translate(text: " ", isModified: true, state: .empty))
    }

    func testDigitsMapToDigitOrPickByState() {
        XCTAssertEqual(KeyTranslator.translate(text: "5", isModified: false, state: .empty), .digit("5"))
        XCTAssertEqual(KeyTranslator.translate(text: "5", isModified: false, state: selecting), .pick(5))
        XCTAssertEqual(KeyTranslator.translate(text: "0", isModified: false, state: selecting), .pick(10))
    }

    func testCommaAndPeriodPageOnlyWhileSelecting() {
        XCTAssertEqual(KeyTranslator.translate(text: ",", isModified: false, state: selecting), .prevPage)
        XCTAssertEqual(KeyTranslator.translate(text: ".", isModified: false, state: selecting), .nextPage)
        XCTAssertEqual(KeyTranslator.translate(text: ",", isModified: false, state: .empty), .passthrough(","))
        XCTAssertEqual(KeyTranslator.translate(text: ".", isModified: false, state: .composing(buffer: "1")), .passthrough("."))
    }

    func testEditingKeysMap() {
        XCTAssertEqual(KeyTranslator.translate(text: " ", isModified: false, state: .empty), .space)
        XCTAssertEqual(KeyTranslator.translate(text: "\r", isModified: false, state: .empty), .enter)
        XCTAssertEqual(KeyTranslator.translate(text: "\u{7F}", isModified: false, state: .empty), .backspace)
        XCTAssertEqual(KeyTranslator.translate(text: "\u{1B}", isModified: false, state: .empty), .escape)
    }

    func testLettersPassthroughAndEmptyTextIsNotOurs() {
        XCTAssertEqual(KeyTranslator.translate(text: "a", isModified: false, state: .empty), .passthrough("a"))
        XCTAssertNil(KeyTranslator.translate(text: nil, isModified: false, state: .empty))
        XCTAssertNil(KeyTranslator.translate(text: "", isModified: false, state: .empty))
    }
}
