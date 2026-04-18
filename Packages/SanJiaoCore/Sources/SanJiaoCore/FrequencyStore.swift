import Foundation

public struct FrequencyStore: Sendable {
    public struct Stats: Codable, Equatable, Sendable {
        public var count: UInt32
        public var lastUsed: Date
    }

    private var stats: [String: Stats]
    private let fileURL: URL
    private let flushEvery: Int
    private var pendingBumps: Int = 0

    public init(fileURL: URL, flushEvery: Int = 20) throws {
        self.fileURL = fileURL
        self.flushEvery = flushEvery
        self.stats = Self.loadOrReset(url: fileURL)
    }

    private static func loadOrReset(url: URL) -> [String: Stats] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: Stats].self, from: data)
        } catch {
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("corrupt.bak"))
            return [:]
        }
    }

    private static func key(code: String, character: String) -> String {
        "\(code)|\(character)"
    }

    public func count(code: String, character: String) -> UInt32 {
        stats[Self.key(code: code, character: character)]?.count ?? 0
    }

    public func lastUsed(code: String, character: String) -> Date? {
        stats[Self.key(code: code, character: character)]?.lastUsed
    }

    public mutating func bump(code: String, character: String, now: Date = .now) {
        let k = Self.key(code: code, character: character)
        var s = stats[k] ?? Stats(count: 0, lastUsed: now)
        s.count &+= 1
        s.lastUsed = now
        stats[k] = s
        pendingBumps += 1
        if pendingBumps >= flushEvery {
            try? flush()
        }
    }

    public mutating func flush() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(stats)
        try data.write(to: fileURL, options: .atomic)
        pendingBumps = 0
    }

    public mutating func reset() throws {
        stats.removeAll()
        pendingBumps = 0
        try flush()
    }
}
