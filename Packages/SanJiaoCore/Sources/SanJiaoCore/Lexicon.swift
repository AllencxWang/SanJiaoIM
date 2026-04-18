import Foundation

public struct Lexicon: Sendable {
    private let loaded: LoadedLexicon
    private let sortedCodes: [String]

    public init(loaded: LoadedLexicon) {
        self.loaded = loaded
        self.sortedCodes = loaded.index.keys.sorted()
    }

    public static func load(url: URL) throws -> Lexicon {
        Lexicon(loaded: try LexiconReader.load(url: url))
    }

    public var count: Int { loaded.entries.count }

    /// Exact 6-digit code lookup.
    public func exact(code: String) -> [CharEntry] {
        guard let indices = loaded.index[code] else { return [] }
        return indices.map { loaded.entries[$0] }
    }

    /// Prefix lookup — returns all entries whose code starts with `prefix`.
    public func prefix(code prefix: String) -> [CharEntry] {
        guard !prefix.isEmpty else { return [] }
        var lo = lowerBound(sortedCodes, target: prefix)
        var result: [CharEntry] = []
        while lo < sortedCodes.count, sortedCodes[lo].hasPrefix(prefix) {
            if let indices = loaded.index[sortedCodes[lo]] {
                result.append(contentsOf: indices.map { loaded.entries[$0] })
            }
            lo += 1
        }
        return result
    }

    private func lowerBound(_ a: [String], target: String) -> Int {
        var lo = 0, hi = a.count
        while lo < hi {
            let m = (lo + hi) / 2
            if a[m] < target { lo = m + 1 } else { hi = m }
        }
        return lo
    }
}
