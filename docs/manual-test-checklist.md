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
