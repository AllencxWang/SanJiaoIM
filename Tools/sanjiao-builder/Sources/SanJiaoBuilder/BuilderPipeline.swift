import Foundation
import SanJiaoCore

public enum BuilderPipeline {
    public static func assemble(from raws: [RawChardef]) -> [CharEntry] {
        raws.enumerated().map { i, r in
            CharEntry(code: r.code,
                      character: r.character,
                      layer: Big5Classifier.classify(r.character),
                      ordinal: UInt32(i))
        }
    }
}
