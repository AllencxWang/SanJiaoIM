import XCTest
import SanJiaoCore
@testable import SanJiaoBuilder

final class LexiconRoundTripTests: XCTestCase {
    func testWriterOutputIsReadableByReader() throws {
        let original = [
            CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
            CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
            CharEntry(code: "100302", character: "七", layer: .big5F, ordinal: 2),
            CharEntry(code: "999978", character: "鬵", layer: .big5LF, ordinal: 3),
        ]
        let bin = try LexiconWriter.serialize(entries: original)
        let loaded = try LexiconReader.load(data: bin)
        XCTAssertEqual(loaded.entries, original)
        XCTAssertEqual(loaded.index["100302"], [1, 2])
    }
}
