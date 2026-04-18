import Foundation

public enum LexiconFormat {
    public static let magic: [UInt8] = Array("SJIM".utf8)
    public static let version: UInt16 = 1
    public static let codeLength = 6   // digits
}
