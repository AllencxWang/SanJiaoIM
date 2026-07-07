import Foundation
import SanJiaoCore

public enum LexiconWriterError: Error {
    case invalidCodeLength(String)
    case characterEncodingFailed(String)
}

// The CLI reports failures via `localizedDescription` — carry the payload.
extension LexiconWriterError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidCodeLength(let code):
            return "entry code \"\(code)\" is not \(LexiconFormat.codeLength) digits"
        case .characterEncodingFailed(let char):
            return "cannot encode character \"\(char)\" as UTF-8"
        }
    }
}

public enum LexiconWriter {
    /// Binary layout:
    ///   magic (4) | version (u16) | entryCount (u32)
    ///   entries: [ codeBytes(6) | layer(u8) | ordinal(u32) | charLen(u8) | charUTF8(var) ]
    ///
    /// The code → entries index is rebuilt by LexiconReader at load time, so
    /// none is written.
    public static func serialize(entries: [CharEntry]) throws -> Data {
        var data = Data()
        data.append(contentsOf: LexiconFormat.magic)
        data.append(contentsOf: UInt16(LexiconFormat.version).littleEndianBytes)
        data.append(contentsOf: UInt32(entries.count).littleEndianBytes)

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
        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian) { Array($0) }
    }
}
