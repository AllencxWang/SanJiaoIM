import XCTest
@testable import SanJiaoIM

@MainActor
final class CandidatePanelTests: XCTestCase {
    /// v0.1 曾在 server 為 nil 時 fatalError，把整個輸入法帶崩；
    /// 正確行為是降級為「無候選窗」模式，show/hide 成為安全 no-op。
    func testNilServerDegradesToNoPanelInsteadOfCrashing() {
        let panel = CandidatePanel(server: nil)
        XCTAssertFalse(panel.isOperational,
                       "沒有 IMKServer 時面板必須標記為不可用")
        // 兩者都不得 crash。
        panel.show(entries: [])
        panel.hide()
    }
}
