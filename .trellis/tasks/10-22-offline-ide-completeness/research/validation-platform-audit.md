# Platform / runtime / offline-capability verification — Lua (Pi p6)

Owner: Pi p6 (verification artifacts only, no product source edits).
Generated: 2026-10-22.
Machine-readable evidence:
`build/offline-ide-audit/lua-baseline-report.json`,
`build/offline-ide-audit/lua-sandbox-probe.json`,
`build/offline-ide-audit/lua-examples-baseline.json`.

## 1. Device availability — none

| Check | Command | Result |
| --- | --- | --- |
| HarmonyOS target | `hdc list targets` (hdc 3.2.0c) | `[Empty]` |
| Android target | `adb devices` | `List of devices attached` (empty) |

**Direct consequence:** no claim in this task is device-verified. Everything below
is host execution, cross-compiled artifact inspection, or package inspection.
Per the brief, host checks are not device proof; R1/R7/R11 target evidence stays
open until a device is connected.

## 2. OHOS SDK

| Item | Value |
| --- | --- |
| `DEVECO_SDK_HOME` | `D:\ProgramFiles\Huawei\DevEco Studio\sdk` |
| Compile SDK used by the HAP | `26.0.0.105` (API 26, `Release`) |
| SDK root contents | `default/{hms,openharmony}` + `licenses` |
| `openharmony/*/oh-uni-package.json` | `apiVersion: 26`, `version: 26.0.0.105` for `ets`/`js`/`native`/`previewer`/`toolchains` |
| Separate toolchain SDK | `D:\ProgramFiles\Huawei\OpenHarmony\Sdk\{20,23}` (hdc lives here, 3.2.0c) |
| `ohos/local.properties` | `hwsdk.dir=D:\\ProgramFiles\\Huawei\\DevEco Studio\\sdk`, `flutter.sdk=D:\\ProgramFiles\\flutter_ohos` |
| Product config | `compatibleSdkVersion 5.1.0(18)`, `targetSdkVersion 6.1.1(24)`, `runtimeOS: HarmonyOS` |
| ohpm lock | `ohos/oh-package-lock.json5` present, `lockfileVersion 3`, single `@ohos/hypium@1.0.6` with integrity + shasum |

Note the API spread: `compatibleSdkVersion 18`, `targetSdkVersion 24`,
`compileSdkVersion 26`. Both SDK trees (26 under DevEco, 20/23 under
OpenHarmony) coexist; nothing here proves a store-submission-ready SDK alignment.

## 3. Native build (ARM64 cross-compile) — genuinely cross-compiled

| Item | Value |
| --- | --- |
| CMake entry | `ohos/entry/src/main/cpp/CMakeLists.txt` → `add_subdirectory(.../native)` |
| abiFilters | `arm64-v8a` only; `nativeLib.filter.excludes` removes `x86_64/**`, `armeabi-v7a/**` |
| Compiler | `.../DevEco Studio/sdk/default/openharmony/native/llvm/bin/clang.exe` |
| Target triple | `--target=aarch64-linux-ohos` |
| System root | `.../openharmony/native/sysroot` |
| Defines | `-DLUA_COMPAT_5_3 -DLUA_USE_DLOPEN -DLUA_USE_POSIX` |
| ELF verification | `libqfli_lua.so` → ELF64, little-endian, `ET_DYN`, `e_machine 0x00B7` (AArch64) |
| Exported API | `qfli_lua_version`, `qfli_lua_run`, `qfli_lua_run_with_token`, `qfli_lua_check`, `qfli_lua_compile`, `qfli_lua_free`, `qfli_lua_token_new/_cancel/_free` — exactly matches `native/src/qfli_lua.h` |
| Source vs artifact at audit time | native `src/*.c|h` mtime 2026-10-03 01:59:27; ARM64 `.so` built 2026-10-18 23:51:56 → artifact newer than sources |

(`qfli_lua_script_exit` also appears in a raw ASCII scan; it is the
`#define EXIT_SENTINEL "qfli_lua_script_exit"` Lua sentinel string, **not** an
exported function. Not an ABI discrepancy.)

