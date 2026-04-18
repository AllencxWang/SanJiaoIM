import Foundation

/// Set of Unicode scalar values in Big5 level-1 (常用字).
/// Source: derived from Big5-HKSCS mapping via Python script (Step 5).
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
