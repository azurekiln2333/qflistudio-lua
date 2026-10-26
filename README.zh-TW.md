# qfli_lua

[English](README.md) | [简体中文](README.zh-CN.md) | 繁體中文

## 用途

本 App 是離線的 Script 開發環境。產品名為 QFLIScript。
App 執行 Lua、JavaScript、TypeScript 與 Shell 程式碼。
Lua 引擎隨 App 打包。使用者不需要安裝系統 Lua。
JavaScript 與 TypeScript 需要 Script 橋接庫。
Apple 專案不含 Script 橋接庫。
預設 MSVC 建置也不含此庫。
Shell 不是內建引擎。它使用系統 shell。

本倉庫是獨立的 Git 倉庫。請把 `qfli_studio_core` 放在同一層目錄。

```text
上層目錄/
  qfli_studio_core/
  qfli_lua/
```

在本目錄執行 `flutter pub get`。
接著執行 `flutter run` 部署到目標裝置。
共用編輯器補丁來自 `../qfli_studio_core/vendor/re_editor`。

## 目前功能

- 「執行」按鈕執行 Lua 原始碼或 `.luac` 位元組碼。
- 「執行」按鈕執行 `.js`、`.mjs` 與 `.ts` 檔案。
- 編輯器提供「檢查 Lua 語法」操作。
- 編輯器提供「編譯 Lua 位元組碼」操作。
- 工具頁列出九個獨立工具。
- 終端接受 `lua` 與 `luac` 命令。
- 內容頁內建 240 個範例與 23 篇教學。
- 編輯器顯示真實語法診斷。診斷帶範圍與波浪線。
- 問題面板可跳到對應檔案位置。
- 側邊欄記住展開狀態。工作區可同時開啟多個專案。
- 原始碼除錯器支援中斷點與單步。

工具頁的九個工具如下。

| 工具 | 用途 |
|---|---|
| Lua 原始碼除錯 | 中斷點與單步 |
| Lua 語法檢查 | 只解析，不執行 |
| Lua 位元組碼 | 檢視標頭、函式與常數 |
| Lua 模組解析 | 顯示 `package.path` 與 `require` 依賴 |
| Lua 字串字面量 | 轉換字串與跳脫序列 |
| Lua 模式匹配 | 測試模式並顯示擷取 |
| JavaScript 語法檢查 | 只編譯，不執行 |
| TypeScript 轉譯 | 輸出 JavaScript |
| Shell 語法檢查 | 回報語法與可攜性問題 |

## 離線與執行邊界

獨立版關閉登入介面。
獨立版關閉社群介面。
獨立版關閉雲端介面。
編輯器與內建語言工具在本機執行。

Lua 使用內建 Lua 5.4.8。原始碼與位元組碼都能執行。
Lua 引擎內建於 Android、HarmonyOS、Windows、Linux、iOS 與 macOS。
原始碼與位元組碼必須使用同一個 VM 版本。
每次執行把相對路徑解析到專案目錄。
橋接不改變程序工作目錄。

JavaScript 與 TypeScript 使用 QuickJS 與 TypeScript 5.9.3。
QuickJS 不含 Node、瀏覽器 API、計時器與網路綁定。
模組匯入必須寫出副檔名。專案外的匯入會回報錯誤。
TypeScript 只回報語法與選項診斷。它不做型別檢查。
TypeScript 原始碼先轉譯，再由 QuickJS 執行。
每次 Script 操作使用全新的 QuickJS 執行環境。
堆積上限 256 MiB。堆疊上限 2 MiB。
單一 QuickJS 來源檔上限 512 KiB。
Lua 不另外設定這三項限額。
專案上限 256 個來源檔與 8 MiB。

Shell 使用系統 shell。行動平台也許沒有可用的 shell。
Android 與 HarmonyOS 查 `/system/bin/sh` 或 `/bin/sh`。
桌面查 `sh` 或 `bash`。
Shell 的 `input.txt` 只接受一般檔案。

Lua 與 QuickJS 預設限時 10 秒。
兩種引擎的每條輸出串流上限是 1 MiB。
每次執行可以取消。取消回傳狀態 130。
缺少執行環境時回傳狀態 127。
`os.exit` 只回傳離開碼。它不結束 App 程序。
取消是協作式。它也許無法中斷阻塞的原生呼叫。

終端只提供檔案命令與 `lua`、`luac`。
終端不支援管線、重定向、串接與變數展開。
終端對不支援的命令回報原因。它不假裝成功。

