import XCTest
@testable import SanJiaoIM

final class SmokeTests: XCTestCase {
    func testBootstrapFindsLexiconBin() throws {
        // Bundle.main in a unit test context refers to the test bundle, so
        // prefer the app bundle by looking up a class that lives in the app.
        let appBundle = Bundle(for: AppDelegate.self)
        if let url = appBundle.url(forResource: "Lexicon", withExtension: "bin") {
            XCTAssertNotNil(url, "Lexicon.bin must be bundled in the app bundle")
            return
        }
        // Fallback: some hosting configurations may place resources in Bundle.main.
        let mainURL = Bundle.main.url(forResource: "Lexicon", withExtension: "bin")
        XCTAssertNotNil(mainURL, "Lexicon.bin must be bundled")
    }
}
