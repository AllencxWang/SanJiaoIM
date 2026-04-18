# SanJiaoIM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a three-corner (三角編號法) input method for macOS as a signed-but-not-notarised open-source app, usable in all cocoa apps.

**Architecture:** Three layers — `SanJiaoCore` (pure Swift SPM package, no UI), `sanjiao-builder` (offline CLI that converts `3corner.cin` → `Lexicon.bin`), and `SanJiaoIM.app` (IMKit bundle that wires Composer/Lexicon into macOS). Core is TDD-driven; the IMKit shell is smoke-tested only.

**Tech Stack:** Swift 6, InputMethodKit, Swift Package Manager, XCTest, GitHub Actions on `macos-latest`.

**Spec reference:** `docs/superpowers/specs/2026-04-18-sanjiaoim-design.md`

---

## Phase structure

- **Phase A (Tasks 1-12)** — SanJiaoCore + sanjiao-builder. Produces a working lookup library and a CLI. End-to-end testable without IMKit.
- **Phase B (Tasks 13-20)** — SanJiaoIM.app IMKit bundle. Wires Phase A into a real input method.
- **Phase C (Tasks 21-24)** — Release artefacts (CI, install script, manual test checklist, README, v0.1.0).

Each task leaves the repo in a green state. Commit after every task.

---

## File structure (locked)

```
tri-corner/
├── SanJiaoIM.xcodeproj
├── Packages/
│   └── SanJiaoCore/
│       ├── Package.swift
│       ├── Sources/SanJiaoCore/
│       │   ├── LexiconFormat.swift      # binary layout constants shared with builder
│       │   ├── LexiconReader.swift      # reads Lexicon.bin into memory
│       │   ├── Lexicon.swift            # public query API
│       │   ├── CharEntry.swift          # value type
│       │   ├── Composer.swift           # state machine
│       │   ├── ComposerState.swift      # state + event types
│       │   ├── FrequencyStore.swift     # persisted user stats
│       │   └── Ranker.swift             # candidate ordering
│       └── Tests/SanJiaoCoreTests/
│           ├── LexiconReaderTests.swift
│           ├── LexiconTests.swift
│           ├── ComposerTests.swift
│           ├── FrequencyStoreTests.swift
│           ├── RankerTests.swift
│           └── Fixtures/
│               └── mini.cin             # small hand-written CIN for tests
├── Tools/
│   └── sanjiao-builder/
│       ├── Package.swift
│       ├── Sources/SanJiaoBuilder/
│       │   ├── CinParser.swift
│       │   ├── Big5Classifier.swift
│       │   ├── LexiconWriter.swift
│       │   └── main.swift
│       └── Tests/SanJiaoBuilderTests/
│           ├── CinParserTests.swift
│           ├── Big5ClassifierTests.swift
│           └── LexiconRoundTripTests.swift
├── App/
│   ├── Info.plist
│   ├── SanJiaoIM.entitlements
│   ├── Sources/
│   │   ├── AppDelegate.swift
│   │   ├── SanJiaoInputController.swift
│   │   ├── CandidatePanel.swift
│   │   ├── PreferencesWindow.swift
│   │   └── LexiconBootstrap.swift       # loads Lexicon.bin from bundle
│   └── Resources/
│       ├── Assets.xcassets
│       └── Lexicon.bin                   # built artefact (gitignored)
├── Vendor/
│   ├── 3corner.cin                       # vendored copy, Public Domain
│   └── 3corner.cin.SOURCE                # URL + SHA pin
├── scripts/
│   ├── build-lexicon.sh
│   └── install-dev.sh
├── docs/
│   ├── superpowers/{specs,plans}/
│   ├── manual-test-checklist.md
│   └── architecture.md
├── .github/workflows/ci.yml
├── README.md
├── LICENSE
└── .gitignore
```

---

## Phase A: Core + Builder

### Task 1: Project skeleton + vendored CIN

**Files:**
- Create: `Packages/SanJiaoCore/Package.swift`
- Create: `Packages/SanJiaoCore/Sources/SanJiaoCore/Placeholder.swift`
- Create: `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/SmokeTests.swift`
- Create: `Tools/sanjiao-builder/Package.swift`
- Create: `Tools/sanjiao-builder/Sources/SanJiaoBuilder/main.swift`
- Create: `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/SmokeTests.swift`
- Create: `Vendor/3corner.cin` (downloaded)
- Create: `Vendor/3corner.cin.SOURCE`

- [ ] **Step 1: Create SanJiaoCore Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SanJiaoCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SanJiaoCore", targets: ["SanJiaoCore"]),
    ],
    targets: [
        .target(name: "SanJiaoCore"),
        .testTarget(name: "SanJiaoCoreTests", dependencies: ["SanJiaoCore"],
                    resources: [.copy("Fixtures")]),
    ]
)
```

- [ ] **Step 2: Add placeholder source so package compiles**

File `Packages/SanJiaoCore/Sources/SanJiaoCore/Placeholder.swift`:
```swift
public enum SanJiaoCore {
    public static let version = "0.1.0"
}
```

- [ ] **Step 3: Add smoke test**

File `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/SmokeTests.swift`:
```swift
import XCTest
@testable import SanJiaoCore

final class SmokeTests: XCTestCase {
    func testVersionIsPopulated() {
        XCTAssertFalse(SanJiaoCore.version.isEmpty)
    }
}
```

- [ ] **Step 4: Create Fixtures directory placeholder**

```bash
mkdir -p Packages/SanJiaoCore/Tests/SanJiaoCoreTests/Fixtures
touch Packages/SanJiaoCore/Tests/SanJiaoCoreTests/Fixtures/.gitkeep
```

- [ ] **Step 5: Verify SanJiaoCore builds and tests pass**

Run: `cd Packages/SanJiaoCore && swift test`
Expected: `Test Suite 'All tests' passed`

- [ ] **Step 6: Create sanjiao-builder Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "sanjiao-builder",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../Packages/SanJiaoCore")
    ],
    targets: [
        .executableTarget(name: "SanJiaoBuilder", dependencies: ["SanJiaoCore"]),
        .testTarget(name: "SanJiaoBuilderTests", dependencies: ["SanJiaoBuilder"]),
    ]
)
```

- [ ] **Step 7: Add minimal builder main**

File `Tools/sanjiao-builder/Sources/SanJiaoBuilder/main.swift`:
```swift
import Foundation

@main
struct SanJiaoBuilder {
    static func main() {
        print("sanjiao-builder 0.1.0 — placeholder")
    }
}
```

- [ ] **Step 8: Add smoke test for builder**

File `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/SmokeTests.swift`:
```swift
import XCTest

final class SmokeTests: XCTestCase {
    func testBuilderTargetCompiles() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 9: Verify builder builds and tests pass**

Run: `cd Tools/sanjiao-builder && swift test`
Expected: `Test Suite 'All tests' passed`

- [ ] **Step 10: Vendor 3corner.cin**

Run:
```bash
curl -sL https://raw.githubusercontent.com/chinese-opendesktop/cin-tables/master/3corner.cin \
  -o Vendor/3corner.cin
curl -sL https://api.github.com/repos/chinese-opendesktop/cin-tables/commits/master \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])" > /tmp/sha.txt
```

Then write `Vendor/3corner.cin.SOURCE`:
```
upstream: https://github.com/chinese-opendesktop/cin-tables
path: 3corner.cin
retrieved: 2026-04-18
commit: <sha from /tmp/sha.txt>
license: Public Domain (per file header)
```

- [ ] **Step 11: Verify CIN file is valid**

Run: `head -10 Vendor/3corner.cin && wc -l Vendor/3corner.cin`
Expected: first line `#三角編號輸入法`, line count ~33000.

- [ ] **Step 12: Commit**

```bash
git add Packages/ Tools/ Vendor/
git commit -m "feat: scaffold SanJiaoCore package, sanjiao-builder CLI, and vendor 3corner.cin"
```

---

### Task 2: CharEntry value type + LexiconFormat constants

**Files:**
- Create: `Packages/SanJiaoCore/Sources/SanJiaoCore/CharEntry.swift`
- Create: `Packages/SanJiaoCore/Sources/SanJiaoCore/LexiconFormat.swift`
- Create: `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/CharEntryTests.swift`

- [ ] **Step 1: Write failing CharEntry test**

File `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/CharEntryTests.swift`:
```swift
import XCTest
@testable import SanJiaoCore

final class CharEntryTests: XCTestCase {
    func testCharEntryEquality() {
        let a = CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 42)
        let b = CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 42)
        XCTAssertEqual(a, b)
    }

    func testLayerRawValueStable() {
        XCTAssertEqual(Layer.big5F.rawValue, 0)
        XCTAssertEqual(Layer.big5LF.rawValue, 1)
        XCTAssertEqual(Layer.big5Other.rawValue, 2)
        XCTAssertEqual(Layer.cjkExt.rawValue, 3)
    }
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `cd Packages/SanJiaoCore && swift test --filter CharEntryTests`
Expected: compile error `CharEntry` undefined.

- [ ] **Step 3: Create CharEntry**

File `Packages/SanJiaoCore/Sources/SanJiaoCore/CharEntry.swift`:
```swift
import Foundation

