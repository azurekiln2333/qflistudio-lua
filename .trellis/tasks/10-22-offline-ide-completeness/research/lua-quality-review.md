# Independent Lua review — 2026-10-22

Reviewer: `lua_review` (`trellis-check`). No shared core, product card, content
generator, OHOS configuration, device, commit or push changes. Root retains the
whole-product/platform gates. Native source ownership and the Flutter test window
were explicitly released to root and `runtime_review` after the checks below.

## Fixed findings

1. **Project temporary storage:** upstream `os.tmpname`/`io.tmpfile` relied on
   process-global temporary storage, which is unavailable in the reported OHOS
   sandbox. The bridge now replaces both functions for normal Run and debugger
   states, without editing vendored Lua. It resolves an absolute project root
   and exclusively creates unique `.qfli_tmp_*` files there. POSIX uses
   `open(O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC, 0600)`; Windows uses UTF-8 to wide
   path conversion and `_wopen` with exclusive creation/noninheritance. No global
   temp directory fallback or process `chdir` exists. `os.tmpname` leaves its
   empty precreated file for the caller. `io.tmpfile` retains its absolute path
   in the file userdata and removes it on close, GC or VM shutdown, including
   cancellation. Unavailable project storage produces actual Lua errors.

2. **Suspended debugger cleanup:** a new regression test demonstrated that
   `lua_close(main_state)` alone omits `<close>` locals on the paused root
   coroutine. `debug_close_vm` now disables its hook, calls `lua_closethread`
   before destroying the state, captures new close failures without duplicating
   the original runtime error, and only then exposes output. Cancellation remains
   status130 and the unexecuted source line stays unexecuted. Close output with
   embedded NUL is preserved. Finalizer `os.exit` now propagates its actual status
   consistently with normal Run.

Changed implementation: `native/src/qfli_lua.c`,
`native/src/qfli_lua_windows.c/.h`. Added native assertions in
`native/test/qfli_lua_test.c`; added `test/lua_tempfile_test.dart` and two debugger
regressions in `test/lua_debugger_test.dart`.

## Review outcome and limits

- The diagnostic adapter uses actual unsaved text and the frozen core API,
  preserves UTF-16 offsets/CRLF/BOM/shebang mapping, performs no execution or
  source writes, and distinguishes parser unavailability from clean syntax.
  Its19 real-library cases pass; no adapter change was needed.
- Existing debugger ownership and command revision guards were reviewed. No
  further demonstrated lifecycle defect was found within this review window.
- Accepted debugger restrictions remain: source-only saved main file; user
  coroutine/hook replacement rejected; primitive bounded inspection only;
  require/native callback stops deferred with warning. These are visible product
  limits rather than claims of full Lua debugger coverage.
- Content review identified the already assigned `math.random(0)` teaching,
  timezone-dependent date/time output and tmpname-precreation issues. Root owns
  those generator corrections and catalog regeneration/reverification. This
  report does not assert a fresh full catalog pass.
- Host tests do not establish OHOS/Apple/POSIX build or runtime success. Root
  must rebuild the package and execute the target-side temp/debugger probes.

## Verification

From `D:/MyNewProjects/qfli_lua`, after rebuilding the default current DLL:

```powershell
& 'D:/ProgramData/Android/Sdk/cmake/3.22.1/bin/cmake.exe' --build native/build/windows --parallel 2
& 'D:/ProgramData/Android/Sdk/cmake/3.22.1/bin/ctest.exe' --test-dir native/build/windows --output-on-failure
# Build succeeds; CTest1/1 passes.

& 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe' 'D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 test/lua_tempfile_test.dart test/lua_debugger_test.dart test/lua_debugger_page_test.dart test/lua_code_analyzer_test.dart
#41/41 pass: temp5, debugger14, debugger page3, analyzer19.

& 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe' analyze lib/lua_debugger.dart lib/lua_debugger_page.dart lib/lua_code_analyzer.dart test/lua_tempfile_test.dart test/lua_debugger_test.dart test/lua_debugger_page_test.dart test/lua_code_analyzer_test.dart
# No issues found (lint and type checking).
```

`gcc -std=c11 -Wall -Wextra -Werror -fsyntax-only` passes separately for the
bridge (with the existing Windows forced header), Windows helper and native
test. `git diff --check` on the owned native files passes (only existing
line-ending-conversion notices). Dart format passes for both changed tests.

The temp regression proves256 distinct precreated files across four real
concurrent VM isolates under a Unicode/emoji project, explicit close/GC/state
shutdown cleanup, unavailable storage errors, running cancellation cleanup and
debugger paused-stop cleanup with exact binary output.

## Spec synchronization for root

Update `.trellis/spec/backend/lua-toolchain.md` with project-owned temporary
storage, the additive debugger API/accepted restrictions, and explicit
`lua_closethread` before main-state destruction. Root also needs to reconcile its
separate OHOS emulator-ABI policy changes. No spec was silently rewritten by
this reviewer while root coordinates that work.
