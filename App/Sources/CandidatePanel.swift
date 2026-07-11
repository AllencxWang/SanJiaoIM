import Cocoa
import InputMethodKit
import SanJiaoCore
import os

@MainActor
final class CandidatePanel {
    /// One candidates window per IME server — shared across input controllers.
    static let shared = CandidatePanel(server: AppDelegate.shared?.server)

    private let candidates: IMKCandidates?

    /// False means the server was unavailable at init; the panel degrades to
    /// a no-op so typing keeps working — an IME crash locks the user out of
    /// every text field system-wide, which is far worse than a missing panel.
    var isOperational: Bool { candidates != nil }

    init(server: IMKServer?) {
        if let server {
            self.candidates = IMKCandidates(server: server,
                                            panelType: kIMKSingleRowSteppingCandidatePanel)
        } else {
            self.candidates = nil
            Logger(subsystem: "com.sanjiaoim.app", category: "imkit")
                .fault("IMKServer not ready when CandidatePanel initialised; degrading to no-panel mode")
        }
    }

    /// Displays exactly one page of candidates; paging is owned by the Composer.
    func show(entries: [CharEntry]) {
        guard let candidates else { return }
        candidates.setCandidateData(entries.map { $0.character as NSString })
        candidates.update()
        candidates.show(kIMKLocateCandidatesBelowHint)
    }

    func hide() {
        candidates?.hide()
    }
}