**Correction (2026-10-22 10:34):** the native source has since diverged from both
shipped artifacts. A peer (p7, terminal/toolchain owner) is actively adding
`qfli_lua_copyright()` and a new argv-aware run API to `native/src/qfli_lua.h`
(+143 lines across `.h`/`.c`, currently uncommitted). Consequences:

- The ABI statement above describes the **built artifacts only** (ARM64 `.so`
  2026-10-18, host DLL 2026-10-03). The current source exports more than they do.
- The HAP and the host DLL are now **stale** relative to `native/src`. Any
  verification run against the existing DLL/HAP exercises the old engine surface.
- My decision not to rebuild was correct and is now doubly justified: rebuilding
  would have collided with that active writer.
- Whoever lands p7's native change must rebuild the host DLL **and** the ARM64
  `.so`/HAP before any of my numbers are treated as current again.

I did **not** rebuild native this session: a `cmake` process and `flutter_tester`
were live at 2026-10-22 10:28, i.e. a source/build writer peer was active and the
shared `native/build/windows` tree was off-limits per the brief.

## 4. HAP package inspection

| Item | Value |
| --- | --- |
| Path | `ohos/entry/build/default/outputs/default/entry-default-signed.hap` |
| Size / mtime | 120,763,877 bytes, 2026-10-18 23:52:02 |
| `buildMode` | `debug` (`app.debug: true`) — **not** a release package |
| bundleName | `com.azurekiln.qfli.script` |
| deviceTypes | `phone`, `2in1`, `tablet` |
| ABIs shipped | `libs/arm64-v8a/{libqfli_lua.so, libflutter.so, libc++_shared.so}` — single ABI, matches filter |
| Lua assets | `resources/rawfile/flutter_assets/packages/qfli_studio_core/assets/content/{examples,tutorials}.json` |
| Lua `.so` in HAP | 407,368 bytes (stripped) vs 935,440 bytes unstripped intermediate |

**Content shipping check (SHA256, byte identical to the core repo):**

| File | core repo | HAP rawfile | Same |
| --- | --- | --- | --- |
| `examples.json` | `8D6B3338…678986C9` | `8D6B3338…678986C9` | yes |
| `tutorials.json` | `EAD9A068…6AFD5672` | `EAD9A068…6AFD5672` | yes |

So the shipped package contains exactly the baseline content audited in
`research/baseline-catalog-audit.md` — the 100-template examples and 100-template
tutorials — and a working ARM64 Lua 5.4.8. The package is stale relative to any
post-baseline content expansion (no expansion exists yet at audit time).

## 5. Host library provenance (no rebuild performed)

| Item | Value |
| --- | --- |
| Path | `native/build/windows/libqfli_lua.dll` |
| Size / mtime | 1,033,968 bytes, 2026-10-03 02:00:52 |
| SHA256 | `3DFEEF048A82F8F093971B4818EE3169B4E39C58BADF4FCC7CB1C9A969006F11` |
| Compiler | `D:/ProgramFiles/Dev-Cpp/MinGW64/bin/gcc.exe` |
| Generator / config | `MinGW Makefiles`, `CMAKE_BUILD_TYPE=Debug` |
| `qfli_lua_version()` | `Lua 5.4.8` |
| Last recorded CTest | `Testing/Temporary/LastTest.log`, 2026-10-17 15:50, `qfli_lua_test` **Passed** (a prior run, not mine) |

The DLL is newer than the native sources, so it is current with respect to them.
It is a **Debug** MinGW build; the ARM64 `.so` is the Release cross-build. Two
different build configurations back the two evidence tiers.

## 6. Sandbox surface — measured, not assumed (R7/R11 input)

`build/offline-ide-audit/lua_sandbox_probe.dart` executed real scripts through
the bundled engine. Results:

