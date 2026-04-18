# SanJiaoIM

macOS 26 Tahoe+ 上的三角編號法（三角編號, Three-Corner Code）輸入法。開源、MIT 授權。

## 安裝（開發版）

需求：macOS 26 Tahoe+，Xcode 16+（含 Swift 6.2 toolchain），`xcodegen`。

```bash
git clone https://github.com/<your-username>/SanJiaoIM.git
cd SanJiaoIM
./scripts/install-dev.sh
```

登出/登入後，系統設定 → 鍵盤 → 輸入來源 → 加入「SanJiaoIM」。

> 首次啟動時，macOS Gatekeeper 可能會警告「來自未識別開發者」。前往「系統設定 → 隱私權與安全性」允許執行。

## 基本用法

切換至 SanJiaoIM 輸入法後：

| 按鍵 | 作用 |
|---|---|
| `0-9` | 輸入三角編號碼（最多 6 位） |
| `Space` | 以當前 buffer 查字並選第一個候選 |
| `Enter` | 右側補 0 至 6 位再查字 |
| `1-9` / `0` | 在候選窗中選第 N 個（0 表第 10 個） |
| `.` / `,` | 候選翻頁 |
| `Backspace` | 刪一位碼 |
| `Esc` | 取消輸入 |

輸入英文字母時，若 Composer 處於 composing 狀態，會丟棄 buffer 並直接送出該字母（直覺派混打）。

## 偏好設定

輸入法選單 → 偏好設定 → 「清除學習紀錄」會清空 `~/Library/Application Support/SanJiaoIM/freq.json`。

## 授權

MIT。碼表來源：[chinese-opendesktop/cin-tables](https://github.com/chinese-opendesktop/cin-tables) 的 `3corner.cin`（Public Domain）。

編碼規則：胡立人、張源渭、黃克東（美國王安電腦公司）。

## 開發

```bash
# 核心單元測試
cd Packages/SanJiaoCore && swift test

# 建置器單元測試
cd Tools/sanjiao-builder && swift test

# 重建 Lexicon.bin
./scripts/build-lexicon.sh

# 產生 Xcode project（首次 clone 後）
xcodegen generate

# 手動測試清單：docs/manual-test-checklist.md
```

## 非功能（v0.1 明確排除）

- 使用者自訂碼表 / 詞組
- 多字連打 / 聯想輸入
- iOS/iPadOS 版本
- 雲端同步字頻
- 打字遙測
