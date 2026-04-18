# SanJiaoIM 設計規格

**日期**：2026-04-18
**狀態**：草案（待實作）
**目標平台**：macOS 13+（Ventura 起，假設值 — 見 §12）
**授權**：MIT
**專案目標**：在 macOS 上實作三角編號法輸入法，開源釋出。

---

## 1. 背景與決策摘要

三角編號法（Three Corner Code）由胡立人、張源渭、黃克東（美國王安電腦公司）提出，以字形三角的 6 位數字碼檢索漢字。本專案在 macOS 上實作該輸入法，決策如下：

| 項目 | 決定 | 理由 |
|---|---|---|
| 發佈形式 | 開源（GitHub） | 使用者目標為 B |
| 碼表來源 | `chinese-opendesktop/cin-tables` 的 `3corner.cin`（Public Domain） | 與 PIME 版碼表內容一致；CIN 是社群通用格式 |
| 字集顯示 | 分層顯示（Big5F → Big5LF → Big5Other → CJK-B+） | 候選窗乾淨、進階使用者仍可取用完整字集 |
| 框架 | Swift + InputMethodKit | 官方 API、現代 Swift、核心可抽獨立套件 |
| 鍵盤輸入 | 主鍵區頂排 1234567890 | macOS CIN 輸入法慣例；MacBook 相容 |
| MVP 功能 | 基本查字 + 候選窗 + 使用者字頻 | 字頻對三角編號多重碼字的體驗差異巨大 |
| 名稱 | SanJiaoIM | |
| 發佈方式 | GitHub Release + ad-hoc 簽章；v0.2+ 考慮 Homebrew Cask | 零成本起步 |

---

## 2. 高階架構

```
┌──────────────────────────────────────────────┐
│  SanJiaoIM.app  (IMKit 輸入法 bundle)        │
│  ├── SanJiaoInputController  ─ 按鍵/狀態機   │
│  ├── CandidatePanel          ─ 候選窗 UI     │
│  └── PreferencesWindow       ─ 偏好設定      │
├──────────────────────────────────────────────┤
│  SanJiaoCore  (SPM Package, 純 Swift, 無 UI) │
│  ├── Lexicon            ─ 碼→字 查詢         │
│  ├── Composer           ─ 輸入 buffer 狀態機 │
│  ├── FrequencyStore     ─ 使用者字頻         │
│  └── Ranker             ─ 候選排序           │
├──────────────────────────────────────────────┤
│  sanjiao-builder  (離線 CLI)                 │
│  └── 3corner.cin → Lexicon.bin               │
└──────────────────────────────────────────────┘
```

### 2.1 分離原則
- `SanJiaoCore` 不依賴 AppKit / IMKit；可用 XCTest 純邏輯測試；為未來 iOS 版留伏筆。
- `sanjiao-builder` 是 build-time 工具，不隨 app 發佈；其產物（`Lexicon.bin`）內嵌於 app bundle。
- IMKit 層僅翻譯「按鍵事件 ↔ Composer state」，不懂查字細節。

### 2.2 內部實作選擇
- **碼表儲存**：自訂二進位格式（見 §6），非 SQLite 或 plist。
- **載入策略**：啟動時一次讀檔並建索引；經量測 ~500 KB、~33K 條目載入約 50 ms，無需 mmap 延遲載入。
- **查字索引**：`Dictionary<String, [CharEntry]>` 以完整 6 位碼為 key 提供 O(1) 查字；前綴查詢用已排序的 code 陣列 + binary search。

---

## 3. Composer 按鍵狀態機

三種狀態：`Empty`、`Composing`、`Selecting`。

### 3.1 狀態轉移

| 狀態 | 按鍵 | 行為 |
|---|---|---|
| Empty | `0-9` | 進 Composing，buffer = [key] |
| Empty | 其他可見鍵 | 透傳給系統（混打英數） |
| Composing | `0-9` | buffer append；達 6 位自動轉 Selecting |
| Composing | `Space` | 以當前 buffer 查字，轉 Selecting |
| Composing | `Enter` | 補 0 到 6 位後查字，轉 Selecting |
| Composing | `Backspace` | buffer pop；若空回 Empty |
| Composing | `Esc` | 清空 buffer 回 Empty |
| Composing | `a-zA-Z` 等 | 丟棄 buffer，該鍵透傳（「直覺派」） |
| Selecting | `1-9` / `0` | 選第 N 個候選送出，回 Empty |
| Selecting | `Space` | 選第 1 個候選送出 |
| Selecting | `,` / `.` / 左右方向鍵 | 翻頁 |
| Selecting | `Esc` | 清空回 Empty |
| Selecting | `Backspace` | 回 Composing，保留 buffer |
| Selecting | `a-zA-Z` 等 | 送出第 1 候選並透傳該鍵 |