| Capability | Host result | Meaning |
| --- | --- | --- |
| `os.execute("echo …")` | **works** — prints `spawned-by-lua`, returns `true, exit, 0` | a user script can spawn host processes |
| `io.popen("echo …")` | **works** — reads `popen-by-lua` | popen pipe is open |
| `os.getenv` | `PATH` and `USERPROFILE` visible | full environment exposure |
| `package.loadlib` / `package.searchers` | present (function / table) | native module loading path exists |
| `io.open("rel")` | resolves **inside** project dir | relative-path confinement works |
| `io.open(<absolute>)` | **escapes** — wrote and re-read `%TEMP%\qfli_lua_escape_probe.txt` | absolute paths bypass the project wrapper |
| `dofile("helper.lua")` | `42` under project dir | project-relative loading works |
| `require("mod_a")` | `{value=7}` from project dir | `package.path` project prefix works |
| `os.remove("temp.txt")` | removed inside project dir | project-relative mutation works |
| `os.stdin` / `input.txt` | `io.read` returns the `input.txt` contents | fixture wiring works |

`qfli_lua.c` wraps `io.open/input/output/lines`, `os.remove/rename`,
`loadfile/dofile` to prefix the project dir, but does **not** touch `os.execute`,
`io.popen`, `os.getenv`, or `package.loadlib`. `push_project_file` deliberately
passes absolute paths through unchanged, which is why absolute escape works.

**OHOS parity:** the ARM64 build compiles with `-DLUA_USE_POSIX`, and
`luaconf.h` maps that to `LUA_USE_POPEN`; the ARM64 `.so` contains `popen` and
`system` symbols. So `os.execute`/`io.popen` are expected to exist on device too.
**This is inference from the artifact, not device execution** — it needs a device
run to be a proven claim.

## 7. Offline profile vs offered languages — exactly which entries cannot run (R11/R5)

`lib/main.dart` sets `isOffline: true` (and `offlineOnly` defaults to it), so the
Dart UI gates cloud projects, community, AI, login, ICP footer and the online-run
path. Verified gating sites include `home_page.dart:105,312,775`,
`profile_page.dart:49,86,110-241`, `editor_page.dart:203,1001,1092,1895`,
`task_activity_service.dart:232-342`, `about_page.dart:24`.

However the profile offers **four** content types via
`contentProductKey: 'script'` → `ContentProductTypes.byProduct['script'] =
{lua, javascript, typescript, shell}`, and `ProjectTemplate` adds javascript,
typescript and shell templates. The bundled content ships 100 entries of each:

| Type | Examples offered | Tutorials offered | Runtime on OHOS | Runtime on this Windows host |
| --- | --- | --- | --- | --- |
| `lua` | 100 | 100 | **yes** — bundled `libqfli_lua.so` | **yes** — 100/100 pass |
| `javascript` | 100 | 100 | **no** — `LuaProgramRunner` only spawns host `node`/`deno`; no JS engine is bundled | **yes** — `node v24.15.0`, 100/100 pass |
| `typescript` | 100 | 100 | **no** — same host-process path | **no** — `where deno/tsx/ts-node` all exit 1 |
| `shell` | 100 | 100 | **no** — host-process path only | **broken** — see below |

`lib/lua_runner.dart` decides this explicitly: `.js/.mjs/.ts/.sh` fall through to
`_commandFor()` which runs `where`/`which` and then `ProcessSupervisor`. It even
short-circuits with `if (!Platform.isWindows && !Platform.isLinux &&
!Platform.isMacOS) return _notReady(...)` — i.e. **the product itself knows**
these languages have no runtime on mobile.

**Exactly 300 of the 400 offered examples and 300 of the 400 offered tutorials
therefore cannot execute on OHOS**: `javascript` ×100, `typescript` ×100,
`shell` ×100 (ids `javascript-example-001…100`, `typescript-example-001…100`,
`shell-example-001…100` and the matching `*-tutorial-001…100`). Lua's 100 + 100
are the only OHOS-runnable content in this product.

This is the concrete, enumerable answer to "identify unsupported examples
exactly": every `javascript`/`typescript`/`shell` entry in
`packages/qfli_studio_core/assets/content/{examples,tutorials}.json` for this
product is unrunnable on OHOS. Either the profile should stop offering those
three languages (and stop shipping 300 dead entries), or a real bundled runtime
must be added. Today the UI shows them as first-class, runnable content.

