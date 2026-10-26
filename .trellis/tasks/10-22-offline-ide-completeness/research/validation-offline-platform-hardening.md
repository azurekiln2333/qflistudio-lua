# Pi p6 — OHOS offline platform hardening (implementation record)

Owner: Pi p6. Exclusive implementation ownership granted for exactly:
1. `ohos/entry/src/main/ets/entryability/EntryAbility.ets`
2. `ohos/entry/src/main/module.json5`
3. `ohos/entry/src/main/resources/base/profile/main_pages.json`
4. `test/lua_offline_platform_test.dart` (new)

Generated: 2026-10-22.
No commits. No other files edited. No full builds, no signing changes.
ArkTS type-check / HAP build is root's final gate.

## Why this change

`research/validation-platform-audit.md` §8 proved the offline Lua product still
shipped network capability: `ohos.permission.INTERNET`, an Account Kit login
channel (`qflistudio/huawei_account`), an HTTPS `Web()` AgreementReader page, a
browser-launching `openUrl` handler, and a placeholder AGC `client_id`.
The Dart UI was already `offlineOnly`-gated, so none of it was reachable — but it
was compiled into the package, which contradicts a strict-offline product.

## Exact changes

### 1. `module.json5`
- **Removed** `{"name": "ohos.permission.INTERNET"}` from `requestPermissions`.
  Remaining permission set is exactly `ohos.permission.READ_PASTEBOARD`.
- **Removed** the ability `metadata` block holding
  `{"name": "client_id", "value": "REPLACE_WITH_AGC_CLIENT_ID"}`.
- **Preserved** the pre-existing peer change `deviceTypes: ["phone","2in1","tablet"]`,
  plus `startWindowIcon`, `startWindowBackground`, `exported`, `skills`
  (`entity.system.home`), `mainElement`, pasteboard `reason` + `usedScene`.

### 2. `main_pages.json`
- Route table reduced to `["pages/Index"]`.
- `pages/AgreementReader` deregistered. `ohos/.../ets/pages/AgreementReader.ets`
  is **left on disk untouched** (still untracked, mtime 2026-09-27 17:01:49) and
  is now simply unreachable — per instruction to preserve it unused.
- Note: HEAD already contained only `pages/Index`; the `AgreementReader` entry was
  an uncommitted working-tree addition, so removing it produces a clean diff.

### 3. `EntryAbility.ets`
Removed:
- `import { authentication } from '@kit.AccountKit'` (whole Account Kit path)
- `import { router } from '@kit.ArkUI'`, `Want` from `@kit.AbilityKit`
- `CHANNEL_HUAWEI` constant and the entire `huawei_account` MethodChannel with its
  `AuthorizationWithHuaweiIDRequest` / `AuthenticationController.executeRequest` login.
- `router.pushUrl({ url: 'pages/AgreementReader', ... })`
- `abilityContext.startAbility({ action: 'ohos.want.action.viewData', ... })` (browser)

Changed to explicit refusals:
- `openAgreement` → `result.error(OFFLINE_ONLY_CODE, OFFLINE_ONLY_MESSAGE, null)`
- `openUrl` → `result.error(OFFLINE_ONLY_CODE, OFFLINE_ONLY_MESSAGE, null)`
- New constants: `OFFLINE_ONLY_CODE = 'OFFLINE_ONLY'`,
  `OFFLINE_ONLY_MESSAGE = '离线版不提供网络功能'`.
- Kept both **method names** on purpose: shared core still calls them
  (`agreement_page.dart`, `runner_service.dart:232`), so returning a real
  `PlatformException` with a clear reason beats a silent `notImplemented`.
  Both Dart callers already tolerate `PlatformException`.

Preserved untouched:
- `onWindowStageCreate` dark/light `setWindowBackgroundColor`
  (`#FF111418` / `#FFF8F9FF`, `COLOR_MODE_DARK`), `super.onWindowStageCreate`.
