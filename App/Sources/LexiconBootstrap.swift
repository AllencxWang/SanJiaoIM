import Foundation
import SanJiaoCore
import os

enum BootstrapError: Error { case lexiconMissing }

final class LexiconBootstrap {
    nonisolated(unsafe) static let shared = LexiconBootstrap()
    let log = Logger(subsystem: "com.sanjiaoim.app", category: "core")

    private(set) var lexicon: Lexicon?
    private(set) var store: FrequencyStore?

    func loadOrThrow() throws {
        guard let url = Bundle.main.url(forResource: "Lexicon", withExtension: "bin") else {
            log.fault("Lexicon.bin missing from bundle")
            throw BootstrapError.lexiconMissing
        }
        self.lexicon = try Lexicon.load(url: url)

        let appSupport = try FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask, appropriateFor: nil,
                                                     create: true)
        let dir = appSupport.appendingPathComponent("SanJiaoIM", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.store = try FrequencyStore(fileURL: dir.appendingPathComponent("freq.json"))
    }
}
