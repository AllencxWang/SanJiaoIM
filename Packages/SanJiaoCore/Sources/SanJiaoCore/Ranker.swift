import Foundation

public struct Ranker: Sendable {
    private let frequencies: FrequencyStore
    private let alpha: Double
    private let beta: Double

    public init(frequencies: FrequencyStore, alpha: Double = 5.0, beta: Double = 0.1) {
        self.frequencies = frequencies
        self.alpha = alpha
        self.beta = beta
    }

    public func rank(_ entries: [CharEntry], buffer: String, now: Date = .now) -> [CharEntry] {
        let scored: [(Int, CharEntry, Double)] = entries.enumerated().map { pair in
            (pair.offset, pair.element, score(pair.element, now: now))
        }
        let sorted = scored.sorted { a, b in
            if a.2 != b.2 { return a.2 < b.2 }
            return a.0 < b.0
        }
        return sorted.map { $0.1 }
    }

    private func score(_ e: CharEntry, now: Date) -> Double {
        var s = Double(e.layer.rawValue) * 100_000 + Double(e.ordinal)
        let freq = frequencies.count(code: e.code, character: e.character)
        s -= alpha * log(1.0 + Double(freq))
        if let last = frequencies.lastUsed(code: e.code, character: e.character) {
            let days = now.timeIntervalSince(last) / 86_400.0
            s += beta * max(0, days)
        }
        return s
    }
}
