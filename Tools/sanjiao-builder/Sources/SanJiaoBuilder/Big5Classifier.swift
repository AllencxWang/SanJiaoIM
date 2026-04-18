import Foundation
import SanJiaoCore

public enum Big5Classifier {
    /// Approximate Big5 tier classification based on Unicode scalar ranges.
    /// - Big5F: CJK Unified Ideographs common set (U+4E00..U+9FFF) that map to Big5 level-1.
    /// - Big5LF: remaining Big5 level-2 ideographs.
    /// - Big5Other: non-Han characters (punctuation, symbols).
    /// - CjkExt: SIP / supplementary planes (U+20000+).
    public static func classify(_ character: String) -> Layer {
        guard let scalar = character.unicodeScalars.first else { return .big5Other }
        let v = scalar.value

        // Supplementary plane → CJK Extension B/C/D/E/F/G.
        if v >= 0x20000 { return .cjkExt }

        // BMP Han region.
        if (0x4E00...0x9FFF).contains(v) {
            // Crude frequency split: level-1 Big5 covers the densely-used middle range.
            // Precise list would need a Big5 table; for v0.1 we use a heuristic range.
            if (0x4E00...0x9FA5).contains(v) { return isCommonHan(v) ? .big5F : .big5LF }
            return .big5LF
        }

        // Compatibility / radicals / extension A.
        if (0x3400...0x4DBF).contains(v) { return .cjkExt }
        if (0xF900...0xFAFF).contains(v) { return .big5LF }

        return .big5Other
    }

    /// Returns true for the ~5400 most common Han ideographs (Big5 level-1 approximation).
    /// Uses Unicode scalar intersection with the BIG5_LEVEL1 table.
    private static func isCommonHan(_ v: UInt32) -> Bool {
        Big5Level1.contains(v)
    }
}
