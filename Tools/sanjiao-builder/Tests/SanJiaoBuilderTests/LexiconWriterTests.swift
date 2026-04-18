import XCTest
import SanJiaoCore
@testable import SanJiaoBuilder

final class LexiconWriterTests: XCTestCase {
    func testWritesHeaderMagicAndVersion() throws {
        let entries = [
            CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
            CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
        ]
        let data = try LexiconWriter.serialize(entries: entries)
        XCTAssertEqual(Array(data.prefix(4)), LexiconFormat.magic)
        let version = data.subdata(in: 4..<6).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
        XCTAssertEqual(version, LexiconFormat.version)
    }

    func testEmitsExpectedEntryCount() throws {
        let entries = [
            CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
        ]
        let data = try LexiconWriter.serialize(entries: entries)
        let count = data.subdata(in: 6..<10).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        XCTAssertEqual(count, 1)
    }

    func testRejectsNonSixDigitCode() {
        let bad = [CharEntry(code: "123", character: "X", layer: .big5F, ordinal: 0)]
        XCTAssertThrowsError(try LexiconWriter.serialize(entries: bad))
    }
}
