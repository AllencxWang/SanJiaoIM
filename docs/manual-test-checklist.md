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

## IMKit 接縫回歸（v0.1 code review 發現的 bug，發佈前必測）
- [ ] 未組字時按 `Space`／`Enter`／`Backspace`／`Esc`／`,`／`.` → 按鍵正常送達 app（能打空格、換行、刪字）
- [ ] 組字或選字中按 `Cmd+C`／`Cmd+1` 等快捷鍵 → app 快捷鍵正常作用，不會被當成輸入
- [ ] 輸入 `999999`（無此碼）後繼續打數字 → beep、buffer 維持 6 碼；接著按 `Enter` → 不 crash
- [ ] 候選超過 10 個時按 `.` 翻頁再按 `1` → 送出的字與畫面上第 1 個一致
- [ ] 用滑鼠點候選窗中的字 → 正確送出該字，後續輸入行為正常
- [ ] 輸入 `10` + `Enter` 查無 exact match → 候選僅含 10 開頭的碼；`01` 開頭的碼也查得到
- [ ] 選同一個字幾次後重新輸入同碼 → 該字排序前移（字頻學習生效）
- [ ] 候選窗開啟時，已輸入的編碼仍以底線 marked text 顯示在游標處

## 錯誤復原
- [ ] 手動刪除 `~/Library/Application Support/SanJiaoIM/freq.json`，重啟 app → 不 crash
- [ ] 手動寫入亂碼到 `freq.json`，重啟 app → 自動備份為 `.corrupt.bak` 並重建

## 偏好設定
- [ ] 輸入法選單 → 偏好設定 → 清除學習紀錄 → freq.json 被清空
