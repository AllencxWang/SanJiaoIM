import Cocoa
import SanJiaoCore

final class PreferencesWindow: NSWindowController {
    static let shared = PreferencesWindow()

    // windowDidLoad() only fires on the nib-loading path; for a programmatically
    // created window the UI must be built in the initializer.
    private convenience init() {
        self.init(window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
                                   styleMask: [.titled, .closable],
                                   backing: .buffered, defer: false))
        window?.title = "SanJiaoIM 偏好設定"
        let view = window!.contentView!
        let button = NSButton(title: "清除學習紀錄", target: self, action: #selector(clear))
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 20, y: 20, width: 200, height: 32)
        view.addSubview(button)
    }

    @objc private func clear() {
        guard let store = LexiconBootstrap.shared.store else { return }
        do {
            try store.reset()
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return
        }
        let alert = NSAlert()
        alert.messageText = "已清除學習紀錄"
        alert.runModal()
    }
}
