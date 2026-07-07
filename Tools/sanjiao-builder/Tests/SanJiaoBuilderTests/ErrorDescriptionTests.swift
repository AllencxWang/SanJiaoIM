import XCTest
@testable import SanJiaoBuilder

/// The CLI prints `error.localizedDescription` — every error case must carry
/// its diagnostic payload (line numbers, offending content) through it.
final class ErrorDescriptionTests: XCTestCase {
    func testParserErrorsCarryDiagnostics() {
        XCTAssertTrue(
            CinParserError.invalidCodeLength(line: 42, code: "12345").localizedDescription
                .contains("42"))
        XCTAssertTrue(
            CinParserError.malformedLine(line: 7, content: "garbage here").localizedDescription
                .contains("garbage here"))
        XCTAssertTrue(
            CinParserError.ioError("no such file").localizedDescription
                .contains("no such file"))
    }

    func testWriterErrorsCarryDiagnostics() {
        XCTAssertTrue(
            LexiconWriterError.invalidCodeLength("12345").localizedDescription
                .contains("12345"))
        XCTAssertTrue(
            LexiconWriterError.characterEncodingFailed("字").localizedDescription
                .contains("字"))
    }
}
