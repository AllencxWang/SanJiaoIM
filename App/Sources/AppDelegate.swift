import Cocoa
import InputMethodKit
import os

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    nonisolated(unsafe) static private(set) var shared: AppDelegate?
    var server: IMKServer?
    let log = Logger(subsystem: "com.sanjiaoim.app", category: "imkit")

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try LexiconBootstrap.shared.loadOrThrow()
        } catch {
            log.fault("bootstrap failed: \(String(describing: error))")
            StatusBar.showError("Lexicon.bin 缺失或損毀，請重裝")
        }
        let name = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String
            ?? "SanJiaoIM_1_Connection"
        let id = Bundle.main.bundleIdentifier ?? "com.sanjiaoim.app"
        self.server = IMKServer(name: name, bundleIdentifier: id)
    }

    func applicationWillTerminate(_ notification: Notification) {
        try? LexiconBootstrap.shared.store?.flush()
    }
}