- `startupProgress` contract: `Number.isFinite` guard, clamping
  `Math.max(0, Math.min(1, progress))`, `EVENT_STARTUP_PROGRESS` emit,
  `INVALID_PROGRESS` error, `result.success(null)`.
- `shareText` via Share Kit (`systemShare.SharedData`, `general.plain-text`,
  `ShareController.show`), `SHARE_FAILED` error.
- `PickerBridge` (`isPickerMethod` / `handlePickerCall`).
- `GeneratedPluginRegistrant.registerWith`, `super.configureFlutterEngine`,
  trailing `result.notImplemented()`.
- Import audit: all 13 remaining imported symbols are used ≥2 times (declaration +
  use); no dangling imports.

### 4. `test/lua_offline_platform_test.dart` (new, 14 tests)
Source/manifest regression tests — deliberately covering the class of mistake that
**compiles fine but silently restores network capability**:
- exact permission list equals `[READ_PASTEBOARD]`; no `INTERNET`, no `*NETWORK*`
- pasteboard `reason` / `usedScene` intact
- no `metadata`, no `REPLACE_WITH_AGC_CLIENT_ID`
- startup icon / background / `exported` / home skill preserved
- route table exactly `[pages/Index]`; `AgreementReader.ets` exists but no other
  `.ets` file references it
- no `@kit.AccountKit`, `authentication.`, `HuaweiID`, `huawei_account`, `CHANNEL_HUAWEI`
- no `router.pushUrl`, no `ohos.want.action.viewData`, no `startAbility(` call, no `Web(`, no `http://`/`https://`
- `openAgreement` / `openUrl` branches return `OFFLINE_ONLY_CODE` via `result.error`
  and contain no `result.success` / `startAbility` / `pushUrl`
- `OFFLINE_ONLY` constant + Chinese offline message
- preserved contracts: startup progress, dark background, picker, share, `notImplemented`

Includes a small JSON5 normalizer (line/block comments + trailing commas) so the
manifest is parsed structurally rather than string-matched; `branch()` extracts a
handler body by brace-balancing so nested `if/else` cannot truncate it.

## Test evidence (cached Flutter SDK `D:\ProgramFiles\flutter_ohos`)

```
flutter test test/lua_offline_platform_test.dart
→ 00:00 +14: All tests passed!          (3 consecutive runs, 14/14 each)

flutter analyze test/lua_offline_platform_test.dart
→ No issues found! (ran in 3.1s)

flutter test test/startup_test.dart
→ 00:01 +1: All tests passed!           (platform channel still healthy)
```

Two harness bugs of mine were fixed during development (recorded for honesty):
`String.replaceAll` does not expand `$1` groups (needed `replaceAllMapped`), and my
first `branch()` truncated at nested `} else {` (replaced with brace balancing).
Neither was a product issue.

One transient: a `startup_test.dart` run once failed at load with peers' concurrent
`flutter test` runs sharing `.dart_tool`; it passed immediately when re-run alone.

### Mutation check (proves the test is not vacuous)

Temporarily reintroduced (a) `ohos.permission.INTERNET` and (b) a real
`startAbility` browser call inside `openUrl`, then re-ran:

```
00:00 +0 -1: 只申请本地能力权限 [E]  Expected: ['ohos.permission.READ_PASTEBOARD']
                                     Actual:   ['ohos.permission.INTERNET', 'ohos.permission.READ_PASTEBOARD']
00:00 +6 -2: 不再注册可打开浏览器或远程页面 [E]  Expected: false  Actual: <true>
00:00 +6 -3: openAgreement 与 openUrl 显式返回 OFFLINE_ONLY [E]  Expected: false  Actual: <true>
→ 3 failures
```

Both mutations were then reverted; the suites are green again (verified above).

## Not proven here

- ArkTS type-check and HAP build: **root's final gate**. `AgreementReader.ets`
  remains in the tree unregistered; it should compile but is no longer routed.
- No device run. No signing change. No `flutter build hap`.
- The packaged HAP on disk still reflects the pre-change manifest until root
  rebuilds; do not treat the existing `.hap` as evidence of this change.
