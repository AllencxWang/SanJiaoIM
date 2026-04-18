import XCTest
@testable import SanJiaoCore

final class CharEntryTests: XCTestCase {
    func testCharEntryEquality() {
        let a = CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 42)
        let b = CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 42)
        XCTAssertEqual(a, b)
    }

    func testLayerRawValueStable() {
        XCTAssertEqual(Layer.big5F.rawValue, 0)
        XCTAssertEqual(Layer.big5LF.rawValue, 1)
        XCTAssertEqual(Layer.big5Other.rawValue, 2)
        XCTAssertEqual(Layer.cjkExt.rawValue, 3)
    }
}
