import Cocoa
import InputMethodKit

public class SanJiaoInputController: IMKInputController {
    public override func inputText(_ string: String?, client sender: Any!) -> Bool {
        return false
    }
}
