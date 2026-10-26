# Pi p6 findings — report to root

Owner: Pi p6 (verification artifacts only).
Generated: 2026-10-22.
Scope of what I actually did: baseline catalog execution, OHOS SDK/native/HAP
inspection, device check, offline-profile + offered-language capability review,
sandbox surface measurement. **No product source edited. No commits. No Git
mutations. No full Flutter build.** Peer work preserved.

Read with:
`research/baseline-catalog-audit.md` (R1 baseline) and
`research/validation-platform-audit.md` (platform/runtime/offline).

## Blocking facts root needs now

1. **R1 baseline is captured and it invalidates the existing content count.**
   202 entries executed through bundled Lua 5.4.8 (`native/build/windows/libqfli_lua.dll`,
   SHA256 `3DFEEF04…006F11`, reports `Lua 5.4.8`). All 202 exit 0 and match the
   authored output once the trailing newline is ignored. But:
   - 100 examples = **1 code template**, only the seed constant changes
     (`{1,3,5}`→`weighted=22` … `{100,102,104}`→`weighted=616`).
   - 100 tutorials = the same template, 1 lesson each.
   - 24 advertised topics cycled 4–5× each. Titles promise 缓存/并发/日志 etc.;
     the code is a weighted sum every time.
   → The `ContentCatalogValidator.releaseMinimumPerType = 100` gate **passes on
   padded content**. Treat "100 per type" as satisfied-but-meaningless, not done.

2. **`inputFixtures` are not fixtures.** Every entry carries
   `{"case":"fixture-N","mode":"deterministic"}` and never a `stdin` key, and
   `_inputFixtures()` only feeds stdin for `stdin`/`input`. So no bundled entry
   ever receives stdin. (The engine *does* support it: I verified `input.txt` →
   `io.read` works.) If expansion is meant to test fixtures, the schema usage has
   to change, not just the values.

3. **Nothing in the product verifies `expectedOutput`.** It is display-only
   (`local_content_adapter.dart:81` → `local_content_pages.dart:401,510`). The
   202/202 agreement is my harness, not a product guarantee. There is no CI-style
   content verifier in the app. Consider making the verifier a shipped gate so
   expansion cannot silently drift.

4. **300 of the 400 offered examples and 300 of the 400 offered tutorials cannot
   run on OHOS.** The `script` profile offers `{lua, javascript, typescript,
   shell}`; only Lua has a bundled runtime. `lib/lua_runner.dart` itself
   short-circuits with `if (!Platform.isWindows && !Platform.isLinux &&
   !Platform.isMacOS) return _notReady(...)` for the other three. Exact ids:
   `javascript-example-001…100`, `typescript-example-001…100`,
   `shell-example-001…100` (+ matching tutorials). Either drop those languages
   from this product or bundle a runtime. This is the concrete R5/R11 answer.

5. **Host `shell` runner is broken on Windows (real bug).** `_commandFor('.sh')`
   picks `powershell -File <script>`; verified failure
   `does not have a '.ps1' extension` (exit −196608). The 100 shell examples are
   valid POSIX sh and pass 100/100 under `Git\bin\sh.exe`. `typescript` has no
   host runtime at all (`where deno/tsx/ts-node` → exit 1). `javascript` passes
   100/100 on node v24.15.0.

## Sandbox surface (measured, R7/R11 input)

Real scripts through the bundled engine:
`os.execute` **spawns processes**, `io.popen` **works**, `os.getenv` exposes
`PATH`/`USERPROFILE`, `package.loadlib` present. Relative `io.open`/`dofile`/
`require`/`os.remove` are confined to the project dir, but **an absolute
`io.open` path escapes it** (wrote and re-read `%TEMP%\qfli_lua_escape_probe.txt`).
`qfli_lua.c` wraps only `io.open/input/output/lines`, `os.remove/rename`,
`loadfile/dofile`, and `push_project_file` deliberately passes absolute paths
through. The ARM64 build adds `-DLUA_USE_POSIX` (→ `LUA_USE_POPEN`) and the `.so`
contains `popen`/`system`, so this is expected on device too — **inference from
the artifact, not device execution.**

## Platform evidence (all host/package tier)

- **No device:** `hdc list targets` → `[Empty]`; `adb devices` → empty. Nothing is
  device-verified. Host ≠ device.
