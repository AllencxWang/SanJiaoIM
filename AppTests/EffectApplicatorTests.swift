import XCTest
import SanJiaoCore
@testable import SanJiaoIM

/// 驗證 Composer effect → IMKit 呼叫的映射。呼叫順序有語義：
/// commit 必須先 insertText 再清 marked text，否則使用者會看到
/// 已上屏的字後面還拖著殘留的編碼串。
@MainActor
final class EffectApplicatorTests: XCTestCase {

    enum Call: Equatable {
        case insertText(String)
        case setMarkedText(String, selectionAt: Int)
        case clearMarkedText
        case show([String])
        case hide
        case bump(code: String, character: String)
        case beep
    }

    final class Recorder {
        var calls: [Call] = []
    }

    struct FakeTextClient: TextClient {
        let recorder: Recorder
        func insertText(_ text: String) {
            recorder.calls.append(.insertText(text))
        }
        func setMarkedText(_ text: NSAttributedString, selectionRange: NSRange) {
            recorder.calls.append(.setMarkedText(text.string, selectionAt: selectionRange.location))
        }
        func clearMarkedText() {
            recorder.calls.append(.clearMarkedText)
        }
    }

    struct FakeCandidateUI: CandidateUI {
        let recorder: Recorder
        func show(entries: [CharEntry]) {
            recorder.calls.append(.show(entries.map(\.character)))
        }
        func hide() {
            recorder.calls.append(.hide)
        }
    }

    private var recorder = Recorder()

    private func makeApplicator() -> EffectApplicator {
        EffectApplicator(
            text: FakeTextClient(recorder: recorder),
            candidates: FakeCandidateUI(recorder: recorder),
            onCommit: { [recorder] in recorder.calls.append(.bump(code: $0.code, character: $0.character)) },
            beep: { [recorder] in recorder.calls.append(.beep) })
    }

    private let jiǎ = CharEntry(code: "102030", character: "甲", layer: .big5F, ordinal: 1)
    private let yǐ  = CharEntry(code: "102031", character: "乙", layer: .big5F, ordinal: 2)

    func testCommitInsertsBumpsClearsMarkedTextAndHidesPanel() {
        makeApplicator().apply(effects: [.commit(jiǎ)], state: .empty, visibleCandidates: [])
        XCTAssertEqual(recorder.calls, [
            .insertText("甲"),
            .bump(code: "102030", character: "甲"),
            .clearMarkedText,
            .hide,
        ])
    }

    func testComposingShowsBufferAsMarkedTextWithCursorAtEndAndHidesPanel() {
        makeApplicator().apply(effects: [], state: .composing(buffer: "123"), visibleCandidates: [])
        XCTAssertEqual(recorder.calls, [
            .setMarkedText("123", selectionAt: 3),
            .hide,
        ])
    }

    func testSelectingKeepsBufferVisibleAndShowsCurrentPage() {
        makeApplicator().apply(
            effects: [],
            state: .selecting(buffer: "12", candidates: [jiǎ, yǐ], page: 0),
            visibleCandidates: [jiǎ, yǐ])
        XCTAssertEqual(recorder.calls, [
            .setMarkedText("12", selectionAt: 2),
            .show(["甲", "乙"]),
        ])
    }

    func testBeepFiresBeforeMarkedTextUpdate() {
        makeApplicator().apply(effects: [.beep], state: .composing(buffer: "123456"), visibleCandidates: [])
        XCTAssertEqual(recorder.calls, [
            .beep,
            .setMarkedText("123456", selectionAt: 6),
            .hide,
        ])
    }

    func testPassthroughEmitsNoClientCalls() {
        // passthrough 由 handle() 回傳 false 讓系統遞送，applicator 不得動客戶端；
        // 只做狀態同步（清 marked text、關面板）。
        makeApplicator().apply(effects: [.passthrough("a")], state: .empty, visibleCandidates: [])
        XCTAssertEqual(recorder.calls, [
            .clearMarkedText,
            .hide,
        ])
    }
}
