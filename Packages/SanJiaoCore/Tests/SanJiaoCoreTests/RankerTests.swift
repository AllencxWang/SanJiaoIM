import XCTest
@testable import SanJiaoCore

final class RankerTests: XCTestCase {
    private func entries() -> [CharEntry] {
        [
            CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
            CharEntry(code: "100302", character: "七", layer: .big5F, ordinal: 2),
            CharEntry(code: "100302", character: "𡯬", layer: .cjkExt, ordinal: 3),
        ]
    }

    func testLayerOrderingWithoutFrequency() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rank-\(UUID().uuidString).json")
        let store = try FrequencyStore(fileURL: url)
        let ranker = Ranker(frequencies: store)
        let ranked = ranker.rank(entries(), buffer: "100302")
        XCTAssertEqual(ranked.last?.character, "𡯬") // CJK ext sinks
        XCTAssertEqual(ranked.first?.character, "丁") // lowest ordinal first
    }

    func testFrequencyPromotesCandidate() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rank-\(UUID().uuidString).json")
        let store = try FrequencyStore(fileURL: url)
        for _ in 0..<10 { store.bump(code: "100302", character: "七") }
        let ranker = Ranker(frequencies: store)
        let ranked = ranker.rank(entries(), buffer: "100302")
        XCTAssertEqual(ranked.first?.character, "七")
    }

    func testBumpAfterRankerConstructionAffectsRanking() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rank-\(UUID().uuidString).json")
        let store = try FrequencyStore(fileURL: url)
        let ranker = Ranker(frequencies: store)

        // Pre-bump check: default ordering
        let before = ranker.rank(entries(), buffer: "100302")
        XCTAssertEqual(before.first?.character, "丁")

        // Bump AFTER Ranker init — with class semantics this should take effect
        for _ in 0..<10 { store.bump(code: "100302", character: "七") }

        let after = ranker.rank(entries(), buffer: "100302")
        XCTAssertEqual(after.first?.character, "七")
    }
}
