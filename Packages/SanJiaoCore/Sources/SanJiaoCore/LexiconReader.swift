import Foundation

public enum LexiconReaderError: Error {
    case badMagic
    case unsupportedVersion(UInt16)
    case truncated
    case invalidUTF8
}

public struct LoadedLexicon: Sendable {
    public let entries: [CharEntry]
    /// code → indices into `entries` (preserves source order within group).
    public let index: [String: [Int]]

    public init(entries: [CharEntry], index: [String: [Int]]) {
        self.entries = entries
        self.index = index
    }
}

public enum LexiconReader {
    public static func load(url: URL) throws -> LoadedLexicon {
        let data = try Data(contentsOf: url)
        return try load(data: data)
    }

    public static func load(data: Data) throws -> LoadedLexicon {
        // Single pass over the raw bytes — no per-entry Data allocations.
        // withUnsafeBytes gives a zero-based view, which also makes slice
        // (non-zero startIndex) inputs safe by construction.
        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> LoadedLexicon in
            var cursor = 0
            func need(_ n: Int) throws {
                if cursor + n > raw.count { throw LexiconReaderError.truncated }
            }
            func readU8() -> UInt8 {
                defer { cursor += 1 }
                return raw[cursor]
            }
            func readLE<T: FixedWidthInteger>(_ type: T.Type) -> T {
                defer { cursor += MemoryLayout<T>.size }
                return T(littleEndian: raw.loadUnaligned(fromByteOffset: cursor, as: T.self))
            }
            func readString(_ n: Int, encoding: String.Encoding) -> String? {
                defer { cursor += n }
                return String(bytes: raw[cursor..<cursor + n], encoding: encoding)
            }

            try need(4)
            guard raw[0..<4].elementsEqual(LexiconFormat.magic) else {
                throw LexiconReaderError.badMagic
            }
            cursor += 4

            try need(2)
            let version = readLE(UInt16.self)
            guard version == LexiconFormat.version else {
                throw LexiconReaderError.unsupportedVersion(version)
            }

            try need(4)
            let count = Int(readLE(UInt32.self))

            // Defence: a crafted header declaring billions of entries would
            // pre-allocate huge memory. Each entry is at least 12 bytes of fixed
            // prefix plus at least 1 byte of UTF-8 char data.
            let minBytesPerEntry = LexiconFormat.codeLength + 1 + 4 + 1 + 1
            let remaining = raw.count - cursor
            guard count <= remaining / minBytesPerEntry else {
                throw LexiconReaderError.truncated
            }

            var entries: [CharEntry] = []
            entries.reserveCapacity(count)
            for _ in 0..<count {
                try need(LexiconFormat.codeLength + 1 + 4 + 1)
                let code = readString(LexiconFormat.codeLength, encoding: .ascii) ?? ""
                let layer = Layer(rawValue: readU8()) ?? .big5Other
                let ordinal = readLE(UInt32.self)
                let charLen = Int(readU8())
                try need(charLen)
                guard let char = readString(charLen, encoding: .utf8) else {
                    throw LexiconReaderError.invalidUTF8
                }
                entries.append(CharEntry(code: code, character: char, layer: layer, ordinal: ordinal))
            }

            var index: [String: [Int]] = [:]
            index.reserveCapacity(count)
            for (i, e) in entries.enumerated() {
                index[e.code, default: []].append(i)
            }
            return LoadedLexicon(entries: entries, index: index)
        }
    }
}
