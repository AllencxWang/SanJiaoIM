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
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian) { Array($0) }
    }
}
