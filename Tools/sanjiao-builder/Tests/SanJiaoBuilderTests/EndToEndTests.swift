import XCTest
import SanJiaoCore
@testable import SanJiaoBuilder

final class EndToEndTests: XCTestCase {
    func testBuildProducesLoadableBin() throws {
        let cin = """
        %chardef begin
        100301 一
        100302 丁
        999978 鬵
        %chardef end
        """
        let raws = try CinParser.parse(string: cin)
        let entries = BuilderPipeline.assemble(from: raws)
        XCTAssertEqual(entries.count, 3)
        let bin = try LexiconWriter.serialize(entries: entries)
        let loaded = try LexiconReader.load(data: bin)
        XCTAssertEqual(loaded.entries.map(\.character), ["一", "丁", "鬵"])
        XCTAssertTrue(loaded.entries.allSatisfy { $0.ordinal < UInt32(entries.count) })
    }
}
