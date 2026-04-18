import Cocoa
import InputMethodKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let name = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String
            ?? "SanJiaoIM_1_Connection"
        let id = Bundle.main.bundleIdentifier ?? "com.sanjiaoim.app"
        self.server = IMKServer(name: name, bundleIdentifier: id)
    }
}
