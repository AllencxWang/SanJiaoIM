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
        var cursor = 0
        func need(_ n: Int) throws {
            if cursor + n > data.count { throw LexiconReaderError.truncated }
        }

        try need(4)
        let magic = Array(data.subdata(in: cursor..<cursor + 4))
        guard magic == LexiconFormat.magic else { throw LexiconReaderError.badMagic }
        cursor += 4

        try need(2)
        let version = data.readLE(UInt16.self, at: cursor); cursor += 2
        guard version == LexiconFormat.version else {
            throw LexiconReaderError.unsupportedVersion(version)
        }

        try need(4)
        let count = Int(data.readLE(UInt32.self, at: cursor)); cursor += 4

        // Defence: a crafted header declaring billions of entries would
        // pre-allocate huge memory. Each entry is at least 12 bytes of fixed prefix
        // plus at least 1 byte of UTF-8 char data.
        let minBytesPerEntry = LexiconFormat.codeLength + 1 + 4 + 1 + 1
        let remaining = data.count - cursor
        guard count <= remaining / minBytesPerEntry else {
            throw LexiconReaderError.truncated
        }

        var entries: [CharEntry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            try need(LexiconFormat.codeLength + 1 + 4 + 1)
            let codeBytes = data.subdata(in: cursor..<cursor + LexiconFormat.codeLength)
            let code = String(bytes: codeBytes, encoding: .ascii) ?? ""
            cursor += LexiconFormat.codeLength

            let layer = Layer(rawValue: data[data.startIndex + cursor]) ?? .big5Other
            cursor += 1

            let ordinal = data.readLE(UInt32.self, at: cursor); cursor += 4

            let charLen = Int(data[data.startIndex + cursor]); cursor += 1
            try need(charLen)
            let charBytes = data.subdata(in: cursor..<cursor + charLen)
            guard let char = String(bytes: charBytes, encoding: .utf8) else {
                throw LexiconReaderError.invalidUTF8
            }
            cursor += charLen

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

extension Data {
    /// Reads a little-endian fixed-width integer at `offset` (absolute from `self.startIndex`
    /// when `self` is a standalone `Data`; this uses `subdata(in:)` to sidestep slice-index
    /// surprises).
    func readLE<T: FixedWidthInteger>(_ type: T.Type, at offset: Int) -> T {
        let size = MemoryLayout<T>.size
        let base = self.startIndex + offset
        let slice = self.subdata(in: base..<base + size)
        var value: T = 0
        for i in 0..<size {
            value |= T(slice[slice.startIndex + i]) << (8 * i)
        }
        return value
    }
}
