import XCTest
import SanJiaoCore
@testable import SanJiaoBuilder

final class Big5ClassifierTests: XCTestCase {
    func testCommonHanClassifiedAsBig5F() {
        XCTAssertEqual(Big5Classifier.classify("一"), .big5F)
        XCTAssertEqual(Big5Classifier.classify("中"), .big5F)
    }

    func testLessCommonHanClassifiedAsBig5LF() {
        // 龢 is a Big5 level-2 (less frequent) ideograph
        XCTAssertEqual(Big5Classifier.classify("龢"), .big5LF)
    }

    func testCjkExtensionCharacterClassifiedAsCjkExt() {
        // 𡯬 is U+21BEC, CJK Extension B
        XCTAssertEqual(Big5Classifier.classify("𡯬"), .cjkExt)
    }

    func testNonHanCharacterClassifiedAsOther() {
        XCTAssertEqual(Big5Classifier.classify("═"), .big5Other)
    }
}