public enum Layer: UInt8, Sendable, Comparable, Codable {
    case big5F = 0
    case big5LF = 1
    case big5Other = 2
    case cjkExt = 3

    public static func < (lhs: Layer, rhs: Layer) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct CharEntry: Equatable, Hashable, Sendable, Codable {
    public let code: String       // exactly 6 ASCII digits
    public let character: String  // one grapheme cluster
    public let layer: Layer
    public let ordinal: UInt32    // index in CIN source order

    public init(code: String, character: String, layer: Layer, ordinal: UInt32) {
        self.code = code
        self.character = character
        self.layer = layer
        self.ordinal = ordinal
    }
}
```

- [ ] **Step 4: Add LexiconFormat constants**

File `Packages/SanJiaoCore/Sources/SanJiaoCore/LexiconFormat.swift`:
```swift
import Foundation

public enum LexiconFormat {
    public static let magic: [UInt8] = Array("SJIM".utf8)
    public static let version: UInt16 = 1
    public static let codeLength = 6   // digits
}
```

- [ ] **Step 5: Run CharEntry tests — expect PASS**

Run: `cd Packages/SanJiaoCore && swift test --filter CharEntryTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Packages/SanJiaoCore/
git commit -m "feat(core): add CharEntry value type and LexiconFormat constants"
```

---

### Task 3: CIN parser (builder)

**Files:**
- Create: `Tools/sanjiao-builder/Sources/SanJiaoBuilder/CinParser.swift`
- Create: `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/CinParserTests.swift`
- Create: `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/Fixtures/mini.cin`

- [ ] **Step 1: Create mini CIN fixture**

File `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/Fixtures/mini.cin`:
```
# mini test CIN
%ename Mini
%selkey 1234567890
%keyname begin
0 0
1 1
%keyname end
%chardef begin
100301 一
100302 丁
100302 七
999978 鬵
%chardef end
```

- [ ] **Step 2: Update builder Package.swift to expose fixtures**

Edit `Tools/sanjiao-builder/Package.swift` — replace `testTarget` line with:
```swift
.testTarget(name: "SanJiaoBuilderTests", dependencies: ["SanJiaoBuilder"],
            resources: [.copy("Fixtures")]),
```

- [ ] **Step 3: Write failing parser test**

File `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/CinParserTests.swift`:
```swift
import XCTest
@testable import SanJiaoBuilder

final class CinParserTests: XCTestCase {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "mini", withExtension: "cin",
                          subdirectory: "Fixtures")!
    }

    func testParsesAllChardefs() throws {
        let entries = try CinParser.parse(fileURL: fixtureURL())
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(entries[0].code, "100301")
        XCTAssertEqual(entries[0].character, "一")
        XCTAssertEqual(entries[3].character, "鬵")
    }

    func testPreservesSourceOrderForDuplicateCodes() throws {
        let entries = try CinParser.parse(fileURL: fixtureURL())
        let codes102 = entries.filter { $0.code == "100302" }
        XCTAssertEqual(codes102.map(\.character), ["丁", "七"])
    }

    func testRejectsInvalidCodeLength() {
        let bad = """
        %chardef begin
        12345 X
        %chardef end
        """
        XCTAssertThrowsError(try CinParser.parse(string: bad))
    }
}
```

- [ ] **Step 4: Run test — expect FAIL**

Run: `cd Tools/sanjiao-builder && swift test --filter CinParserTests`
Expected: compile error `CinParser` undefined.

- [ ] **Step 5: Implement CinParser**

File `Tools/sanjiao-builder/Sources/SanJiaoBuilder/CinParser.swift`:
```swift
import Foundation

public struct RawChardef: Equatable, Sendable {
    public let code: String
    public let character: String
}

public enum CinParserError: Error, Equatable {
    case invalidCodeLength(line: Int, code: String)
    case malformedLine(line: Int, content: String)
    case missingChardefSection
    case ioError(String)
}

public enum CinParser {
    public static func parse(fileURL: URL) throws -> [RawChardef] {
        let data: String
        do {
            data = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw CinParserError.ioError(error.localizedDescription)
        }
        return try parse(string: data)
    }

    public static func parse(string: String) throws -> [RawChardef] {
        var inChardef = false
        var results: [RawChardef] = []
        var seenSection = false
        for (idx, rawLine) in string.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line == "%chardef begin" { inChardef = true; seenSection = true; continue }
            if line == "%chardef end"   { inChardef = false; continue }
            if !inChardef { continue }

            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else {
                throw CinParserError.malformedLine(line: idx + 1, content: line)
            }
            let code = String(parts[0])
            let char = String(parts[1])
            guard code.count == 6, code.allSatisfy(\.isASCII), code.allSatisfy(\.isNumber) else {
                throw CinParserError.invalidCodeLength(line: idx + 1, code: code)
            }
            results.append(RawChardef(code: code, character: char))
        }
        guard seenSection else { throw CinParserError.missingChardefSection }
        return results
    }
}
```

- [ ] **Step 6: Run tests — expect PASS**

Run: `cd Tools/sanjiao-builder && swift test --filter CinParserTests`
Expected: PASS.

- [ ] **Step 7: Smoke-parse the real 3corner.cin**

Add one-off test:
```swift
func testParsesRealCin() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // SanJiaoBuilderTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // sanjiao-builder
        .deletingLastPathComponent() // Tools
    let cin = repoRoot.appendingPathComponent("Vendor/3corner.cin")
    let entries = try CinParser.parse(fileURL: cin)
    XCTAssertGreaterThan(entries.count, 30000)
    XCTAssertLessThan(entries.count, 35000)
}
```

Run: `cd Tools/sanjiao-builder && swift test --filter testParsesRealCin`
Expected: PASS, count in range.

- [ ] **Step 8: Commit**

```bash
git add Tools/sanjiao-builder/
git commit -m "feat(builder): CIN parser with fixture and real-file smoke test"
```

---

### Task 4: Big5 layer classifier

**Files:**
- Create: `Tools/sanjiao-builder/Sources/SanJiaoBuilder/Big5Classifier.swift`
- Create: `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/Big5ClassifierTests.swift`

- [ ] **Step 1: Write failing classifier test**

File `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/Big5ClassifierTests.swift`:
```swift
import XCTest
import SanJiaoCore
@testable import SanJiaoBuilder

final class Big5ClassifierTests: XCTestCase {
    func testCommonHanClassifiedAsBig5F() {
        XCTAssertEqual(Big5Classifier.classify("一"), .big5F)
        XCTAssertEqual(Big5Classifier.classify("中"), .big5F)
    }

    func testLessCommonHanClassifiedAsBig5LF() {
        // 龢 is a Big5 level-2 (less frequent) ideograph
        XCTAssertEqual(Big5Classifier.classify("龢"), .big5LF)
    }

    func testCjkExtensionCharacterClassifiedAsCjkExt() {
        // 𡯬 is U+21BEC, CJK Extension B
        XCTAssertEqual(Big5Classifier.classify("𡯬"), .cjkExt)
    }

