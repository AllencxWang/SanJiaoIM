# 發佈流程（v0.1.x）

GitHub Actions 目前沒有 macOS 26 Tahoe runner（`macos-14` + Xcode 16.0 無法建置
deployment target 26.0），因此發佈必須在本機完成。等 GitHub 發佈 Tahoe runner
（例如 `macos-26`）後，可從 git 歷史撈回 `.github/workflows/release.yml`
（見 commit `6e6990d`），把 `runs-on:` 換掉即可恢復自動發佈。

## 本機發佈步驟

```bash
# 1. 確認測試全綠
(cd Packages/SanJiaoCore && swift test)
(cd Tools/sanjiao-builder && swift test)

# 2. 重建碼表與專案
./scripts/build-lexicon.sh
xcodegen generate

# 3. Release 建置
xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM \
  -configuration Release -derivedDataPath build build

# 4. 打包並建立 GitHub Release（以 v0.1.0 為例）
cd build/Build/Products/Release
zip -r ../../../../SanJiaoIM-v0.1.0.zip SanJiaoIM.app
cd -
gh release create v0.1.0 SanJiaoIM-v0.1.0.zip

# 5. 發佈前請跑過 docs/manual-test-checklist.md
```