除錯器執行已儲存的原始碼。它支援中斷點與單步。
變數檢查不執行 Lua 運算式。物件內容不可用。

## 建置與檢查

請使用支援 HarmonyOS 的 Flutter SDK。
請保持 SDK 路徑與 `ohos/local.properties` 一致。
先取得相依套件。

```text
flutter pub get
```

再執行靜態分析與測試。

```text
flutter analyze
flutter test
```

原生 Lua 橋接用 CMake 建置。主機測試用 CTest。

```text
cmake -S native -B native/build/host -G Ninja
cmake --build native/build/host
ctest --test-dir native/build/host --output-on-failure
```

JavaScript 與 TypeScript 引擎另外建置。
編譯器須為 GCC 9 以上或 Clang。
請把編譯器路徑替換為本機路徑。

```text
cmake -S native -B native/build/script-windows -G Ninja -DCMAKE_C_COMPILER=C:/path/to/gcc.exe
cmake --build native/build/script-windows --target qfli_script_engine
python native/script/test_native.py
```

命令列工具使用同一份內建程式庫。

```text
dart run bin/qfli_lua.dart run <檔案>
dart run bin/qfli_lua.dart check <檔案>
dart run bin/qfli_lua.dart compile <檔案> [輸出.luac]
dart run bin/qfli_lua.dart version
```

桌面快速驗證執行 `examples/hello.lua`。
輸出為 `sum` 與 `55`，兩者以定位字元分隔。

內容驗證器逐筆執行範例。
驗證器比對實際輸出。

```text
dart run tool/verify_lua_content.dart
```

完整稽核涵蓋 1,282 處位置。
其中 682 處來自 Lua。600 處來自 JS、TS 與 Shell。
兩個稽核入口都要用 Flutter 啟動。
`dart run` 無法啟動這兩個入口。

```text
flutter run -t bin/script_acceptance.dart
flutter run -t bin/lua_catalog_audit.dart
```

後一個入口只涵蓋 Lua。
OHOS 建置指令稿是 `tools/build_ohos_audit.ps1`。
該指令稿保留套件摘要與檢查報告。

建置細節見 [`native/README.md`](native/README.md)。

## 目錄

```text
lib/          編輯器、工具鏈、除錯器與工具頁
native/       Lua 與 QuickJS 原生橋接
test/         Flutter 測試
bin/          命令列工具與驗收腳本
tool/         內容建置與驗證腳本
tools/        建置檢查腳本
assets/       圖示、內容 JSON 與 TypeScript 編譯器
examples/     範例程式
scripts/      文件檢查腳本
android/ ios/ linux/ macos/ ohos/ web/ windows/   平台專案
```

## 授權

本倉庫根目錄沒有 LICENSE 檔。

Lua 5.4.8 使用 MIT 授權。原始授權保留在 `native/third_party/lua-5.4.8/`。
QuickJS 使用 MIT 授權。授權檔在 `native/script/quickjs/LICENSE`。
TypeScript 5.9.3 使用 Apache-2.0 授權。
授權檔在 `assets/runtime/TYPESCRIPT-LICENSE.txt`。

## 驗收限制

主機檢查不等於目標裝置通過。
目前沒有可連線的 OHOS 目標裝置。
HAP 封裝檢查與裝置執行是兩個獨立關卡。
2026 年 10 月 26 日的主機測試結果如下。
測試通過 373 項。
測試跳過 1 項。
測試沒有失敗項。
完整稽核的 20 項主機斷言通過。
稽核涵蓋 1,282 處位置。
800 處歷史結尾換行位元組差異仍保留。
這不表示 1,282 處嚴格位元組比對全通過。
OHOS 原生探針為 `not_evaluated`。
本次未封裝新的 HAP。
本次未執行目標裝置驗收。
驗證程序已自然結束。
末次終端確認超過 330 秒協調上限。
完整交接時限未通過。
這些結果只適用於當時的原始碼快照。
後續生產原始碼修改仍需新的完整驗證。
目標裝置驗收仍然開放。
一次完整的目標驗收仍待新的執行時段。
內容驗證在主機執行。這是主機證據，不是裝置證據。
Windows 完整 App 需要 Visual Studio。
Apple 建置需要 Xcode。Apple 只編譯 Lua 橋接。
Linux 建置需要可用的 Linux 環境。
這台 Windows 主機沒有執行上述平台建置。
Script 引擎的 Apple 打包尚未驗證。
Android 封裝結果見
[平台驗證紀錄](.trellis/tasks/10-01-native-platforms/verification.md)。
