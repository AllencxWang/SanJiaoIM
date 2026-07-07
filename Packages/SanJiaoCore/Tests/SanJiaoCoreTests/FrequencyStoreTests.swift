import XCTest
@testable import SanJiaoCore

final class FrequencyStoreTests: XCTestCase {
    private func tmpFile() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        return dir.appendingPathComponent("freq-\(UUID().uuidString).json")
    }

    func testBumpIncrementsCount() throws {
        let url = tmpFile()
        let store = try FrequencyStore(fileURL: url, flushEvery: 1)
        store.bump(code: "100301", character: "一")
        store.bump(code: "100301", character: "一")
        XCTAssertEqual(store.count(code: "100301", character: "一"), 2)
    }

    func testFlushAndReload() throws {
        let url = tmpFile()
        do {
            let store = try FrequencyStore(fileURL: url, flushEvery: 1)
            store.bump(code: "100301", character: "一")
            try store.flush()
        }
        let reloaded = try FrequencyStore(fileURL: url, flushEvery: 1)
        XCTAssertEqual(reloaded.count(code: "100301", character: "一"), 1)
    }

    func testStatsForEntriesReturnsWholeBatchInOneCall() throws {
        let url = tmpFile()
        let store = try FrequencyStore(fileURL: url, flushEvery: 100)
        let t = Date(timeIntervalSince1970: 1_000_000)
        store.bump(code: "100301", character: "一", now: t)
        store.bump(code: "100301", character: "一", now: t)
        let entries = [
            CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
            CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
        ]
        let result = store.stats(for: entries)
        XCTAssertEqual(result[0], FrequencyStore.Stats(count: 2, lastUsed: t))
        XCTAssertNil(result[1])
    }

    func testCorruptFileReseedsAndBackups() throws {
        let url = tmpFile()
        try Data("not json".utf8).write(to: url)
        let store = try FrequencyStore(fileURL: url, flushEvery: 1)
        XCTAssertEqual(store.count(code: "x", character: "y"), 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path + ".corrupt.bak"))
    }
}
