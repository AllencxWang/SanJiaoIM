import Foundation

/// Set of Unicode scalar values derived from Big5-HKSCS mapping.
/// This is a superset of classic Big5 level-1 (5401 entries); the HKSCS
/// codec yields 5421 entries including 20 HKSCS-only additions.
/// Regenerate via: `Tools/sanjiao-builder/scripts/generate-big5-level1.py`.
enum Big5Level1 {
    static func contains(_ v: UInt32) -> Bool {
        _table.withUnsafeBufferPointer { buf in
            var lo = 0, hi = buf.count - 1
            while lo <= hi {
                let m = (lo + hi) / 2
                if buf[m] == v { return true }
                if buf[m] < v { lo = m + 1 } else { hi = m - 1 }
            }
            return false
        }
    }

    /// Populated by one-off bootstrap script.
    static let _table: [UInt32] = Big5Level1Table.values
}