- **SDK:** `DEVECO_SDK_HOME` → DevEco `sdk`, compile SDK `26.0.0.105` (API 26).
  Product declares compatible 18 / target 24 / compile 26. Separate
  `OpenHarmony\Sdk\{20,23}` holds hdc 3.2.0c.
- **Native:** genuine cross-compile — `clang --target=aarch64-linux-ohos` + OHOS
  sysroot, `arm64-v8a` only, ELF64 `e_machine 0x00B7`. Exports match
  `qfli_lua.h` exactly. (`qfli_lua_script_exit` in an ASCII scan is the Lua
  sentinel `#define`, not an export.)
- **HAP:** `entry-default-signed.hap`, 120,763,877 B, 2026-10-18 23:52,
  `buildMode: debug` (not release), `com.azurekiln.qfli.script`, single ABI.
  Shipped `examples.json`/`tutorials.json` are **byte-identical** to the core repo
  (SHA256 match) → the package carries exactly the template content above.
- **Host lib provenance:** `native/build/windows/libqfli_lua.dll` 1,033,968 B,
  2026-10-03 02:00:52, MinGW64 gcc, `MinGW Makefiles`, **Debug**. Existing test
  binary `qfli_lua_test.exe` re-run by me just now → **exit 0, pass** (real suite:
  check/compile/run source/run bytecode/io capture/path redirect/loadfile env/
  stdin/syntax error). I did not rebuild.
- **Skipped by design:** no `cmake` build/CTest regeneration (a `cmake` process and
  `flutter_tester` were live → source/build writer peer active); no `flutter test`
  or `flutter build hap` (Flutter/SDK locks must be reserved through root).

## R11 nuance worth a decision

Dart is genuinely offline-gated (cloud/community/AI/login/ICP/online-run all
`offlineOnly`-guarded; `agreement_config.dart` URLs empty). But the OHOS ability
still declares `ohos.permission.INTERNET`, wires a `qflistudio/huawei_account`
Account Kit login channel, ships an HTTPS `Web()` AgreementReader, and carries
`client_id: "REPLACE_WITH_AGC_CLIENT_ID"`. No reachable networked UI path was
found, but the capability ships. Decide: strip INTERNET + login channel, or
document why they stay.

## Late-breaking: shipped artifacts are now stale vs `native/src`

A peer (p7) is actively adding `qfli_lua_copyright()` and an argv-aware run API to
`native/src/qfli_lua.h` + `.c` (+143 uncommitted lines). So:
- My ABI/export statement describes the **built artifacts** (ARM64 `.so`
  2026-10-18, host DLL 2026-10-03) and remains accurate for *those* files.
- `native/src` now exports **more** than either artifact. The host DLL and the HAP
  are stale relative to source.
- After p7's change lands, the host DLL, the ARM64 `.so` and the HAP must all be
  rebuilt before any of my numbers count as current engine proof again.

## What I could not prove

On-device execution of any entry; `os.execute`/`io.popen` on HarmonyOS; `hdc
install` of this debug HAP; current `flutter test` results; any post-expansion
content (peers were mid-generation — `assets/content/lua_examples.json`,
`lua_tutorials.json`, `tool/lua_content/topics_*.dart` were appearing while I
audited).

## Peer activity observed (do not disturb)

At 10:24–10:31 local: p3 writing `tool/lua_content/*`, `tool/generate_lua_content.dart`,
`tool/verify_lua_content.dart`, `assets/content/lua_{examples,tutorials}.json`;
p5 writing `lib/lua_tools.dart`, `lib/lua_tools_page.dart`,
`lib/lua_content_repository.dart`, `test/lua_tools_test.dart`. Three
`flutter_tester` processes live → Flutter test runs in progress. I touched none of
these.

## Reproduce

```powershell
dart run build/offline-ide-audit/lua_baseline_audit.dart `
  --library native/build/windows/libqfli_lua.dll `
  --examples ../qfli_studio_core/assets/content/examples.json `
  --tutorials ../qfli_studio_core/assets/content/tutorials.json `
  --legacy ../qfli_studio_core/assets/tutorials/lua.json `
  --out build/offline-ide-audit/lua-baseline-report.json

dart run build/offline-ide-audit/lua_sandbox_probe.dart `
  --library native/build/windows/libqfli_lua.dll `
  --out build/offline-ide-audit/lua-sandbox-probe.json
```
