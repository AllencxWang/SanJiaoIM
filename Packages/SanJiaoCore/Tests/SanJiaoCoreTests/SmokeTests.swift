import XCTest
@testable import SanJiaoCore

final class SmokeTests: XCTestCase {
    func testVersionIsPopulated() {
        XCTAssertFalse(SanJiaoCore.version.isEmpty)
    }
}
