import XCTest
@testable import SanJiaoCore

final class LexiconReaderTests: XCTestCase {
    func testRejectsBadMagic() {
        var bad = Data("XXXX".utf8)
        bad.append(contentsOf: UInt16(1).littleEndianBytes)
        bad.append(contentsOf: UInt32(0).littleEndianBytes)
        XCTAssertThrowsError(try LexiconReader.load(data: bad))
    }

    func testRejectsFutureVersion() {
        var d = Data(LexiconFormat.magic)
        d.append(contentsOf: UInt16(999).littleEndianBytes)
        d.append(contentsOf: UInt32(0).littleEndianBytes)
        XCTAssertThrowsError(try LexiconReader.load(data: d))
    }

    /// A one-entry lexicon: magic + version + count + (code, layer, ordinal, charLen, char)
    private func validLexiconData() -> Data {
        var d = Data(LexiconFormat.magic)
        d.append(contentsOf: LexiconFormat.version.littleEndianBytes)
        d.append(contentsOf: UInt32(1).littleEndianBytes)
        d.append(Data("100301".utf8))                     // code
        d.append(0)                                       // layer .big5F
        d.append(contentsOf: UInt32(7).littleEndianBytes) // ordinal
        let char = Data("一".utf8)
        d.append(UInt8(char.count))                       // charLen
        d.append(char)
        return d
    }

    func testLoadsFromDataSliceWithNonZeroStartIndex() throws {
        let valid = validLexiconData()
        let padded = Data(repeating: 0xFF, count: 8) + valid
        let slice = padded[8...]
        XCTAssertNotEqual(slice.startIndex, 0, "precondition: must exercise a real slice")

        let loaded = try LexiconReader.load(data: slice)
        XCTAssertEqual(loaded.entries, [
            CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 7)
        ])
        XCTAssertEqual(loaded.index["100301"], [0])
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian) { Array($0) }
    }
}
