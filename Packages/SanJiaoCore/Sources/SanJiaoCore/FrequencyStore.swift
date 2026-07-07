import Foundation

public final class FrequencyStore: @unchecked Sendable {
    public struct Stats: Codable, Equatable, Sendable {
        public var count: UInt32
        public var lastUsed: Date
    }

    private var stats: [String: Stats]
    private let fileURL: URL
    private let flushEvery: Int
    private var pendingBumps: Int = 0
    private let queue = DispatchQueue(label: "com.sanjiaoim.freq")

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
        queue.sync {
            stats[Self.key(code: code, character: character)]?.count ?? 0
        }
    }

    public func lastUsed(code: String, character: String) -> Date? {
        queue.sync {
            stats[Self.key(code: code, character: character)]?.lastUsed
        }
    }

    /// Batch lookup — one synchronized pass for a whole candidate list, instead
    /// of two queue round trips per candidate on the key-press hot path.
    public func stats(for entries: [CharEntry]) -> [Stats?] {
        queue.sync {
            entries.map { stats[Self.key(code: $0.code, character: $0.character)] }
        }
    }

    public func bump(code: String, character: String, now: Date = .now) {
        queue.sync {
            let k = Self.key(code: code, character: character)
            var s = stats[k] ?? Stats(count: 0, lastUsed: now)
            s.count &+= 1
            s.lastUsed = now
            stats[k] = s
            pendingBumps += 1
            if pendingBumps >= flushEvery {
                try? flushLocked()
            }
        }
    }

    public func flush() throws {
        try queue.sync {
            try flushLocked()
        }
    }

    private func flushLocked() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(stats)
        try data.write(to: fileURL, options: .atomic)
        pendingBumps = 0
    }

    public func reset() throws {
        try queue.sync {
            stats.removeAll()
            pendingBumps = 0
            try flushLocked()
        }
    }
}
