import XCTest
@testable import SanJiaoBuilder

final class CinParserTests: XCTestCase {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "mini", withExtension: "cin",
                          subdirectory: "Fixtures")!
    }

    func testParsesAllChardefs() throws {
        let entries = try CinParser.parse(fileURL: fixtureURL())
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(entries[0].code, "100301")
        XCTAssertEqual(entries[0].character, "一")
        XCTAssertEqual(entries[3].character, "鬵")
    }

    func testPreservesSourceOrderForDuplicateCodes() throws {
        let entries = try CinParser.parse(fileURL: fixtureURL())
        let codes102 = entries.filter { $0.code == "100302" }
        XCTAssertEqual(codes102.map(\.character), ["丁", "七"])
    }

    func testRejectsInvalidCodeLength() {
        let bad = """
        %chardef begin
        12345 X
        %chardef end
        """
        XCTAssertThrowsError(try CinParser.parse(string: bad))
    }

    func testParsesRealCin() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // SanJiaoBuilderTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // sanjiao-builder
            .deletingLastPathComponent() // Tools
        let cin = repoRoot.appendingPathComponent("Vendor/3corner.cin")
        let entries = try CinParser.parse(fileURL: cin)
        XCTAssertGreaterThan(entries.count, 30000)
        XCTAssertLessThan(entries.count, 35000)
    }
}
