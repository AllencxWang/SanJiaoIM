import Foundation

/// Stub `Ranker` — Task 11 will replace with full scoring (frequency, layer,
/// prefix-exactness, recency). For now it's a pass-through so `Composer` can
/// accept an optional `Ranker` parameter for forward-compat.
public struct Ranker: Sendable {
    public init() {}

    public func rank(_ entries: [CharEntry], buffer: String) -> [CharEntry] {
        entries
    }
}
