# Verification

## Confirmed Behavior

Editor imports remain registered on the home project list, as explicitly
confirmed by the user. Both detail import actions accept a custom filename,
write the current code, and open that file over a restored editor session.
New projects persist a custom runnable entry. Existing-project imports preserve
the entry and require confirmation before replacing a file with a backup.
Preparation, backup, registration, and I/O failures retain recoverable state.
Registry replacement preserves the prior JSON on denied writes. Other queued
saves cannot publish a pending registration, failure notifies the UI, and
refresh waits for the latest queued saves.

## Final Checks

Run from `D:/MyNewProjects/qfli_lua` with the installed Flutter OHOS SDK:

```powershell
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot analyze --no-pub
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot test --no-pub --reporter expanded --dart-define=CONTENT_SCREENSHOTS=true
```

- Full app analysis: no issues.
- Full app tests: 43 passed.
- Coverage includes real Lua files, custom entry execution, import races,
  backup failure, registry rollback/refresh/retry, navigation, replacement,
  actual-entry startup progress, and deferred-first-frame home rendering.
- The three added registry regressions failed before the persistence patch
  and passed after integration. Real Windows locking reproduced old JSON
  truncation; the other cases force a later save failure and a concurrent
  refresh, verifying disk state and the final listener state.

Run from `D:/MyNewProjects/qfli_studio_core`:

```powershell
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot analyze --no-pub lib test
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot test --no-pub --reporter expanded test/content_code_import_test.dart test/studio_profile_test.dart
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot test --no-pub --reporter expanded test/experience_test.dart --name '重复载入|云端目录合并|启动只等待'
```

- Production and test analysis: no issues.
- Content import and profile regression tests: 38 passed.
- Existing refresh, cloud-merge and bootstrap-failure regressions: 3 passed.
- Coverage includes real HomePage routes, both detail actions, saved example
  reload/reset, failure recovery, editor session selection, and 2x text at
  320px and 1280px widths.
- Both repositories' task-related tracked changes pass whitespace checks;
  core CRLF is checked with `core.whitespace=cr-at-eol`.

## Visual Evidence

Twelve captures are under `build/content-screenshots/`: tutorial/example
lists, details and import dialogs at 360x800 and 1280x900, refreshed on
2026-10-01 at 07:55:20-22. Inspected captures
show no clipped or overlapping controls. Widget layout checks also pass at
320px with twice-normal text.

## Startup Follow-Up

Source comparison against sibling `qflistudio` found matching native progress
and Flutter first-frame handling. Native FlutterPage retains its loading
surface until onFirstFrame, while the Lua entry waits for bootstrap and home
layout before allowing that frame. Channel/method/event names match and the
native listener is removed when its splash disappears.

Rechecked on 2026-10-02 during the native-platform audit: `Index.ets` has the
same SHA256 as the reference project's native page
(`A1D1D0F5340688964FE46EB5D34614303B7709EFAF951EF385574E868C0EE8CD`).
The packaged `ets/modules.abc` and current loader output both hash to
`09B128AB24D5590840CB395923804A258D6E884DD214AF64D32D38F42846E579`.
The installed FlutterPage dependency removes the native surface only in
`onFirstFrame`, rather than at progress completion. The later full app suite
also passes all 44 tests, including the actual-entry startup regression.

`test/startup_test.dart` calls the real entry and verifies engine-frame
deferral, progress `[1/3, 2/3, 1]`, prepared home before release, and home after
release. AppBootstrap failure recovery also passes in the core regression.

The final release arm64 HAP, including the registry changes, built successfully
in 105.4 seconds using DevEco JBR through process-local `JAVA_HOME`:

```powershell
$env:JAVA_HOME='D:/ProgramFiles/Huawei/DevEco Studio/jbr'
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot build hap --release --target-platform ohos-arm64 --no-pub
```

- Package: `build/ohos/hap/entry-default-signed.hap`.
- Modified: 2026-10-01 07:59:22; 37,453,284 bytes.
- SHA256: `278F7004E1E380F835ED1074D086C0F7AEFB96C48FB4D01ECF8E1B353916E390`.
- Compiled ArkTS: `ets/modules.abc`, 677,484 bytes.
- All four native libraries are under `libs/arm64-v8a/` and have ELF machine
  183 (AArch64): `libapp.so`, `libflutter.so`, `libqfli_lua.so`, and
  `libc++_shared.so`.
- Final cross-layer review found no new production/test defects. All twelve
  refreshed captures were inspected without clipped or overlapping controls.

## Wider Checks and Limits

- The earlier full shared-core run had 102 passing and 25 failing tests. It
  exposed the task harness failures repaired here, plus older language-folder,
  backup-count and activity-timer failures. The full suite was not repeated
  after these repairs; the final 38-test result plus three targeted experience
  regressions is the relevant subset.
- Full shared-core analysis also scans `vendor/re_editor/example`, whose
  package imports are unresolved, and vendor lint warnings. The successful
  final core analysis explicitly covers `lib` and `test`.
- No device connection, debugging, installation or restart was performed.
- No commit, archive or journal commit has been made. Commit scope requires
  confirmation because the feature uses parallel work not yet present in HEAD.
