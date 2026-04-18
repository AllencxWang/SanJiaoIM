import Foundation

public struct RawChardef: Equatable, Sendable {
    public let code: String
    public let character: String
}

public enum CinParserError: Error, Equatable {
    case invalidCodeLength(line: Int, code: String)
    case malformedLine(line: Int, content: String)
    case missingChardefSection
    case ioError(String)
}

public enum CinParser {
    public static func parse(fileURL: URL) throws -> [RawChardef] {
        let data: String
        do {
            data = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw CinParserError.ioError(error.localizedDescription)
        }
        return try parse(string: data)
    }

    public static func parse(string: String) throws -> [RawChardef] {
        var inChardef = false
        var results: [RawChardef] = []
        var seenSection = false
        // Only strip ASCII whitespace (spaces/tabs) and CR so that an ideographic
        // space (U+3000) used as an actual chardef value is preserved.
        let trimSet: Set<Character> = [" ", "\t", "\r"]
        for (idx, rawLine) in string.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            // Trim from both ends without collapsing interior whitespace.
            var line = Substring(rawLine)
            while let first = line.first, trimSet.contains(first) { line = line.dropFirst() }
            while let last = line.last, trimSet.contains(last) { line = line.dropLast() }
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line == "%chardef begin" { inChardef = true; seenSection = true; continue }
            if line == "%chardef end"   { inChardef = false; continue }
            if !inChardef { continue }

            // Split on the first ASCII space only; the value may itself contain whitespace characters.
            guard let spaceIdx = line.firstIndex(of: " ") else {
                throw CinParserError.malformedLine(line: idx + 1, content: String(line))
            }
            let code = String(line[..<spaceIdx])
            let char = String(line[line.index(after: spaceIdx)...])
            guard !char.isEmpty else {
                throw CinParserError.malformedLine(line: idx + 1, content: String(line))
            }
            guard code.count == 6, code.allSatisfy(\.isASCII), code.allSatisfy(\.isNumber) else {
                throw CinParserError.invalidCodeLength(line: idx + 1, code: code)
            }
            results.append(RawChardef(code: code, character: char))
        }
        guard seenSection else { throw CinParserError.missingChardefSection }
        return results
    }
}
