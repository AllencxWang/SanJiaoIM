import Cocoa
import InputMethodKit
import SanJiaoCore

final class CandidatePanel: NSObject {
    private let candidates: IMKCandidates

    override init() {
        guard let server = AppDelegate.shared?.server else {
            fatalError("IMKServer not ready when CandidatePanel initialised")
        }
        self.candidates = IMKCandidates(server: server,
                                        panelType: kIMKSingleRowSteppingCandidatePanel)
        super.init()
    }

    func show(buffer: String, entries: [CharEntry]) {
        candidates.update()
        candidates.setCandidateData(entries.map { $0.character as NSString })
        candidates.show(kIMKLocateCandidatesBelowHint)
    }

    func hide() {
        candidates.hide()
    }
}
