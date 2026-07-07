import Foundation

/// Set of Unicode scalar values derived from Big5-HKSCS mapping.
/// This is a superset of classic Big5 level-1 (5401 entries); the HKSCS
/// codec yields 5421 entries including 20 HKSCS-only additions.
/// Regenerate via: `Tools/sanjiao-builder/scripts/generate-big5-level1.py`.
enum Big5Level1 {
    static func contains(_ v: UInt32) -> Bool {
        _table.contains(v)
    }

    /// Populated by one-off bootstrap script.
    static let _table: Set<UInt32> = Set(Big5Level1Table.values)
}
