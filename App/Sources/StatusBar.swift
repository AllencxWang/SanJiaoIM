import Cocoa

enum StatusBar {
    nonisolated(unsafe) private static var item: NSStatusItem?

    static func showError(_ message: String) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "⚠︎"
        statusItem.button?.toolTip = "SanJiaoIM: \(message)"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: message, action: nil, keyEquivalent: ""))
        statusItem.menu = menu
        self.item = statusItem
    }
}
