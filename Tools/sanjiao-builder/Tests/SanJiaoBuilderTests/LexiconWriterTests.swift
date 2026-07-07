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

    func testEmitsGoldenBytesForTwoEntries() throws {
        let entries = [
            CharEntry(code: "100301", character: "A", layer: .big5Other, ordinal: 0),
            CharEntry(code: "100302", character: "B", layer: .big5F, ordinal: 1),
        ]
        let data = try LexiconWriter.serialize(entries: entries)
        // Header: magic(4) + version u16 LE (0x0001) + entryCount u32 LE (0x00000002) = 10 bytes
        XCTAssertEqual(Array(data[0..<4]), LexiconFormat.magic)
        XCTAssertEqual(Array(data[4..<6]), [0x01, 0x00])
        XCTAssertEqual(Array(data[6..<10]), [0x02, 0x00, 0x00, 0x00])
        // Entry 0: code "100301" (6B) + layer 0x02 (big5Other) + ordinal 0 (u32 LE) + charLen 1 + "A"
        XCTAssertEqual(Array(data[10..<16]), Array("100301".utf8))
        XCTAssertEqual(data[16], Layer.big5Other.rawValue)
        XCTAssertEqual(Array(data[17..<21]), [0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(data[21], 1)
        XCTAssertEqual(Array(data[22..<23]), Array("A".utf8))
        // Entry 1 starts at 23: code "100302" + layer 0x00 (big5F) + ordinal 1 + charLen 1 + "B"
        XCTAssertEqual(Array(data[23..<29]), Array("100302".utf8))
        XCTAssertEqual(data[29], Layer.big5F.rawValue)
        XCTAssertEqual(Array(data[30..<34]), [0x01, 0x00, 0x00, 0x00])
        XCTAssertEqual(data[34], 1)
        XCTAssertEqual(Array(data[35..<36]), Array("B".utf8))
        // The file ends after the entries — the reader builds its own index,
        // so no index section is written.
        XCTAssertEqual(data.count, 36)
    }
}
