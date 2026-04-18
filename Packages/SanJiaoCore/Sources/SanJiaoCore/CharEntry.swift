import Foundation

public enum Layer: UInt8, Sendable, Comparable, Codable {
    case big5F = 0
    case big5LF = 1
    case big5Other = 2
    case cjkExt = 3

    public static func < (lhs: Layer, rhs: Layer) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct CharEntry: Equatable, Hashable, Sendable, Codable {
    public let code: String       // exactly 6 ASCII digits
    public let character: String  // one grapheme cluster
    public let layer: Layer
    public let ordinal: UInt32    // index in CIN source order

    public init(code: String, character: String, layer: Layer, ordinal: UInt32) {
        self.code = code
        self.character = character
        self.layer = layer
        self.ordinal = ordinal
    }
}