    func testNonHanCharacterClassifiedAsOther() {
        XCTAssertEqual(Big5Classifier.classify("═"), .big5Other)
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `cd Tools/sanjiao-builder && swift test --filter Big5ClassifierTests`
Expected: compile error.

- [ ] **Step 3: Implement classifier**

File `Tools/sanjiao-builder/Sources/SanJiaoBuilder/Big5Classifier.swift`:
```swift
import Foundation
import SanJiaoCore

public enum Big5Classifier {
    /// Approximate Big5 tier classification based on Unicode scalar ranges.
    /// - Big5F: CJK Unified Ideographs common set (U+4E00..U+9FFF) that map to Big5 level-1.
    /// - Big5LF: remaining Big5 level-2 ideographs.
    /// - Big5Other: non-Han characters (punctuation, symbols).
    /// - CjkExt: SIP / supplementary planes (U+20000+).
    public static func classify(_ character: String) -> Layer {
        guard let scalar = character.unicodeScalars.first else { return .big5Other }
        let v = scalar.value

        // Supplementary plane → CJK Extension B/C/D/E/F/G.
        if v >= 0x20000 { return .cjkExt }

        // BMP Han region.
        if (0x4E00...0x9FFF).contains(v) {
            // Crude frequency split: level-1 Big5 covers the densely-used middle range.
            // Precise list would need a Big5 table; for v0.1 we use a heuristic range.
            if (0x4E00...0x9FA5).contains(v) { return isCommonHan(v) ? .big5F : .big5LF }
            return .big5LF
        }

        // Compatibility / radicals / extension A.
        if (0x3400...0x4DBF).contains(v) { return .cjkExt }
        if (0xF900...0xFAFF).contains(v) { return .big5LF }

        return .big5Other
    }

    /// Returns true for the ~5400 most common Han ideographs (Big5 level-1 approximation).
    /// Uses Unicode scalar intersection with the BIG5_LEVEL1 table.
    private static func isCommonHan(_ v: UInt32) -> Bool {
        Big5Level1.contains(v)
    }
}
```

- [ ] **Step 4: Generate Big5Level1 table**

Big5 level-1 ideographs are the 5401 common Hanzi. We derive them at build time from a reference list. For v0.1, embed a pre-computed list. Create a helper file:

File `Tools/sanjiao-builder/Sources/SanJiaoBuilder/Big5Level1.swift`:
```swift
import Foundation

/// Set of Unicode scalar values in Big5 level-1 (常用字).
/// Source: derived from Big5-UAO mapping; 5401 entries.
/// For v0.1 we intern the set as a sorted array and binary-search.
enum Big5Level1 {
    static func contains(_ v: UInt32) -> Bool {
        _table.withUnsafeBufferPointer { buf in
            var lo = 0, hi = buf.count - 1
            while lo <= hi {
                let m = (lo + hi) / 2
                if buf[m] == v { return true }
                if buf[m] < v { lo = m + 1 } else { hi = m - 1 }
            }
            return false
        }
    }

    /// Populated by `scripts/generate-big5-level1.sh` (one-off at dev time).
    /// For v0.1 bootstrapping we ship an embedded copy checked into the repo.
    static let _table: [UInt32] = Big5Level1Table.values
}
```

- [ ] **Step 5: Bootstrap the Big5 level-1 table**

Run this one-off helper:
```bash
python3 - <<'PY' > /tmp/big5_level1.swift
# Big5 level-1 occupies code points A440..C67E in the Big5 encoding.
# Convert via Apple's built-in Big5 text encoding and extract Han ideographs in BMP.
import codecs
codes = []
for b1 in range(0xA4, 0xC7):
    for b2 in list(range(0x40, 0x7F)) + list(range(0xA1, 0xFF)):
        try:
            ch = bytes([b1, b2]).decode("big5-hkscs")
        except UnicodeDecodeError:
            continue
        if len(ch) == 1:
            cp = ord(ch)
            if 0x4E00 <= cp <= 0x9FFF:
                codes.append(cp)
codes = sorted(set(codes))
print("// Auto-generated. Do not edit.")
print("enum Big5Level1Table {")
print("    static let values: [UInt32] = [")
for chunk in range(0, len(codes), 8):
    row = codes[chunk:chunk+8]
    print("        " + ", ".join(f"0x{c:04X}" for c in row) + ",")
print("    ]")
print("}")
PY

mv /tmp/big5_level1.swift Tools/sanjiao-builder/Sources/SanJiaoBuilder/Big5Level1Table.swift
```

- [ ] **Step 6: Run tests — expect PASS**

Run: `cd Tools/sanjiao-builder && swift test --filter Big5ClassifierTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Tools/sanjiao-builder/
git commit -m "feat(builder): Big5 level classifier with bootstrapped level-1 table"
```

---

### Task 5: Lexicon binary writer

**Files:**
- Create: `Tools/sanjiao-builder/Sources/SanJiaoBuilder/LexiconWriter.swift`
- Create: `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/LexiconWriterTests.swift`

- [ ] **Step 1: Write failing writer test**

File `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/LexiconWriterTests.swift`:
```swift
import XCTest
import SanJiaoCore
@testable import SanJiaoBuilder

final class LexiconWriterTests: XCTestCase {
    func testWritesHeaderMagicAndVersion() throws {
        let entries = [
            CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
            CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
        ]
        let data = try LexiconWriter.serialize(entries: entries)
        XCTAssertEqual(Array(data.prefix(4)), LexiconFormat.magic)
        let version = data.subdata(in: 4..<6).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
        XCTAssertEqual(version, LexiconFormat.version)
    }

    func testEmitsExpectedEntryCount() throws {
        let entries = [
            CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
        ]
        let data = try LexiconWriter.serialize(entries: entries)
        let count = data.subdata(in: 6..<10).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        XCTAssertEqual(count, 1)
    }

    func testRejectsNonSixDigitCode() {
        let bad = [CharEntry(code: "123", character: "X", layer: .big5F, ordinal: 0)]
        XCTAssertThrowsError(try LexiconWriter.serialize(entries: bad))
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `cd Tools/sanjiao-builder && swift test --filter LexiconWriterTests`
Expected: compile error.

- [ ] **Step 3: Implement LexiconWriter**

File `Tools/sanjiao-builder/Sources/SanJiaoBuilder/LexiconWriter.swift`:
```swift
import Foundation
import SanJiaoCore

public enum LexiconWriterError: Error {
    case invalidCodeLength(String)
    case characterEncodingFailed(String)
}

public enum LexiconWriter {
    /// Binary layout:
    ///   magic (4) | version (u16) | entryCount (u32)
    ///   entries: [ codeBytes(6) | layer(u8) | ordinal(u32) | charLen(u8) | charUTF8(var) ]
    ///   index: [ codeBytes(6) | firstEntryIndex(u32) | entryCount(u16) ]  sorted by code
    ///   indexCount (u32) at EOF
    public static func serialize(entries: [CharEntry]) throws -> Data {
        var data = Data()
        data.append(contentsOf: LexiconFormat.magic)
        data.append(UInt16(LexiconFormat.version).littleEndianBytes)
        data.append(UInt32(entries.count).littleEndianBytes)

        // Group entries by code (preserve input order within a group).
        var grouped: [(code: String, indices: [Int])] = []
        var firstByCode: [String: Int] = [:]
        for (i, e) in entries.enumerated() {
            if firstByCode[e.code] == nil {
                firstByCode[e.code] = grouped.count
                grouped.append((e.code, [i]))
            } else {
                grouped[firstByCode[e.code]!].indices.append(i)
            }
        }

        // Write entries in original order (so ordinals match file position).
        for entry in entries {
            guard entry.code.count == LexiconFormat.codeLength else {
                throw LexiconWriterError.invalidCodeLength(entry.code)
            }
            data.append(contentsOf: Array(entry.code.utf8))
            data.append(entry.layer.rawValue)
            data.append(entry.ordinal.littleEndianBytes)
            guard let utf8 = entry.character.data(using: .utf8), utf8.count < 256 else {
                throw LexiconWriterError.characterEncodingFailed(entry.character)
            }
            data.append(UInt8(utf8.count))
            data.append(utf8)
        }

        // Sorted index.
        let sorted = grouped.sorted { $0.code < $1.code }
        for (code, indices) in sorted {
            data.append(contentsOf: Array(code.utf8))
            data.append(UInt32(indices.first!).littleEndianBytes)
            data.append(UInt16(indices.count).littleEndianBytes)
        }
        data.append(UInt32(sorted.count).littleEndianBytes)
        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian) { Array($0) }
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `cd Tools/sanjiao-builder && swift test --filter LexiconWriterTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Tools/sanjiao-builder/
git commit -m "feat(builder): LexiconWriter with versioned binary layout"
```

---

### Task 6: LexiconReader + round-trip test

**Files:**
- Create: `Packages/SanJiaoCore/Sources/SanJiaoCore/LexiconReader.swift`
- Create: `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/LexiconReaderTests.swift`
- Create: `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/LexiconRoundTripTests.swift`

- [ ] **Step 1: Write failing reader test**

File `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/LexiconReaderTests.swift`:
```swift
import XCTest
@testable import SanJiaoCore

final class LexiconReaderTests: XCTestCase {
    func testRejectsBadMagic() {
        var bad = Data("XXXX".utf8)
        bad.append(UInt16(1).littleEndianBytes)
        bad.append(UInt32(0).littleEndianBytes)
        XCTAssertThrowsError(try LexiconReader.load(data: bad))
    }

    func testRejectsFutureVersion() {
        var d = Data(LexiconFormat.magic)
        d.append(UInt16(999).littleEndianBytes)
        d.append(UInt32(0).littleEndianBytes)
        XCTAssertThrowsError(try LexiconReader.load(data: d))
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian) { Array($0) }
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `cd Packages/SanJiaoCore && swift test --filter LexiconReaderTests`
Expected: compile error.

- [ ] **Step 3: Implement LexiconReader**

File `Packages/SanJiaoCore/Sources/SanJiaoCore/LexiconReader.swift`:
```swift
import Foundation

public enum LexiconReaderError: Error {
    case badMagic
    case unsupportedVersion(UInt16)
    case truncated
    case invalidUTF8
}

public struct LoadedLexicon: Sendable {
    public let entries: [CharEntry]
    /// code → range of indices into `entries` (preserves source order within group).
    public let index: [String: [Int]]
}

public enum LexiconReader {
    public static func load(url: URL) throws -> LoadedLexicon {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try load(data: data)
    }

    public static func load(data: Data) throws -> LoadedLexicon {
        var cursor = 0
        func need(_ n: Int) throws { if cursor + n > data.count { throw LexiconReaderError.truncated } }
        try need(4)
        let magic = Array(data[cursor..<cursor+4])
        guard magic == LexiconFormat.magic else { throw LexiconReaderError.badMagic }
        cursor += 4
        try need(2)
        let version = data.readLE(UInt16.self, at: cursor); cursor += 2
        guard version == LexiconFormat.version else { throw LexiconReaderError.unsupportedVersion(version) }
        try need(4)
        let count = Int(data.readLE(UInt32.self, at: cursor)); cursor += 4

        var entries: [CharEntry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            try need(LexiconFormat.codeLength + 1 + 4 + 1)
            let code = String(bytes: data[cursor..<cursor+LexiconFormat.codeLength], encoding: .ascii) ?? ""
            cursor += LexiconFormat.codeLength
            let layer = Layer(rawValue: data[cursor]) ?? .big5Other
            cursor += 1
            let ordinal = data.readLE(UInt32.self, at: cursor); cursor += 4
            let charLen = Int(data[cursor]); cursor += 1
            try need(charLen)
            guard let char = String(bytes: data[cursor..<cursor+charLen], encoding: .utf8) else {
                throw LexiconReaderError.invalidUTF8
            }
            cursor += charLen
            entries.append(CharEntry(code: code, character: char, layer: layer, ordinal: ordinal))
        }

        var index: [String: [Int]] = [:]
        index.reserveCapacity(count)
        for (i, e) in entries.enumerated() {
            index[e.code, default: []].append(i)
        }
        return LoadedLexicon(entries: entries, index: index)
    }
}

extension Data {
    func readLE<T: FixedWidthInteger>(_ type: T.Type, at offset: Int) -> T {
        withUnsafeBytes { buf in
            var value: T = 0
            withUnsafeMutableBytes(of: &value) { dest in
                dest.copyBytes(from: UnsafeRawBufferPointer(rebasing: buf[offset..<offset+MemoryLayout<T>.size]))
            }
            return T(littleEndian: value)
        }
    }
}
```

- [ ] **Step 4: Run reader tests — expect PASS**

Run: `cd Packages/SanJiaoCore && swift test --filter LexiconReaderTests`
Expected: PASS.

- [ ] **Step 5: Write round-trip test in builder**

File `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/LexiconRoundTripTests.swift`:
```swift
import XCTest
import SanJiaoCore
@testable import SanJiaoBuilder

final class LexiconRoundTripTests: XCTestCase {
    func testWriterOutputIsReadableByReader() throws {
        let original = [
            CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
            CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
            CharEntry(code: "100302", character: "七", layer: .big5F, ordinal: 2),
            CharEntry(code: "999978", character: "鬵", layer: .big5LF, ordinal: 3),
        ]
        let bin = try LexiconWriter.serialize(entries: original)
        let loaded = try LexiconReader.load(data: bin)
        XCTAssertEqual(loaded.entries, original)
        XCTAssertEqual(loaded.index["100302"], [1, 2])
    }
}
```

- [ ] **Step 6: Run round-trip — expect PASS**

Run: `cd Tools/sanjiao-builder && swift test --filter LexiconRoundTripTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Packages/SanJiaoCore/ Tools/sanjiao-builder/
git commit -m "feat(core): LexiconReader with builder round-trip test"
```

---

### Task 7: Builder main (CIN → Lexicon.bin end-to-end)

**Files:**
- Modify: `Tools/sanjiao-builder/Sources/SanJiaoBuilder/main.swift`
- Create: `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/EndToEndTests.swift`

- [ ] **Step 1: Write failing end-to-end test**

File `Tools/sanjiao-builder/Tests/SanJiaoBuilderTests/EndToEndTests.swift`:
```swift
import XCTest
import SanJiaoCore
@testable import SanJiaoBuilder

final class EndToEndTests: XCTestCase {
    func testBuildProducesLoadableBin() throws {
        let cin = """
        %chardef begin
        100301 一
        100302 丁
        999978 鬵
        %chardef end
        """
        let raws = try CinParser.parse(string: cin)
        let entries = BuilderPipeline.assemble(from: raws)
        XCTAssertEqual(entries.count, 3)
        let bin = try LexiconWriter.serialize(entries: entries)
        let loaded = try LexiconReader.load(data: bin)
        XCTAssertEqual(loaded.entries.map(\.character), ["一", "丁", "鬵"])
        XCTAssertTrue(loaded.entries.allSatisfy { $0.ordinal < UInt32(entries.count) })
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `cd Tools/sanjiao-builder && swift test --filter EndToEndTests`
Expected: compile error `BuilderPipeline` undefined.

- [ ] **Step 3: Add pipeline + main**

File `Tools/sanjiao-builder/Sources/SanJiaoBuilder/BuilderPipeline.swift`:
```swift
import Foundation
import SanJiaoCore

public enum BuilderPipeline {
    public static func assemble(from raws: [RawChardef]) -> [CharEntry] {
        raws.enumerated().map { i, r in
            CharEntry(code: r.code,
                      character: r.character,
                      layer: Big5Classifier.classify(r.character),
                      ordinal: UInt32(i))
        }
    }
}
```

Replace `Tools/sanjiao-builder/Sources/SanJiaoBuilder/main.swift`:
```swift
import Foundation
import SanJiaoCore

@main
struct SanJiaoBuilder {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3 else {
            FileHandle.standardError.write(Data("usage: sanjiao-builder <input.cin> <output.bin>\n".utf8))
            exit(2)
        }
        let input = URL(fileURLWithPath: args[1])
        let output = URL(fileURLWithPath: args[2])
        let raws = try CinParser.parse(fileURL: input)
        let entries = BuilderPipeline.assemble(from: raws)
        let bin = try LexiconWriter.serialize(entries: entries)
        try bin.write(to: output)
        print("wrote \(entries.count) entries → \(output.path)")
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `cd Tools/sanjiao-builder && swift test`
Expected: all PASS.

- [ ] **Step 5: Build the real Lexicon.bin**

```bash
mkdir -p App/Resources
cd Tools/sanjiao-builder
swift run sanjiao-builder ../../Vendor/3corner.cin ../../App/Resources/Lexicon.bin
```

Expected output: `wrote <~32900> entries → …/App/Resources/Lexicon.bin`.

- [ ] **Step 6: Verify the file size**

Run: `ls -lh App/Resources/Lexicon.bin`
Expected: size between 400 KB and 1 MB.

- [ ] **Step 7: Commit (note Lexicon.bin is gitignored)**

```bash
git add Tools/sanjiao-builder/
git commit -m "feat(builder): end-to-end pipeline produces Lexicon.bin from 3corner.cin"
```

---

### Task 8: Lexicon public query API

**Files:**
- Create: `Packages/SanJiaoCore/Sources/SanJiaoCore/Lexicon.swift`
- Create: `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/LexiconTests.swift`

- [ ] **Step 1: Write failing Lexicon API tests**

File `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/LexiconTests.swift`:
```swift
import XCTest
@testable import SanJiaoCore

final class LexiconTests: XCTestCase {
    private func makeLexicon() -> Lexicon {
        Lexicon(loaded: LoadedLexicon(
            entries: [
                CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
                CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
                CharEntry(code: "100302", character: "七", layer: .big5F, ordinal: 2),
                CharEntry(code: "100302", character: "𡯬", layer: .cjkExt, ordinal: 3),
            ],
            index: ["100301": [0], "100302": [1, 2, 3]]
        ))
    }

    func testExactLookup() {
        let l = makeLexicon()
        let hits = l.exact(code: "100302")
        XCTAssertEqual(hits.map(\.character), ["丁", "七", "𡯬"])
    }

    func testPrefixLookupExpandsMissingDigits() {
        let l = makeLexicon()
        let hits = l.prefix(code: "1003")
        XCTAssertEqual(Set(hits.map(\.character)), Set(["一", "丁", "七", "𡯬"]))
    }

    func testExactReturnsEmptyWhenUnknown() {
        let l = makeLexicon()
        XCTAssertTrue(l.exact(code: "000000").isEmpty)
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `cd Packages/SanJiaoCore && swift test --filter LexiconTests`
Expected: compile error `Lexicon` undefined.

- [ ] **Step 3: Implement Lexicon**

File `Packages/SanJiaoCore/Sources/SanJiaoCore/Lexicon.swift`:
```swift
import Foundation

public struct Lexicon: Sendable {
    private let loaded: LoadedLexicon
    private let sortedCodes: [String]

    public init(loaded: LoadedLexicon) {
        self.loaded = loaded
        self.sortedCodes = loaded.index.keys.sorted()
    }

    public static func load(url: URL) throws -> Lexicon {
        Lexicon(loaded: try LexiconReader.load(url: url))
    }

    public var count: Int { loaded.entries.count }

    /// Exact 6-digit code lookup.
    public func exact(code: String) -> [CharEntry] {
        guard let indices = loaded.index[code] else { return [] }
        return indices.map { loaded.entries[$0] }
    }

    /// Prefix lookup — returns all entries whose code starts with `prefix`.
    public func prefix(code prefix: String) -> [CharEntry] {
        guard !prefix.isEmpty else { return [] }
        var lo = lowerBound(sortedCodes, target: prefix)
        var result: [CharEntry] = []
        while lo < sortedCodes.count, sortedCodes[lo].hasPrefix(prefix) {
            if let indices = loaded.index[sortedCodes[lo]] {
                result.append(contentsOf: indices.map { loaded.entries[$0] })
            }
            lo += 1
        }
        return result
    }

    private func lowerBound(_ a: [String], target: String) -> Int {
        var lo = 0, hi = a.count
        while lo < hi {
            let m = (lo + hi) / 2
            if a[m] < target { lo = m + 1 } else { hi = m }
        }
        return lo
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `cd Packages/SanJiaoCore && swift test --filter LexiconTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/SanJiaoCore/
git commit -m "feat(core): Lexicon public API with exact and prefix lookup"
```

---

### Task 9: Composer state machine

**Files:**
- Create: `Packages/SanJiaoCore/Sources/SanJiaoCore/ComposerState.swift`
- Create: `Packages/SanJiaoCore/Sources/SanJiaoCore/Composer.swift`
- Create: `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/ComposerTests.swift`

- [ ] **Step 1: Add state + event types**

File `Packages/SanJiaoCore/Sources/SanJiaoCore/ComposerState.swift`:
```swift
import Foundation

public enum ComposerState: Equatable, Sendable {
    case empty
    case composing(buffer: String)
    case selecting(buffer: String, candidates: [CharEntry], page: Int)
}

public enum ComposerEvent: Equatable, Sendable {
    case digit(Character)        // 0-9
    case space
    case enter
    case backspace
    case escape
    case pick(Int)               // 1-based candidate index within visible page
    case nextPage
    case prevPage
    case passthrough(Character)  // a-z A-Z etc.
}

public enum ComposerEffect: Equatable, Sendable {
    case commit(String)          // emit text to client
    case passthrough(Character)  // forward key to system
    case beep                    // buffer full / invalid pick
}
```

- [ ] **Step 2: Write failing Composer test**

File `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/ComposerTests.swift`:
```swift
import XCTest
@testable import SanJiaoCore

final class ComposerTests: XCTestCase {
    private func lex() -> Lexicon {
        Lexicon(loaded: LoadedLexicon(
            entries: [
                CharEntry(code: "100301", character: "一", layer: .big5F, ordinal: 0),
                CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
            ],
            index: ["100301": [0], "100302": [1]]
        ))
    }

    func testDigitFromEmptyMovesToComposing() {
        var c = Composer(lexicon: lex())
        let fx = c.handle(.digit("1"))
        XCTAssertEqual(c.state, .composing(buffer: "1"))
        XCTAssertEqual(fx, [])
    }

    func testSixthDigitAutoTransitionsToSelecting() {
        var c = Composer(lexicon: lex())
        _ = c.handle(.digit("1")); _ = c.handle(.digit("0")); _ = c.handle(.digit("0"))
        _ = c.handle(.digit("3")); _ = c.handle(.digit("0")); _ = c.handle(.digit("1"))
        guard case .selecting(let buf, let cands, _) = c.state else {
            return XCTFail("expected selecting, got \(c.state)")
        }
        XCTAssertEqual(buf, "100301")
        XCTAssertEqual(cands.first?.character, "一")
    }

    func testSpaceCommitsFirstCandidate() {
        var c = Composer(lexicon: lex())
        for ch in "100301" { _ = c.handle(.digit(ch)) }
        let fx = c.handle(.space)
        XCTAssertEqual(fx, [.commit("一")])
        XCTAssertEqual(c.state, .empty)
    }

    func testEnterPadsZerosAndCommits() {
        var c = Composer(lexicon: lex())
        _ = c.handle(.digit("1")); _ = c.handle(.digit("0")); _ = c.handle(.digit("0"))
        _ = c.handle(.digit("3"))
        _ = c.handle(.enter) // pads to 100300 ... no wait, enter pads to 100300
        // the rule: right-pad zeros → "100300" → no match in mini lexicon
        // but prefix "1003" matches → selecting with all entries beginning with 1003
        guard case .selecting(_, let cands, _) = c.state else {
            return XCTFail("expected selecting")
        }
        XCTAssertFalse(cands.isEmpty)
    }

    func testEscapeFromComposingReturnsToEmpty() {
        var c = Composer(lexicon: lex())
        _ = c.handle(.digit("1"))
        _ = c.handle(.escape)
        XCTAssertEqual(c.state, .empty)
    }

    func testBackspaceFromSelectingReturnsToComposing() {
        var c = Composer(lexicon: lex())
        for ch in "100301" { _ = c.handle(.digit(ch)) }
        _ = c.handle(.backspace)
        XCTAssertEqual(c.state, .composing(buffer: "10030"))
    }

    func testPassthroughFromEmpty() {
        var c = Composer(lexicon: lex())
        let fx = c.handle(.passthrough("a"))
        XCTAssertEqual(fx, [.passthrough("a")])
    }

    func testPassthroughFromComposingDropsBuffer() {
        var c = Composer(lexicon: lex())
        _ = c.handle(.digit("1"))
        let fx = c.handle(.passthrough("a"))
        XCTAssertEqual(fx, [.passthrough("a")])
        XCTAssertEqual(c.state, .empty)
    }

    func testPickInSelectingCommits() {
        var c = Composer(lexicon: lex())
        for ch in "100301" { _ = c.handle(.digit(ch)) }
        let fx = c.handle(.pick(1))
        XCTAssertEqual(fx, [.commit("一")])
        XCTAssertEqual(c.state, .empty)
    }
}
```

- [ ] **Step 3: Run — expect FAIL**

Run: `cd Packages/SanJiaoCore && swift test --filter ComposerTests`
Expected: compile error `Composer` undefined.

- [ ] **Step 4: Implement Composer**

File `Packages/SanJiaoCore/Sources/SanJiaoCore/Composer.swift`:
```swift
import Foundation

public struct Composer: Sendable {
    public private(set) var state: ComposerState = .empty
    private let lexicon: Lexicon
    private var ranker: Ranker?
    public let pageSize = 10

    public init(lexicon: Lexicon, ranker: Ranker? = nil) {
        self.lexicon = lexicon
        self.ranker = ranker
    }

    @discardableResult
    public mutating func handle(_ event: ComposerEvent) -> [ComposerEffect] {
        switch (state, event) {
        case (.empty, .digit(let d)):
            state = .composing(buffer: String(d))
            return []

        case (.empty, .passthrough(let c)):
            return [.passthrough(c)]

        case (.empty, _):
            return []

        case (.composing(let buf), .digit(let d)):
            let next = buf + String(d)
            if next.count == LexiconFormat.codeLength {
                return enterSelecting(buffer: next)
            }
            state = .composing(buffer: next)
            return []

        case (.composing(let buf), .space):
            return enterSelecting(buffer: buf)

        case (.composing(let buf), .enter):
            let padded = buf + String(repeating: "0", count: LexiconFormat.codeLength - buf.count)
            return enterSelecting(buffer: padded)

        case (.composing(let buf), .backspace):
            let next = String(buf.dropLast())
            state = next.isEmpty ? .empty : .composing(buffer: next)
            return []

        case (.composing, .escape):
            state = .empty
            return []

        case (.composing, .passthrough(let c)):
            state = .empty
            return [.passthrough(c)]

        case (.selecting(_, let cands, let page), .pick(let n)):
            let idx = page * pageSize + (n - 1)
            guard idx >= 0, idx < cands.count else { return [.beep] }
            let picked = cands[idx]
            state = .empty
            return [.commit(picked.character)]

        case (.selecting(_, let cands, let page), .space):
            let idx = page * pageSize
            guard idx < cands.count else { return [.beep] }
            state = .empty
            return [.commit(cands[idx].character)]

        case (.selecting(let buf, let cands, let page), .nextPage):
            let maxPage = max(0, (cands.count - 1) / pageSize)
            let p = min(page + 1, maxPage)
            state = .selecting(buffer: buf, candidates: cands, page: p)
            return []

        case (.selecting(let buf, let cands, let page), .prevPage):
            state = .selecting(buffer: buf, candidates: cands, page: max(page - 1, 0))
            return []

        case (.selecting(let buf, _, _), .backspace):
            let trimmed = String(buf.dropLast())
            state = trimmed.isEmpty ? .empty : .composing(buffer: trimmed)
            return []

        case (.selecting, .escape):
            state = .empty
            return []

        case (.selecting(_, let cands, let page), .passthrough(let c)):
            let idx = page * pageSize
            var out: [ComposerEffect] = []
            if idx < cands.count { out.append(.commit(cands[idx].character)) }
            out.append(.passthrough(c))
            state = .empty
            return out

        case (.selecting, .enter):
            return [] // no-op; require explicit pick

        case (.selecting, .digit):
            return [.beep] // in selecting mode digits should have been routed as .pick
        }
    }

    private mutating func enterSelecting(buffer: String) -> [ComposerEffect] {
        var cands: [CharEntry]
        if buffer.count == LexiconFormat.codeLength {
            cands = lexicon.exact(code: buffer)
            if cands.isEmpty { cands = lexicon.prefix(code: String(buffer.prefix(while: { $0 != "0" }))) }
        } else {
            cands = lexicon.prefix(code: buffer)
        }
        if let r = ranker { cands = r.rank(cands, buffer: buffer) }
        state = .selecting(buffer: buffer, candidates: cands, page: 0)
        return []
    }
}
```

- [ ] **Step 5: Run — expect PASS**

Run: `cd Packages/SanJiaoCore && swift test --filter ComposerTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Packages/SanJiaoCore/
git commit -m "feat(core): Composer state machine with full event handling"
```

---

### Task 10: FrequencyStore

**Files:**
- Create: `Packages/SanJiaoCore/Sources/SanJiaoCore/FrequencyStore.swift`
- Create: `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/FrequencyStoreTests.swift`

- [ ] **Step 1: Write failing FrequencyStore tests**

File `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/FrequencyStoreTests.swift`:
```swift
import XCTest
@testable import SanJiaoCore

final class FrequencyStoreTests: XCTestCase {
    private func tmpFile() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        return dir.appendingPathComponent("freq-\(UUID().uuidString).json")
    }

    func testBumpIncrementsCount() throws {
        let url = tmpFile()
        var store = try FrequencyStore(fileURL: url, flushEvery: 1)
        store.bump(code: "100301", character: "一")
        store.bump(code: "100301", character: "一")
        XCTAssertEqual(store.count(code: "100301", character: "一"), 2)
    }

    func testFlushAndReload() throws {
        let url = tmpFile()
        do {
            var store = try FrequencyStore(fileURL: url, flushEvery: 1)
            store.bump(code: "100301", character: "一")
            try store.flush()
        }
        let reloaded = try FrequencyStore(fileURL: url, flushEvery: 1)
        XCTAssertEqual(reloaded.count(code: "100301", character: "一"), 1)
    }

    func testCorruptFileReseedsAndBackups() throws {
        let url = tmpFile()
        try Data("not json".utf8).write(to: url)
        let store = try FrequencyStore(fileURL: url, flushEvery: 1)
        XCTAssertEqual(store.count(code: "x", character: "y"), 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path + ".corrupt.bak"))
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `cd Packages/SanJiaoCore && swift test --filter FrequencyStoreTests`
Expected: compile error.

- [ ] **Step 3: Implement FrequencyStore**

File `Packages/SanJiaoCore/Sources/SanJiaoCore/FrequencyStore.swift`:
```swift
import Foundation

public struct FrequencyStore: Sendable {
    public struct Stats: Codable, Equatable, Sendable {
        public var count: UInt32
        public var lastUsed: Date
    }

    private var stats: [String: Stats]
    private let fileURL: URL
    private let flushEvery: Int
    private var pendingBumps: Int = 0

    public init(fileURL: URL, flushEvery: Int = 20) throws {
        self.fileURL = fileURL
        self.flushEvery = flushEvery
        self.stats = Self.loadOrReset(url: fileURL)
    }

    private static func loadOrReset(url: URL) -> [String: Stats] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: Stats].self, from: data)
        } catch {
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("corrupt.bak"))
            return [:]
        }
    }

    private static func key(code: String, character: String) -> String {
        "\(code)|\(character)"
    }

    public func count(code: String, character: String) -> UInt32 {
        stats[Self.key(code: code, character: character)]?.count ?? 0
    }

    public func lastUsed(code: String, character: String) -> Date? {
        stats[Self.key(code: code, character: character)]?.lastUsed
    }

    public mutating func bump(code: String, character: String, now: Date = .now) {
        let k = Self.key(code: code, character: character)
        var s = stats[k] ?? Stats(count: 0, lastUsed: now)
        s.count &+= 1
        s.lastUsed = now
        stats[k] = s
        pendingBumps += 1
        if pendingBumps >= flushEvery {
            try? flush()
        }
    }

    public mutating func flush() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(stats)
        try data.write(to: fileURL, options: .atomic)
        pendingBumps = 0
    }

    public mutating func reset() {
        stats.removeAll()
        try? flush()
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `cd Packages/SanJiaoCore && swift test --filter FrequencyStoreTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/SanJiaoCore/
git commit -m "feat(core): FrequencyStore with JSON persistence and corruption recovery"
```

---

### Task 11: Ranker

**Files:**
- Create: `Packages/SanJiaoCore/Sources/SanJiaoCore/Ranker.swift`
- Create: `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/RankerTests.swift`

- [ ] **Step 1: Write failing Ranker tests**

File `Packages/SanJiaoCore/Tests/SanJiaoCoreTests/RankerTests.swift`:
```swift
import XCTest
@testable import SanJiaoCore

final class RankerTests: XCTestCase {
    private func entries() -> [CharEntry] {
        [
            CharEntry(code: "100302", character: "丁", layer: .big5F, ordinal: 1),
            CharEntry(code: "100302", character: "七", layer: .big5F, ordinal: 2),
            CharEntry(code: "100302", character: "𡯬", layer: .cjkExt, ordinal: 3),
        ]
    }

    func testLayerOrderingWithoutFrequency() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rank-\(UUID().uuidString).json")
        let store = try FrequencyStore(fileURL: url)
        let ranker = Ranker(frequencies: store)
        let ranked = ranker.rank(entries(), buffer: "100302")
        XCTAssertEqual(ranked.last?.character, "𡯬") // CJK ext sinks
        XCTAssertEqual(ranked.first?.character, "丁") // lowest ordinal first
    }

    func testFrequencyPromotesCandidate() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rank-\(UUID().uuidString).json")
        var store = try FrequencyStore(fileURL: url)
        for _ in 0..<10 { store.bump(code: "100302", character: "七") }
        let ranker = Ranker(frequencies: store)
        let ranked = ranker.rank(entries(), buffer: "100302")
        XCTAssertEqual(ranked.first?.character, "七")
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `cd Packages/SanJiaoCore && swift test --filter RankerTests`
Expected: compile error `Ranker`.

- [ ] **Step 3: Implement Ranker**

File `Packages/SanJiaoCore/Sources/SanJiaoCore/Ranker.swift`:
```swift
import Foundation

public struct Ranker: Sendable {
    private let frequencies: FrequencyStore
    private let alpha: Double
    private let beta: Double

    public init(frequencies: FrequencyStore, alpha: Double = 5.0, beta: Double = 0.1) {
        self.frequencies = frequencies
        self.alpha = alpha
        self.beta = beta
    }

    public func rank(_ entries: [CharEntry], buffer: String, now: Date = .now) -> [CharEntry] {
        entries.enumerated().map { ($0.offset, $0.element, score($0.element, now: now)) }
            .sorted { a, b in a.2 < b.2 || (a.2 == b.2 && a.0 < b.0) }
            .map { $0.1 }
    }

    private func score(_ e: CharEntry, now: Date) -> Double {
        var s = Double(e.layer.rawValue) * 100_000 + Double(e.ordinal)
        let freq = frequencies.count(code: e.code, character: e.character)
        s -= alpha * log(1.0 + Double(freq))
        if let last = frequencies.lastUsed(code: e.code, character: e.character) {
            let days = now.timeIntervalSince(last) / 86_400.0
            s += beta * max(0, days)
        }
        return s
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `cd Packages/SanJiaoCore && swift test --filter RankerTests`
Expected: PASS.

- [ ] **Step 5: Full core test suite sanity**

Run: `cd Packages/SanJiaoCore && swift test`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add Packages/SanJiaoCore/
git commit -m "feat(core): Ranker with frequency + layer + recency scoring"
```

---

### Task 12: Build script

**Files:**
- Create: `scripts/build-lexicon.sh`

- [ ] **Step 1: Write script**

File `scripts/build-lexicon.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INPUT="$ROOT/Vendor/3corner.cin"
OUTPUT="$ROOT/App/Resources/Lexicon.bin"

mkdir -p "$(dirname "$OUTPUT")"
cd "$ROOT/Tools/sanjiao-builder"
swift run -c release sanjiao-builder "$INPUT" "$OUTPUT"
ls -lh "$OUTPUT"
```

- [ ] **Step 2: Make executable and run**

```bash
chmod +x scripts/build-lexicon.sh
scripts/build-lexicon.sh
```

Expected: `wrote ~32900 entries → …/Lexicon.bin` and file listing.

- [ ] **Step 3: Commit**

```bash
git add scripts/build-lexicon.sh
git commit -m "chore: add build-lexicon.sh convenience wrapper"
```

---

## Phase B: IMKit App

### Task 13: Xcode project scaffolding

**Files:**
- Create: `SanJiaoIM.xcodeproj` (via Xcode GUI or `xcodegen`)
- Create: `App/Info.plist`
- Create: `App/SanJiaoIM.entitlements`
- Create: `App/Sources/AppDelegate.swift`
- Create: `App/Sources/SanJiaoInputController.swift` (stub)

Since Xcode project generation is painful in plain-text tooling, use `xcodegen`. Install if missing:

- [ ] **Step 1: Install xcodegen**

Run: `brew install xcodegen`
Expected: installation succeeds or reports already installed.

- [ ] **Step 2: Write `project.yml`**

File `project.yml`:
```yaml
name: SanJiaoIM
options:
  minimumXcodeGenVersion: 2.38.0
  deploymentTarget:
    macOS: "26.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    PRODUCT_BUNDLE_IDENTIFIER: com.sanjiaoim.app
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGN_STYLE: Manual
packages:
  SanJiaoCore:
    path: Packages/SanJiaoCore
targets:
  SanJiaoIM:
    type: application
    platform: macOS
    sources:
      - App/Sources
    resources:
      - App/Resources
    dependencies:
      - package: SanJiaoCore
    info:
      path: App/Info.plist
      properties:
        CFBundleDisplayName: SanJiaoIM
        LSBackgroundOnly: true
        LSUIElement: true
        InputMethodConnectionName: SanJiaoIM_1_Connection
        InputMethodServerControllerClass: SanJiaoIM.SanJiaoInputController
        tsInputMethodCharacterRepertoireKey:
          - zh-Hant
          - zh-Hans
    entitlements:
      path: App/SanJiaoIM.entitlements
      properties:
        com.apple.security.app-sandbox: false
```

- [ ] **Step 3: Generate Xcode project**

Run: `xcodegen generate`
Expected: `Created project at SanJiaoIM.xcodeproj`.

- [ ] **Step 4: Add AppDelegate and placeholder input controller**

File `App/Sources/AppDelegate.swift`:
```swift
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
```

File `App/Sources/SanJiaoInputController.swift`:
```swift
import Cocoa
import InputMethodKit

public class SanJiaoInputController: IMKInputController {
    public override func inputText(_ string: String?, client sender: Any!) -> Bool {
        return false
    }
}
```

- [ ] **Step 5: Verify build**

Run: `xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM -configuration Debug build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add project.yml App/ SanJiaoIM.xcodeproj/
git commit -m "build: scaffold SanJiaoIM Xcode project with xcodegen"
```

---

### Task 14: LexiconBootstrap + input controller wiring

**Files:**
- Create: `App/Sources/LexiconBootstrap.swift`
- Modify: `App/Sources/SanJiaoInputController.swift`
- Modify: `App/Sources/AppDelegate.swift`

- [ ] **Step 1: Write bootstrap**

File `App/Sources/LexiconBootstrap.swift`:
```swift
import Foundation
import SanJiaoCore
import os

enum BootstrapError: Error { case lexiconMissing }

final class LexiconBootstrap {
    static let shared = LexiconBootstrap()
    let log = Logger(subsystem: "com.sanjiaoim.app", category: "core")

    private(set) var lexicon: Lexicon?
    private(set) var store: FrequencyStore?

    func loadOrThrow() throws {
        guard let url = Bundle.main.url(forResource: "Lexicon", withExtension: "bin") else {
            log.fault("Lexicon.bin missing from bundle")
            throw BootstrapError.lexiconMissing
        }
        self.lexicon = try Lexicon.load(url: url)

        let appSupport = try FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask, appropriateFor: nil,
                                                     create: true)
        let dir = appSupport.appendingPathComponent("SanJiaoIM", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.store = try FrequencyStore(fileURL: dir.appendingPathComponent("freq.json"))
    }
}
```

- [ ] **Step 2: Wire bootstrap into AppDelegate**

Replace `App/Sources/AppDelegate.swift`:
```swift
import Cocoa
import InputMethodKit
import os

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var server: IMKServer?
    let log = Logger(subsystem: "com.sanjiaoim.app", category: "imkit")

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try LexiconBootstrap.shared.loadOrThrow()
        } catch {
            log.fault("bootstrap failed: \(String(describing: error))")
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
```

- [ ] **Step 3: Wire Composer into input controller**

Replace `App/Sources/SanJiaoInputController.swift`:
```swift
import Cocoa
import InputMethodKit
import SanJiaoCore
import os

public class SanJiaoInputController: IMKInputController {
    private let log = Logger(subsystem: "com.sanjiaoim.app", category: "imkit")
    private var composer: Composer?

    public override func activateServer(_ sender: Any!) {
        guard let lex = LexiconBootstrap.shared.lexicon,
              let store = LexiconBootstrap.shared.store else { return }
        let ranker = Ranker(frequencies: store)
        self.composer = Composer(lexicon: lex, ranker: ranker)
    }

    public override func deactivateServer(_ sender: Any!) {
        self.composer = nil
    }

    public override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown, var c = composer else { return false }
        let evt = translate(event)
        let effects = c.handle(evt)
        self.composer = c
        apply(effects: effects, client: sender, state: c.state)
        switch c.state {
        case .empty: return !effects.contains { if case .passthrough = $0 { return true } else { return false } }
        case .composing, .selecting: return true
        }
    }

    private func translate(_ event: NSEvent) -> ComposerEvent {
        let s = event.charactersIgnoringModifiers ?? ""
        guard let ch = s.first else { return .passthrough(" ") }
        switch ch {
        case "0"..."9":
            if case .selecting = composer?.state { return .pick(Int(String(ch))! == 0 ? 10 : Int(String(ch))!) }
            return .digit(ch)
        case " ":  return .space
        case "\r", "\n": return .enter
        case "\u{7F}", "\u{08}": return .backspace
        case "\u{1B}": return .escape
        case ",": return .prevPage
        case ".": return .nextPage
        default:  return .passthrough(ch)
        }
    }

    private func apply(effects: [ComposerEffect], client: Any!, state: ComposerState) {
        guard let client = client as? IMKTextInput else { return }
        for fx in effects {
            switch fx {
            case .commit(let text):
                client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
                if let code = currentCode(state: state), var store = LexiconBootstrap.shared.store {
                    store.bump(code: code, character: text)
                    LexiconBootstrap.shared.replaceStore(store)
                }
            case .passthrough:
                break // system receives keyDown naturally since we return false
            case .beep:
                NSSound.beep()
            }
        }
    }

    private func currentCode(state: ComposerState) -> String? {
        if case .selecting(let buf, _, _) = state { return buf }
        return nil
    }
}
```

- [ ] **Step 4: Add replaceStore helper**

Add to `App/Sources/LexiconBootstrap.swift` inside the class:
```swift
    func replaceStore(_ updated: FrequencyStore) {
        self.store = updated
    }
```

- [ ] **Step 5: Build**

Run: `xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add App/
git commit -m "feat(app): wire Composer + Lexicon + FrequencyStore into IMKInputController"
```

---

### Task 15: Candidate panel (IMKCandidates integration)

**Files:**
- Create: `App/Sources/CandidatePanel.swift`
- Modify: `App/Sources/SanJiaoInputController.swift`

- [ ] **Step 1: Expose the IMKServer from AppDelegate**

Modify `App/Sources/AppDelegate.swift` — make the `server` property static-accessible:
```swift
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?
    var server: IMKServer?
    let log = Logger(subsystem: "com.sanjiaoim.app", category: "imkit")

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    // ... rest unchanged
}
```

- [ ] **Step 2: Implement CandidatePanel wrapper**

File `App/Sources/CandidatePanel.swift`:
```swift
import Cocoa
import InputMethodKit
import SanJiaoCore

final class CandidatePanel: NSObject {
    private let candidates: IMKCandidates

    init() {
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
```

Note: `CandidatePanel` is lazy-initialised inside `SanJiaoInputController`, which itself is instantiated by IMKit only after `applicationDidFinishLaunching` has run (server is ready).

- [ ] **Step 3: Wire panel into controller**

In `SanJiaoInputController`, add lazy property `private lazy var panel = CandidatePanel()`, and inside `apply(effects:client:state:)` after the loop, add:
```swift
switch state {
case .selecting(let buf, let cands, _):
    panel.show(buffer: buf, entries: cands)
case .empty, .composing:
    panel.hide()
}
```

Also display the buffer inline when composing — before the above switch:
```swift
if case .composing(let buf) = state, let client = client as? IMKTextInput {
    let attr = NSAttributedString(string: buf,
        attributes: [.foregroundColor: NSColor.secondaryLabelColor,
                     .underlineStyle: NSUnderlineStyle.single.rawValue])
    client.setMarkedText(attr, selectionRange: NSRange(location: buf.count, length: 0),
                         replacementRange: NSRange(location: NSNotFound, length: 0))
} else if let client = client as? IMKTextInput {
    client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                         replacementRange: NSRange(location: NSNotFound, length: 0))
}
```

- [ ] **Step 4: Build**

Run: `xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM build`
Expected: SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add App/
git commit -m "feat(app): CandidatePanel using IMKCandidates; inline composing buffer"
```

---

### Task 16: Preferences window with "clear learning history"

**Files:**
- Create: `App/Sources/PreferencesWindow.swift`
- Modify: `App/Sources/SanJiaoInputController.swift` (add menu item)

- [ ] **Step 1: Implement PreferencesWindow**

File `App/Sources/PreferencesWindow.swift`:
```swift
import Cocoa
import SanJiaoCore

final class PreferencesWindow: NSWindowController {
    static let shared = PreferencesWindow(
        window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false))

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.title = "SanJiaoIM 偏好設定"
        let view = window!.contentView!
        let button = NSButton(title: "清除學習紀錄", target: self, action: #selector(clear))
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 20, y: 20, width: 200, height: 32)
        view.addSubview(button)
    }

    @objc private func clear() {
        if var store = LexiconBootstrap.shared.store {
            store.reset()
            LexiconBootstrap.shared.replaceStore(store)
        }
        let alert = NSAlert()
        alert.messageText = "已清除學習紀錄"
        alert.runModal()
    }
}
```

- [ ] **Step 2: Expose menu action**

In `SanJiaoInputController` add:
```swift
public override func menu() -> NSMenu! {
    let m = NSMenu()
    m.addItem(withTitle: "偏好設定…", action: #selector(openPrefs), keyEquivalent: "")
    return m
}

@objc private func openPrefs() {
    PreferencesWindow.shared.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM build`
Expected: SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add App/
git commit -m "feat(app): preferences window with clear-learning-history button"
```

---

### Task 17: App smoke tests

**Files:**
- Create: `AppTests/SmokeTests.swift`
- Modify: `project.yml` (add test target)

- [ ] **Step 1: Add test target to project.yml**

In `project.yml`, under `targets`, add:
```yaml
  SanJiaoIMTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - AppTests
    dependencies:
      - target: SanJiaoIM
schemes:
  SanJiaoIM:
    build:
      targets:
        SanJiaoIM: all
        SanJiaoIMTests: [test]
    test:
      targets: [SanJiaoIMTests]
```

- [ ] **Step 2: Write smoke test**

File `AppTests/SmokeTests.swift`:
```swift
import XCTest
@testable import SanJiaoIM

final class SmokeTests: XCTestCase {
    func testBootstrapFindsLexiconBin() throws {
        let url = Bundle.main.url(forResource: "Lexicon", withExtension: "bin")
        XCTAssertNotNil(url, "Lexicon.bin must be bundled")
    }
}
```

- [ ] **Step 3: Regenerate project and test**

Run:
```bash
xcodegen generate
xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM test
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add project.yml AppTests/ SanJiaoIM.xcodeproj/
git commit -m "test(app): add smoke test target ensuring Lexicon.bin ships"
```

---

### Task 18: install-dev.sh

**Files:**
- Create: `scripts/install-dev.sh`

- [ ] **Step 1: Write script**

File `scripts/install-dev.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/build-lexicon.sh"
xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM -configuration Debug \
    -derivedDataPath build build

APP="$ROOT/build/Build/Products/Debug/SanJiaoIM.app"
DEST="$HOME/Library/Input Methods/SanJiaoIM.app"

if [ -d "$DEST" ]; then
    echo "Removing existing $DEST"
    rm -rf "$DEST"
fi

cp -R "$APP" "$DEST"
echo "Installed to $DEST. Log out and back in, then enable in System Settings → Keyboard → Input Sources."
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/install-dev.sh`

- [ ] **Step 3: Sanity run**

Run: `scripts/install-dev.sh`
Expected: build succeeds; final message prints.

- [ ] **Step 4: Commit**

```bash
git add scripts/install-dev.sh
git commit -m "chore: install-dev.sh for local developer install"
```

---

### Task 19: Error handling for missing Lexicon.bin

**Files:**
- Modify: `App/Sources/AppDelegate.swift`
- Create: `App/Sources/StatusBar.swift`

- [ ] **Step 1: Add status bar indicator**

File `App/Sources/StatusBar.swift`:
```swift
import Cocoa

enum StatusBar {
    private static var item: NSStatusItem?

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
```

- [ ] **Step 2: Wire in AppDelegate**

Replace the `catch` in `applicationDidFinishLaunching`:
```swift
        } catch {
            log.fault("bootstrap failed: \(String(describing: error))")
            StatusBar.showError("Lexicon.bin 缺失或損毀，請重裝")
        }
```

- [ ] **Step 3: Build**

Run: `xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM build`
Expected: SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add App/
git commit -m "feat(app): status-bar indicator when Lexicon.bin is missing"
```

---

### Task 20: Manual-test dry run

**Files:**
- Create: `docs/manual-test-checklist.md`

- [ ] **Step 1: Write checklist**

File `docs/manual-test-checklist.md`:
```markdown
# SanJiaoIM 手動測試清單（v0.1）

每次發佈前在以下 5 款 app 各跑一次：
- Safari（搜尋列）
- Pages（正文）
- Xcode（編輯器）
- Terminal.app（命令列）
- Chrome（搜尋框）

## 基本流程
- [ ] 開啟 app，切換至 SanJiaoIM 輸入法（`Ctrl+Space` 或系統快捷鍵）
- [ ] 輸入 `100301` + `Space` → 應輸出「一」
- [ ] 輸入 `1003` + `Enter` → 候選窗顯示 1003* 所有字
- [ ] 輸入 `1` 選第 1 候選 → 正確送出
- [ ] 輸入 `100301` 再按 `Backspace` → 回到 composing `10030`
- [ ] Composing 中按 `a` → 丟棄 buffer 並送出 `a`
- [ ] 輸入無效碼 `999999` → 顯示無候選提示，不 crash
- [ ] 候選窗翻頁：`.` 前進、`,` 後退

## 錯誤復原
- [ ] 手動刪除 `~/Library/Application Support/SanJiaoIM/freq.json`，重啟 app → 不 crash
- [ ] 手動寫入亂碼到 `freq.json`，重啟 app → 自動備份為 `.corrupt.bak` 並重建

## 偏好設定
- [ ] 輸入法選單 → 偏好設定 → 清除學習紀錄 → freq.json 被清空
```

- [ ] **Step 2: Commit**

```bash
git add docs/manual-test-checklist.md
git commit -m "docs: manual test checklist for v0.1 release"
```

---

## Phase C: Release

### Task 21: GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write workflow**

File `.github/workflows/ci.yml`:
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.0.app
      - name: Test SanJiaoCore
        working-directory: Packages/SanJiaoCore
        run: swift test
      - name: Test sanjiao-builder
        working-directory: Tools/sanjiao-builder
        run: swift test
      - name: Build Lexicon.bin
        run: ./scripts/build-lexicon.sh
      - name: Install xcodegen
        run: brew install xcodegen
      - name: Generate Xcode project
        run: xcodegen generate
      - name: Build and unit-test app
        run: xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM test
```

Note: `macos-latest` currently maps to macOS 14. Tahoe-specific APIs that don't build on 14 will need `macos-15` or `macos-26` when available; revisit when GitHub Actions publishes Tahoe runners. Until then the CI target remains `macOS 14` for build-only verification — for the full `macOS 26` target, developers test locally.

- [ ] **Step 2: Commit**

```bash
git add .github/
git commit -m "ci: add GitHub Actions workflow for core + builder + app"
```

---

### Task 22: README + LICENSE

**Files:**
- Create: `README.md`
- Create: `LICENSE`

- [ ] **Step 1: Write README**

File `README.md`:
```markdown
# SanJiaoIM

macOS 26 Tahoe+ 上的三角編號法輸入法。開源、MIT 授權。

## 安裝（開發版）

需求：macOS 26 Tahoe+，Xcode 16+，Swift 6，xcodegen。

\`\`\`bash
git clone https://github.com/<you>/SanJiaoIM.git
cd SanJiaoIM
./scripts/install-dev.sh
\`\`\`

登出/登入後，系統設定 → 鍵盤 → 輸入來源 → 加入「SanJiaoIM」。

## 基本用法

中文模式下：
- `0-9` — 輸入三角編號碼（最多 6 位）
- `Space` — 以當前 buffer 查字並選第一個候選
- `Enter` — 右側補 0 至 6 位再查字（匹配原 PIME 行為）
- `1-9` / `0` — 在候選窗中選第 N 個
- `.` / `,` — 候選翻頁
- `Backspace` — 刪一位碼
- `Esc` — 取消輸入

## 授權

MIT。碼表來源：[chinese-opendesktop/cin-tables](https://github.com/chinese-opendesktop/cin-tables)（Public Domain）。

## 開發

\`\`\`bash
cd Packages/SanJiaoCore && swift test
cd Tools/sanjiao-builder && swift test
./scripts/build-lexicon.sh
\`\`\`
```

- [ ] **Step 2: Write LICENSE (MIT)**

File `LICENSE`:
```
MIT License

Copyright (c) 2026 <your name>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: Commit**

```bash
git add README.md LICENSE
git commit -m "docs: README and MIT LICENSE"
```

---

### Task 23: Release packaging workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Write release workflow**

File `.github/workflows/release.yml`:
```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.0.app
      - name: Install xcodegen
        run: brew install xcodegen
      - name: Build Lexicon.bin
        run: ./scripts/build-lexicon.sh
      - name: Generate Xcode project
        run: xcodegen generate
      - name: Build release app
        run: |
          xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM \
            -configuration Release -derivedDataPath build build
      - name: Package
        run: |
          cd build/Build/Products/Release
          zip -r "../../../../SanJiaoIM-${GITHUB_REF_NAME}.zip" SanJiaoIM.app
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: SanJiaoIM-*.zip
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: release workflow packaging .app zip on tag"
```

---

### Task 24: Tag v0.1.0

**Files:** (none)

- [ ] **Step 1: Run full verification**

```bash
cd Packages/SanJiaoCore && swift test && cd ../..
cd Tools/sanjiao-builder && swift test && cd ../..
./scripts/build-lexicon.sh
xcodegen generate
xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM test
```
Expected: all green.

- [ ] **Step 2: Run full manual checklist**

Follow `docs/manual-test-checklist.md` on the 5 apps.

- [ ] **Step 3: Tag and push**

```bash
git tag -a v0.1.0 -m "v0.1.0 — MVP with core lookup, user frequency, candidate panel"
git push origin main --tags
```

Release workflow produces `SanJiaoIM-v0.1.0.zip` on GitHub.

---

## Spec coverage audit

| Spec section | Tasks |
|---|---|
| §2 架構 | 1, 13, 14 |
| §3 Composer 狀態機 | 9, 14 |
| §4 候選窗 | 15 |
| §5 FrequencyStore + Ranker | 10, 11, 16 (clear button) |
| §6 碼表建置 | 3, 4, 5, 6, 7, 12 |
| §7 錯誤處理 | 10 (corrupt file), 14 (nil client), 19 (missing bin) |
| §8 測試策略 | TDD across 2-11; smoke in 17; manual in 20 |
| §9 專案結構 | 1, 13 |
| §10 發佈 | 18, 22, 23, 24 |
| §11 非範圍 | (explicitly excluded — no tasks) |