### 3.2 無候選情境
查無字時顯示「❌ 無此碼」提示但保留 buffer，使用者可 Backspace 修正。

### 3.3 Enter 補 0 語意
忠於 PIME 原版：按 Enter 時 `buffer` 右側補 `0` 至 6 位再查字（相當於前綴查詢擴充）。

---

## 4. 候選窗 UI

### 4.1 技術選擇
MVP 採 **IMKit 內建 `IMKCandidates`**；每頁 10 格對應 `1234567890`。日後若需分層展開互動再換自製 NSWindow。

### 4.2 顯示規則
- 候選順序：`big5F`（5483 常用）→ `big5LF`（7957 次常用）→ `big5Other` → `CJK-B+` 罕字。
- 使用者字頻加權後重排（見 §5）。
- 6 位碼重碼多時分頁；未滿 6 位（Enter 補 0 情境）前綴字全部收齊後排序。

### 4.3 視覺（MVP）
橫排、單行；左上角顯示當前 buffer（灰字）+ 候選字標號 `1-0`。範例：

```
┌──────────────────────────────────────────────┐
│ 1023__  [1]一 [2]丁 [3]七 [4]丂 [5]丄 ...    │
└──────────────────────────────────────────────┘
```

---

## 5. 使用者字頻（FrequencyStore）

### 5.1 資料結構
Key = `"<code>|<char>"`，value 如下：

```swift
struct Stats: Codable {
    var count: UInt32
    var lastUsed: Date
}
```

### 5.2 儲存
`~/Library/Application Support/SanJiaoIM/freq.json`（JSON，方便 debug 與備份）。

### 5.3 更新時機
使用者從候選窗選字送出時呼叫 `store.bump(code:, char:)`。

### 5.4 排序公式（Ranker）
```
score = baseRank (小 = 優)
      - α · log(1 + freq)
      + β · daysSinceLastUsed
```
- `baseRank`：CIN 原序 + Big5 層級
- `α = 5.0`、`β = 0.1`（程式內常數，v0.1 不暴露給使用者）

### 5.5 寫入節流
每 20 次選字 flush 一次；`applicationWillTerminate` 強制 flush。Flush 於 serial queue 執行，避免 UI 阻塞。

### 5.6 隱私
純本機、無遙測。偏好面板提供「清除學習紀錄」按鈕。

### 5.7 損毀處理
JSON parse 失敗 → 靜默重建為空，保留 `freq.json.corrupt.bak` 一份。

---

## 6. 碼表建置流程（sanjiao-builder）

### 6.1 概觀
獨立 Swift CLI，離線將 `3corner.cin` 轉為 `Lexicon.bin`。

### 6.2 管線
1. 解析 CIN：讀 `%chardef begin`/`end` 區段，每行取 `(code: String, char: String)`。
2. 分層標記：依字元是否在 Big5F / Big5LF / Big5Other / CJK-B+ 之一。
3. 排序：`(layer ASC, CIN 原序 ASC)`。
4. 序列化為自訂二進位（見下）。

### 6.3 Lexicon.bin 格式
```
Header: magic "SJIM" (4B) + version u16 + entryCount u32
Section A: entries
    for each entry:
        code: 6 bytes ASCII
        charLen: u8
        charUTF8: var bytes
        layer: u8  (0=big5F, 1=big5LF, 2=big5Other, 3=cjkExt)
Section B: code-index
    code → (offsetStart u32, offsetEnd u32)
```
- 啟動時一次讀檔、解析進 `Dictionary` + 排序陣列（§2.2）。
- 版本號不匹配 → 重載 bundle 內建版本（v0.1 不支援使用者自訂碼表）。
- 預估大小：~500 KB。

### 6.4 執行時機
- 開發：手動跑 `scripts/build-lexicon.sh`。
- CI：build phase 前執行一次，產物 gitignore。

### 6.5 驗證
Builder 測試給小段 mock CIN，跑 `build → Lexicon 讀回`，assert round-trip 相等。驗證 Big5 分層邊界字。

---

## 7. 錯誤處理與邊界

策略：靜默降級 + `os_log`，不彈 alert 干擾打字。

| 情境 | 處理 |
|---|---|
| `Lexicon.bin` 缺失/損毀 | fatal log → menu bar 紅點提示「請重裝」；IME 轉透傳 |
| `freq.json` parse 錯 | 靜默重建為空，留 `.corrupt.bak` |
| client 傳 nil buffer | Composer 忽略，不 crash |
| 候選窗多螢幕錯位 | 沿用 IMKCandidates 預設定位 |
| 高速連續按鍵 | Composer 純同步；FrequencyStore flush 用 serial queue |
| 系統休眠恢復狀態異常 | `activateServer`/`deactivateServer` 強制 reset 到 Empty |

