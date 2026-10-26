# Runtime and debugger review — 2026-10-22

Dispatched reviewer: runtime_review. Root authorized the genuine debugger extension after the original terminal review. No commits/pushes, no shared core edits, no main/pubspec/tools-card edits. Native ownership released to root after checks.

## Changes and fixed findings

- `lib/lua_toolchain.dart`, `lib/lua_terminal_commands.dart`: fixed the two curly-brace lint findings. Shared embedded loader is exposed additively through `LuaToolchain.openNativeLibrary()` for debugger reuse; original run/check/compile behavior and FFI result lengths retained.
- `test/lua_terminal_commands_test.dart`: parenthesized the real Lua5.4 require call when asserting one return value. Shared SandboxShellBackend intentionally reports null lastExitCode after user interruption (core sandbox_terminal_test already asserts that); a recording wrapper observes the unchanged real native execution and proves status130, cancelled diagnostic, idle backend and next-command recovery.
- `native/src/qfli_lua.c/.h`: additive cooperative source-debugger API, one VM/root coroutine per session, line/count yielding hooks, real breakpoint and step depth checks, active execution budget excluding pause, atomic-only pause/stop, exact output byte copies and bounded primitive inspection. Stop while paused checks cancellation before resume so the pending source line never executes. Errors retain space even when stderr fills. A request inside a non-yieldable callback is retained and explicitly diagnosed before pausing at the next resumable instruction. Existing C ABI/upstream Lua/stdin/Unicode changes preserved.
- `lib/lua_debugger.dart`: persistent worker isolate owns every VM operation except atomic requests, explicit lifecycle/disposal handshake avoids control-pointer races, command revision guards prevent a delayed breakpoint acknowledgement from overwriting running state, absolute normalized root-owned source/breakpoint paths, no evaluation/metamethod inspection.
- `lib/lua_debugger_page.dart`: individual Tools page (`LuaDebuggerPage(store: store)`, title/summary constants; optional projectPath/initialFile/libraryPath), saved-source choice, real controls, source breakpoint gutter/current line, frame selection/locals/output. Narrow controls wrap. Per-session source preview cache and selection/source generations prevent new or stale disk reads from changing paused source unexpectedly. New session clears old terminal status/output. Failed breakpoint updates roll back the marker.
- New `test/lua_debugger_test.dart` (12 real-library tests) and `test/lua_debugger_page_test.dart` (3 real-widget/library tests). Native CTest includes a direct debugger ABI pause/local/breakpoint/stop assertion.

## Final verification

All commands run from `D:/MyNewProjects/qfli_lua`:

```powershell
& 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe' analyze lib/lua_debugger.dart lib/lua_debugger_page.dart lib/lua_terminal_commands.dart lib/lua_toolchain.dart lib/lua_runner.dart test/lua_debugger_test.dart test/lua_debugger_page_test.dart test/lua_terminal_commands_test.dart test/lua_runner_shell_test.dart
# No issues found.

& 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe' 'D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 test/lua_debugger_test.dart test/lua_debugger_page_test.dart test/lua_terminal_commands_test.dart test/lua_runner_shell_test.dart
# 28/28 passed. Subsequent page-only rerun after final stale-output cleanup:3/3 passed.

& 'D:/ProgramData/Android/Sdk/cmake/3.22.1/bin/cmake.exe' --build native/build/windows --parallel 2
& 'D:/ProgramData/Android/Sdk/cmake/3.22.1/bin/ctest.exe' --test-dir native/build/windows --output-on-failure
# Rebuilt default DLL, CTest1/1 passed (0.06s).
# DLL native/build/windows/libqfli_lua.dll:1,049,757 bytes,2026-10-22 18:17:22 local.

& 'D:/ProgramFiles/Dev-Cpp/MinGW64/bin/gcc.exe' '-std=c11' '-Wall' '-Wextra' '-Werror' '-fsyntax-only' '-include' 'native/src/qfli_lua_windows.h' '-Inative/src' '-Inative/third_party/lua-5.4.8/src' 'native/src/qfli_lua.c'
& 'D:/ProgramFiles/Dev-Cpp/MinGW64/bin/gcc.exe' '-std=c11' '-Wall' '-Wextra' '-Werror' '-fsyntax-only' '-Inative/src' 'native/test/qfli_lua_test.c'
# Both pass, no diagnostics.
```

Assertions cover true argv/negative indexes/100 argument stack expansion, source-buffer embedded NUL and no execution, luac source/bytecode parse+strip+run after source deletion, Unicode input/modules/paths, runtime stderr/status, timeouts, cancellation and recovery; debugger pre-execution stop, nesting into/over/out, actual locals without __tostring, pause/stop running and paused, paused time exclusion, source/runtime failures/EOF/explicit exit, rejected coroutine/hook/binary operations, module function stops and initialization deferral, acknowledgement race,360px layout/actions and native unavailability.

## Honest limits / root integration gates

- User coroutine create/resume/wrap/yield and replacing the hook are explicitly rejected only in debugger mode; normal Run remains unchanged. Main debug entry must be `.lua` text within its project. Primitive locals only; no eval/watch mutation.64 frames/128 locals/4096-byte displayed strings; source preview512KiB/2000 lines.
- Non-yieldable native callbacks, including require module initialization, cannot pause at their internal line with this coroutine design. Native emits an explicit deferral diagnostic and pauses at the next resumable Lua instruction. Module functions invoked later from Lua can stop normally and are tested. Native I/O/finalizers remain cooperative; stripped/generated chunks may lack source lines. UI states these limits.
- Root owns adding the separate Tools card, whole-product tests/spec synchronization/commit. Native target packaging and device runtime are separate proof gates; host checks do not prove OHOS execution.
- New export inspection list for rebuilt packages: qfli_lua_copyright,qfli_lua_run_with_argv,qfli_lua_check_source,qfli_lua_compile_ex; qfli_lua_debug_new/resume/pause/stop/set_breakpoints/state/output/frame/local/free.
- `research/runtime-design.md` contains the approved coroutine implementation design appended after the earlier OS-condition proposal. Sync backend spec to the actual additive API and limitations.
