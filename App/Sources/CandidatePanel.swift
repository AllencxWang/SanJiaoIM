import Cocoa
import InputMethodKit
import SanJiaoCore

@MainActor
final class CandidatePanel {
    /// One candidates window per IME server — shared across input controllers.
    static let shared = CandidatePanel()

    private let candidates: IMKCandidates

    private init() {
        guard let server = AppDelegate.shared?.server else {
            fatalError("IMKServer not ready when CandidatePanel initialised")
        }
        self.candidates = IMKCandidates(server: server,
                                        panelType: kIMKSingleRowSteppingCandidatePanel)
    }

    /// Displays exactly one page of candidates; paging is owned by the Composer.
    func show(entries: [CharEntry]) {
        candidates.setCandidateData(entries.map { $0.character as NSString })
        candidates.update()
        candidates.show(kIMKLocateCandidatesBelowHint)
    }

    func hide() {
        candidates.hide()
    }
}
