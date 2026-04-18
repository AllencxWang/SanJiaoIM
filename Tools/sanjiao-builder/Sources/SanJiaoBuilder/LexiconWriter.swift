import Foundation
import SanJiaoCore

public enum LexiconWriterError: Error {
    case invalidCodeLength(String)
    case characterEncodingFailed(String)
}

public enum LexiconWriter {
    /// Binary layout:
    ///   magic (4) | version (u16) | entryCount (u32)
    ///   entries: [ codeBytes(6) | layer(u8) | ordinal(u32) | charLen(u8) | charUTF8(var) ]
    ///   index: [ codeBytes(6) | firstEntryIndex(u32) | entryCount(u16) ]  sorted by code
    ///   indexCount (u32) at EOF
    public static func serialize(entries: [CharEntry]) throws -> Data {
        var data = Data()
        data.append(contentsOf: LexiconFormat.magic)
        data.append(contentsOf: UInt16(LexiconFormat.version).littleEndianBytes)
        data.append(contentsOf: UInt32(entries.count).littleEndianBytes)

        // Group entries by code (preserve input order within a group).
        var grouped: [(code: String, indices: [Int])] = []
        var firstByCode: [String: Int] = [:]
        for (i, e) in entries.enumerated() {
            if firstByCode[e.code] == nil {
                firstByCode[e.code] = grouped.count
                grouped.append((e.code, [i]))
            } else {
                grouped[firstByCode[e.code]!].indices.append(i)
            }
        }

        // Write entries in original order (so ordinals match file position).
        for entry in entries {
            guard entry.code.count == LexiconFormat.codeLength else {
                throw LexiconWriterError.invalidCodeLength(entry.code)
            }
            data.append(contentsOf: Array(entry.code.utf8))
            data.append(entry.layer.rawValue)
            data.append(contentsOf: entry.ordinal.littleEndianBytes)
            guard let utf8 = entry.character.data(using: .utf8), utf8.count < 256 else {
                throw LexiconWriterError.characterEncodingFailed(entry.character)
            }
            data.append(UInt8(utf8.count))
            data.append(utf8)
        }

        // Sorted index.
        let sorted = grouped.sorted { $0.code < $1.code }
        for (code, indices) in sorted {
            data.append(contentsOf: Array(code.utf8))
            data.append(contentsOf: UInt32(indices.first!).littleEndianBytes)
            data.append(contentsOf: UInt16(indices.count).littleEndianBytes)
        }
        data.append(contentsOf: UInt32(sorted.count).littleEndianBytes)
        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian) { Array($0) }
    }
}