### Host-side defect found while checking `shell` (real bug, not OHOS)

On Windows `_commandFor('.sh')` selects `powershell -NoProfile -ExecutionPolicy
Bypass -File <script>`. Verified failure:

```
Processing -File '…\main.sh' failed because the file does not have a '.ps1'
extension.        (exit -196608)
```

The 100 `shell` examples are valid POSIX sh — run under `D:\ProgramFiles\Git\bin\sh.exe`
they pass **100/100** — but the runner can never launch them on Windows. So
`shell` content is unrunnable on both tiers, for two different reasons.

### Content-quality cross-check on the non-Lua types

The same generator flaw found for Lua applies to the other three: each type has
100 distinct code strings but 1 template, with the seed number changed.

- `javascript`: `const values = [1,3,5]` … `console.log("weighted=" + weighted)` → `weighted=22`
- `typescript`: identical with `: number[]` → `weighted=22`
- `shell`: `weighted=22` / `printf "weighted=%s\n"` → `weighted=22`

`LuaProgramRunner` host execution for javascript: **100/100 pass** on node
v24.15.0; shell under git sh: **100/100 pass**. Their outputs are correct, their
subject matter is still one rewritten template.

## 8. OHOS shell network surface (R11 nuance)

The Dart layer is offline-gated, but the OHOS ability is not network-free:

- `ohos/entry/src/main/module.json5` requests `ohos.permission.INTERNET` and
  `ohos.permission.READ_PASTEBOARD`; the HAP `module.json` confirms both.
- `EntryAbility.ets` registers a `qflistudio/huawei_account` channel that calls
  Account Kit `AuthenticationController.executeRequest` (needs the network).
- `EntryAbility.ets` registers `openAgreement` → `pages/AgreementReader`, which is
  a `Web({ src: <https url> })` component that genuinely loads HTTPS.
- Ability metadata carries `client_id: "REPLACE_WITH_AGC_CLIENT_ID"`.

Reachability from the offline profile, verified: the ICP/agreement footer is
gated (`profile_page.dart` `if (!offlineOnly) _icpFooter()`), login/community/AI
are gated, and `openUrl` is only reached from the "run online preview" path which
is gated by `offlineOnly != true`. `agreement_config.dart` also currently has
empty `userAgreementUrl`. So no *reachable* networked UI path was found in the
offline profile — but the permission, the login channel and the HTTPS Web page are
all still compiled into the shipped package. That is a capability the offline
product declares without using it, which is worth an explicit decision (drop
INTERNET + the login channel, or document why they stay).

## 9. Tool failures and limits actually encountered

- `cmake` is not on `PATH` anywhere I searched; the only working native build is
  the pre-existing `native/build/windows` (MinGW) tree. I did not rebuild it.
- No `hdc`/`adb` device. No OHOS emulator started (out of scope, and no device
  runtime was reserved with root).
- First two runs of my audit harness failed to compile (`Utf8` is not in
  `dart:ffi`; my blind text replace then broke `utf8.decode`). Fixed by using
  `package:ffi`; both harnesses now run clean. Recorded here so the failure is not
  mistaken for a product problem.
- I did not run `flutter test`, `flutter build hap`, or CTest: peers were actively
  holding `flutter_tester` and `cmake` at audit time, and the brief requires
  reserving Flutter/SDK locks through root first.

## 10. What is still unproven

1. Any OHOS on-device execution of even one Lua entry.
2. `os.execute`/`io.popen` behaviour on HarmonyOS (present in the ARM64 artifact,
   not executed there).
3. Whether `hdc install` of this debug HAP succeeds (no device, and it is a debug
   build signed with the local debug config, not a release identity).
4. Whether the eight `flutter test` suites pass right now (peer activity).
5. Post-expansion content: nothing exists yet, so the R2 ">100 additions" and
   "240 paired topics" targets are unmet at the time of writing.