**日誌**：`os_log`，subsystem=`com.sanjiaoim.app`，category 分 `core` / `imkit` / `freq`。

---

## 8. 測試策略

### 8.1 單元（SanJiaoCoreTests，密度最高）
- `LexiconTests`：mock `.bin`，驗 lookup / 前綴 / 空結果。
- `ComposerTests`：`[KeyEvent] → ExpectedState` 表驅動；涵蓋 §3 所有轉移（含混打、Backspace、6 位自動提交）。
- `FrequencyStoreTests`：bump / flush / 衰減 / 損毀復原。
- `RankerTests`：排序公式穩定性。

### 8.2 建置器（SanJiaoBuilderTests）
Round-trip、Big5 分層邊界字。

### 8.3 IMKit 整合（薄）
- Smoke test：app bundle 啟動不 crash、偏好面板開啟不 crash。
- 手動清單 `docs/manual-test-checklist.md`：Safari、Pages、Xcode、Terminal、Chrome。

### 8.4 CI
GitHub Actions macOS runner，跑單元 + 建置器測試 + `xcodebuild test`；不跑 IMKit 整合（runner 無桌面）。

### 8.5 TDD 紀律
Composer 與 Ranker 採 TDD（純邏輯、邊界多）。Lexicon / Builder 可先實作再補測試（I/O 為主）。

---

## 9. 專案結構

```
tri-corner/
├── SanJiaoIM.xcodeproj
├── Packages/
│   └── SanJiaoCore/
│       ├── Package.swift
│       ├── Sources/SanJiaoCore/
│       │   ├── Lexicon.swift
│       │   ├── Composer.swift
│       │   ├── FrequencyStore.swift
│       │   └── Ranker.swift
│       └── Tests/SanJiaoCoreTests/
├── App/
│   ├── AppDelegate.swift
│   ├── SanJiaoInputController.swift
│   ├── CandidatePanel.swift
│   ├── PreferencesWindow.swift
│   ├── Info.plist
│   └── Resources/
│       └── Lexicon.bin (gitignored)
├── Tools/
│   └── sanjiao-builder/
│       ├── Package.swift
│       └── Sources/main.swift
├── Vendor/
│   ├── 3corner.cin           # vendored 單檔副本，Public Domain
│   └── 3corner.cin.SOURCE    # 註明來源 URL + commit SHA，方便日後同步
├── docs/
│   ├── superpowers/specs/
│   ├── manual-test-checklist.md
│   └── architecture.md
├── .github/workflows/ci.yml
├── scripts/
│   ├── build-lexicon.sh
│   └── install-dev.sh
├── README.md
├── LICENSE  # MIT
└── .gitignore
```

### 9.1 Info.plist 關鍵欄位
- `InputMethodConnectionName`: `SanJiaoIM_1_Connection`
- `InputMethodServerControllerClass`: `SanJiaoIM.SanJiaoInputController`
- `tsInputMethodCharacterRepertoireKey`: `zh-Hant, zh-Hans`
- `LSBackgroundOnly`: `YES`
- `LSUIElement`: `YES`

---

## 10. 發佈流程

### 10.1 v0.1（MVP）
1. GitHub Actions 產出 `SanJiaoIM-x.y.z.zip`（含 `.app` bundle，ad-hoc 簽章）。
2. 使用者下載、解壓 → 拖到 `~/Library/Input Methods/`。
3. 登出/登入 → 系統偏好「鍵盤 → 輸入法」加入 SanJiaoIM。
4. 首次啟動時 Gatekeeper 警告 → 「隱私權與安全性」允許。

### 10.2 v0.2+
- Homebrew Cask formula。
- 考慮 Developer ID 簽章 + 公證（若有贊助或穩定使用者基數）。

### 10.3 版本策略
SemVer。`0.1.0` = MVP 完成（§1-9 全部實作）。

---

## 11. 非範圍（明確排除）

v0.1 不做：
- 使用者自訂碼表 / 自訂詞組
- 詞彙聯想輸入（多字連打）
- iOS / iPadOS 版本
- 雲端同步字頻
- 打字統計 / 遙測
- 在 IMKit 層做 SwiftUI 自訂 cell（留給未來）

這些需求出現時，再開新 spec 評估。

---

## 12. 開放議題

1. **最低 macOS 版本**：暫定 13+（Ventura）。若需支援更低（如 12），`IMKCandidates` + SwiftUI 互通性需另行驗證。待使用者確認。
