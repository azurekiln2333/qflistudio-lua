# Peer review — Pi p7 (runtime/terminal), READ-ONLY handover

Date: 2026-10-22. Reviewer role: Pi p7, now read-only per coordination instruction.
Ownership: Lua terminal/toolchain + native bridge. I have stopped all source/test writes.
No commits, no pushes, no reverts. This file is my only write.

Say plainly: my earlier turn produced broken Dart (analyzer errors) and I did not get to
running a terminal test. A native worker has since rewritten `lib/lua_terminal_commands.dart`
and `lib/lua_toolchain.dart` in place (timestamps 11:13:46) and extended the native bridge
(11:08:39). Everything below describes the **current on-disk state**, not my superseded draft.

---

## 1. What exists now

### Files in my ownership scope

| File | State | Provenance |
|---|---|---|
| `lib/lua_terminal_commands.dart` | 313 lines, 9,529 B, 11:13:46 | rewritten by native takeover |
| `lib/lua_toolchain.dart` | 13,245 B, 11:13:46 | takeover extended my draft |
| `native/src/qfli_lua.h` | 3,230 B, 11:08:39 | my additions + takeover additions |
| `native/src/qfli_lua.c` | 22,988 B, 11:08:39 | my additions + takeover additions |
| `native/test/qfli_lua_test.c` | 14,128 B, **10:35:34 — NOT updated by takeover** | my additions only |
| `lib/lua_runner.dart` | unchanged by me (pre-existing peer edits only) | another owner |

Untracked (new): `lib/lua_terminal_commands.dart`. Tracked-modified: `lib/lua_toolchain.dart`,
`native/src/qfli_lua.c`, `native/src/qfli_lua.h`, `native/test/qfli_lua_test.c`.

**No test file for the terminal delegate exists.** `test/` contains `lua_app_test.dart`,
`lua_editor_tools_test.dart`, `lua_offline_platform_test.dart`, `lua_tools_page_test.dart`,
`lua_tools_test.dart`, `code_import_service_test.dart`, `content_import_workflow_test.dart`,
`startup_test.dart`. Nothing imports `lua_terminal_commands.dart`. This is the largest
acceptance gap for R7 (real offline terminal with execution evidence).

### Exported C ABI (all `QFLI_API`, checked in `native/src/qfli_lua.h`)

Pre-existing (ABI unchanged, unchanged signatures):
`qfli_lua_version`, `qfli_lua_run`, `qfli_lua_run_with_token`, `qfli_lua_token_new`,
`qfli_lua_token_cancel`, `qfli_lua_token_free`, `qfli_lua_check`, `qfli_lua_compile`,
`qfli_lua_free`.

Additive (new):
- `const char *qfli_lua_copyright(void)` — returns `LUA_COPYRIGHT`, so `lua -v` prints the
  real upstream banner (`Lua 5.4.8  Copyright (C) 1994-2025 Lua.org, PUC-Rio`).
- `QfliLuaResult *qfli_lua_run_with_argv(const char *file, const char *project_dir, int timeout_ms, const char *const *argv, int argv_count, int script_index, QfliLuaCancelToken *token)`
  — builds `arg` exactly like upstream `createargtable()` (`arg[i - script_index] = argv[i]`)
  and passes tokens after `script_index` as chunk varargs. `argv == NULL` reproduces the old
  `arg[0] = file`, no-varargs shape; `qfli_lua_run_with_token` now forwards to it, so the
  existing behaviour is preserved by construction.
- `QfliLuaResult *qfli_lua_check_source(const char *source, size_t length, const char *chunk_name)`
  — parse an unsaved buffer (added by takeover; intended for editor diagnostics).
- `QfliLuaResult *qfli_lua_compile_ex(const char *file, const char *output_file, int strip)`
  — `lua_dump` with the strip flag (added by takeover; backs `luac -s`).

### Dart API

`LuaToolchain` (all additive; `run`/`startRun`/`check`/`compile`/`version` keep working):
- `run(..., List<String> commandLine = const [], int scriptIndex = 1)`
- `startRun(..., List<String> commandLine = const [], int scriptIndex = 1)`; throws
  `ArgumentError` when `scriptIndex` does not index `commandLine`, and rejects NUL in paths
  and arguments.
- `copyright()` — guarded lookup of `qfli_lua_copyright`, falls back to `version()`.
- `supportsCommandLine` — guarded lookup of `qfli_lua_run_with_argv`; lets a caller refuse
  honestly instead of silently dropping script arguments on an older packaged library.
- `checkSource(source, {chunkName})` → `qfli_lua_check_source`.
- `load(file, {outputFile, stripDebug})` → `qfli_lua_compile_ex`.

`luaTerminalCommandDelegate(SandboxShellBackend, String) → Future<bool>` and
`class LuaTerminalDelegate({toolchain, timeLimit})` in `lua_terminal_commands.dart`.

---

## 2. Current behaviour of the terminal delegate (read from source)

Classification uses `backend.escapePolicy` (i.e. `EscapePolicy.backslashLiteral`), so
classification and tokenization agree and `C:\dir` survives. Compound/empty/unparseable lines
return `false` and stay with the shared backend. Tool match is `lua`/`lua.exe`/`luac`/`luac.exe`.

`lua`:
- `-v` / `--version` → `toolchain.copyright()`; alone → exit 0.
- `-h` / `--help` → usage text, exit 0. (Product extension; upstream prints usage only after a
  bad option.)
- `-e`, `-l`, `-i`, `-E`, `-W`, `-` → refused, exit 127, one Chinese message naming the option
  and stating that code/require must live in a file and that stdin is the project's
  `input.txt`. This is accurate: the native `install_run_input` binds `io.stdin`/`io.read` to
  `<project>/input.txt`, not a console.
- Unknown option → `unknown option …` + usage, exit 1.
- Bare `lua` → exit 127 + "no interactive REPL" + usage. Honest: no console exists.
- `lua <file> [args]` → `resolveSandboxPath`, regular-file check, then
  `startRun(file:, projectDirectory: backend.cwd, commandLine: tokens, scriptIndex: index)`.
  Streams the whole native result through `backend.runStreams` with `cancel: execution.cancel`
  and `exitCode` from `result.status`.

`luac`:
- `-p` parse-only (source or bytecode), `-s` strip (via `qfli_lua_compile_ex`), `-o name`
  (default `luac.out`), `-v`/`--version`, `-h`/`--help`, `--`.
- Refused 127: `-l` (no instruction listing in the bundled library), `-` (no console stdin),
  `-o -` (binary on a line renderer), and >1 input without `-p` (upstream merges prototypes;
  the bundled compiler takes one file).

Sandbox safety: paths resolve through `backend.resolveSandboxPath`; `SandboxEscapeException`
is caught in `handle()` and reported as `不能越出沙盒目录`, exit 1. `FileSystemException` and
any other throwable are also caught (`127`), so a bad line cannot crash the session.

### Deviations from upstream, stated deliberately
1. Usage/unknown-option errors exit 1. Upstream `lua` returns 0 after `print_usage`, which this
   terminal renders as success; a nonzero status is more honest here.
2. `-h`/`--help`/`--version` are product extensions. Upstream rejects `--version`.
3. `-e`/`-l`/`-i`/`-E`/`-W`, `luac -l`/`-s`-as-listing, `luac -o -`, multi-input merge and
   `lua -` are refused rather than emulated.
4. `luac -s` **is** now supported (takeover), so the table in my original design doc comment
   (`-s` refused) no longer matches the code if that comment survived the rewrite — see §4.1.

---

## 3. Verification actually run (exact commands and results)

Toolchain discovery: `cmake` is not on `PATH`. A usable MinGW-w64 + CMake + Ninja set exists at
`D:\AppData\Local\Temp\codearts2api-race-compiler\mingw64\bin`
(CMake 4.4.4, gcc 16.2.0). The pre-existing `native/build/windows` cache was generated with
`MinGW Makefiles` + Dev-Cpp gcc 4.9.2, so a fresh dir was used instead of corrupting it:
`native/build/host` (gitignored via `**/native/build/`).

```
cmake -S . -B build/host -G Ninja -DCMAKE_C_COMPILER=gcc     # configure OK
cmake --build build/host                                     # Linking libqfli_lua.dll, qfli_lua_test.exe, 0 errors
ctest --test-dir build/host --output-on-failure
  → 1/1 Test #1: qfli_lua_test ... Passed  0.10 sec
  → 100% tests passed
```
Result: native bridge (including `qfli_lua_run_with_argv`, `qfli_lua_copyright`,
`qfli_lua_check_source`, `qfli_lua_compile_ex`, negative-timeout = unbounded) compiles and the
existing C test passes on Windows host.

```
flutter analyze lib/lua_terminal_commands.dart lib/lua_toolchain.dart lib/lua_runner.dart
  → 2 issues, both `info` only:
      info - curly_braces_in_flow_control_structures - lib/lua_terminal_commands.dart:232:11
      info - curly_braces_in_flow_control_structures - lib/lua_toolchain.dart:206:7
  → no errors, no warnings
```

```
flutter test test/lua_app_test.dart test/lua_editor_tools_test.dart
  → 00:01 +19 -1: Some tests failed.
```
- `test/lua_app_test.dart` — **all 8 tests pass**, including `运行后端 本语言文件由内置 Lua 执行`
  (real library: `print(6 * 7)` → `42`, exit 0), Unicode filename `测试(1).lua`, and
  `RunnerService.runProject` wiring. This is real-library execution evidence, not a mock.
- `test/lua_editor_tools_test.dart` — **fails** with
  `A RenderFlex overflowed by 6.0 pixels on the right.` (horizontal flex, 360×800 test view),
  followed by `Looking up a deactivated widget's ancestor is unsafe` during teardown.
  This is a layout assertion inside the shared editor page at a 360×800 viewport; it does not
  touch the terminal delegate and does not go through `lua_terminal_commands.dart`. I did not
  reproduce it on a clean tree (that would require reverting peers' files), so treat it as
  **unconfirmed pre-existing vs. newly introduced** — see §4.2.

Earlier, my own draft of the delegate did not compile (12 analyzer errors: missing
`dart:async`/`dart:convert` imports, `runStreams` without required `stderr`,
`const Stream.fromIterable`, and named-vs-positional mismatch on `_invokeNative`). The takeover
rewrite fixed all of those; the note is kept only so the history is not misread as a clean pass.

---

## 4. Findings for the native worker

Ordered by risk. Each is something I could not verify or fix under read-only.

### 4.1 Stale doc comment / capability drift in the delegate
My original design doc comment in `lua_terminal_commands.dart` listed `luac -s` among refused
options. The rewrite now supports `-s` via `qfli_lua_compile_ex`. If any doc block still lists
`-s` as refused, the comment contradicts the code. **Action:** grep the file for `-s` in
comments and reconcile. Capability tables that lie are exactly the R7 "no decorative fake"
failure mode.

### 4.2 No test covers the terminal delegate (highest-value gap)
Zero tests import `lua_terminal_commands.dart`. Nothing currently proves:
- `lua script.lua a b` really sets `arg[1]`, `arg[2]`, `arg[-1]` and `...` **through the
  delegate** (the C test proves the native call; the delegate wiring is untested);
- `lua -v` emits the real banner and exits 0;
- `lua -e ...` / `lua -` exit 127 with the refusal text;
- `luac -o out.luac main.lua` writes the 4-byte signature and the result re-runs;
- `luac -p` on a syntax error returns nonzero and never executes user code;
- cancellation (`^C` → `execution.cancel()` → status 130) works through `runStreams`;
- Unicode paths and a path escaping the sandbox are handled;
- both surfaces (standalone `TerminaxTerminalPage` and editor `TerminalPane`) install the
  delegate — both read `StudioProfile.current?.terminalCommandDelegate`, but `main.dart` wiring
  is root-owned and I did not confirm the profile actually sets it.

Suggested minimal test file (needs write permission, not mine): construct
`SandboxShellBackend(sandboxRoot: tmp, startDirectory: tmp)` in a temp dir, inject
`LuaTerminalDelegate(toolchain: LuaToolchain(libraryPath: <native/build/host/libqfli_lua.dll>))`,
capture `backend.output`, and assert on `lastExitCode` + emitted lines. On a non-Windows host the
default `_openLibrary` path (`native/build/<platform>`) already finds the freshly built library.

### 4.3 Native C test does not cover the two new-by-takeover entry points
`native/test/qfli_lua_test.c` (14,128 B) covers `qfli_lua_copyright` (line 256-257) and
`qfli_lua_run_with_argv` (lines 267, 278), but has **no** reference to
`qfli_lua_check_source` or `qfli_lua_compile_ex`, and no assertion for the
negative-timeout-is-unbounded path. Design intent of my draft test (never applied because my
last header edit failed): a `while os.clock() - start < 0.05 do end` script with
`timeout_ms = -1` must return status 0 with `finished\n`. Without it, a regression that
re-clamps negative timeouts to 10 000 ms would silently cap long terminal runs and no test
would notice. `qfli_lua_compile_ex(..., strip = 1)` also needs a check that the stripped chunk
still loads and runs (strip only drops debug info, not the loader header).

### 4.4 `projectDirectory` for terminal runs is `backend.cwd`, not the project root
`_interpreter` passes `projectDirectory: backend.cwd`. The runner passes the project path.
Consequences: `package.path` gets `<cwd>/?.lua` etc. and `install_project_files` prefixes
relative `io.open`/`dofile`/`loadfile` with `<cwd>`. After `cd src`, `require("mod")` resolves
against `src/`, and a script writing `data.txt` writes into `src/`. That is defensible
shell-like behaviour, but it differs from the editor Run button for the same file. Either
confirm it is intended and document it in the delegate doc comment, or pass
`backend.sandboxRoot` to match the runner. I did not change it.

### 4.5 `timeLimit` default is 10 s, so long terminal runs still get cut
`LuaTerminalDelegate.timeLimit` defaults to `const Duration(seconds: 10)`. The native side now
treats a **negative** limit as unbounded (`effective_timeout = timeout_ms > 0 ? timeout_ms :
(timeout_ms < 0 ? 0 : 10000)`, hook returns early when `timeout_ms <= 0`), which is what an
interactive terminal wants — upstream `lua` has no timer. With the 10 s default, a script that
runs 12 s is killed by `Lua execution timed out` instead of being stoppable only by `^C`.
Decide: keep 10 s as a runaway guard (and say so), or pass a negative `Duration` (e.g.
`Duration(seconds: -1)`) from the terminal while the editor Run button keeps 10 s. Note
`Duration(seconds: -1).inMilliseconds == -1000`, which the native boundary accepts.

### 4.6 `-v` + refusal interaction loses the banner
In `_interpreter`, if `-v` is given **and** an unsupported option follows (`lua -v -e 'print(1)'`),
the `-e` branch calls `_show(...)` with only `error:` and never prepends `banner`. Upstream
prints the copyright then runs/fails. Minor fidelity gap; the banner is computed after the loop
so it is simply unused on those early-return paths. Same shape in `_compiler` for the `-o -`
and `-l` early returns.

### 4.7 `lua -v` exit code vs. unrecognised option path
`_writeUsage` was removed in the rewrite; unknown options now emit
`lua: unknown option …` + usage with status 1. Upstream prints `lua: unrecognized option '…'`.
Behaviour class is the same (usage + nonzero); only wording differs. Acceptable, but if a
tutorial quotes upstream's exact wording the terminal will not match it.

### 4.8 Native library packaging on non-host platforms
`qfli_lua_run_with_argv`, `qfli_lua_copyright`, `qfli_lua_check_source` and
`qfli_lua_compile_ex` are new exports. Android (`native/CMakeLists.txt` via Gradle), OHOS
(`ohos/entry/src/main/cpp/CMakeLists.txt`) and Apple (Runner Xcode target compiling the 33 C
files) all compile the same sources, so they will export the symbols **once rebuilt**. Any
stale packaged `.so`/framework predates them. `supportsCommandLine` and `copyright()` degrade
honestly for `run_with_argv`/`copyright`, but **`checkSource` and `load` have no guard** — if
the editor calls them against a stale library, `lookupFunction` throws `ArgumentError` at call
time. Add the same `providesSymbol`/`try` guard, or confirm the packaging gate guarantees a
fresh build. This is the one place where a missing symbol surfaces as a user-visible crash
rather than an honest message.

### 4.9 `native/build/windows` still holds the pre-change DLL
`native/build/windows/libqfli_lua.dll` is still the 2026-10-03 build (1,033,968 B). My attempt
to copy the fresh build there failed with
`The process cannot access the file … because it is being used by another process` — peer
`flutter_tester`/`dart` processes had it mapped. The fresh artefact exists and passes CTest at
`native/build/host/libqfli_lua.dll` (built 11:0x). Because `_openLibrary` checks
`native/build/<platform>` with `Platform.isWindows → 'windows'`, **`flutter test` here still
loads the old DLL** and the new `--version`/argv/checkSource paths are untested under Flutter
until `native/build/windows` is refreshed while no test process holds it, or the tests pass an
explicit `libraryPath`. I did not kill peers' test processes.

### 4.10 Two lint infos left
`curly_braces_in_flow_control_structures` at `lua_terminal_commands.dart:232` and
`lua_toolchain.dart:206`. Cosmetic, but `flutter analyze` exits non-zero, which will fail a
strict gate.

---

## 5. Capability matrix (what is real today)

| Capability | Status | Evidence |
|---|---|---|
| Offline `lua <file>` execution | **Real** | `lua_app_test.dart` passes with real `libqfli_lua.dll` |
| Source + bytecode (`.lua`/`.luac`) | **Real** | `lua_app_test.dart` `Lua 编译器` group |
| Cancellation (status 130) | **Real, editor path** | `lua_app_test.dart` `取消运行会停止 Lua 死循环` |
| Timeout | **Real** | native CTest `timed out` assertion |
| Modules (`require`), Unicode paths, `dofile` | **Real** | `lua_app_test.dart` |
| Script argv / `arg` / `...` | **Real native**, delegate wiring unverified | CTest `qfli_lua_run_with_argv` |
| `lua -v` real banner | **Real native**, delegate unverified | CTest `qfli_lua_copyright` |
| `luac -p` / `-o` / `-s` | **Real native**, delegate unverified | CTest covers `compile`; `compile_ex` untested |
| `lua -e`/`-l`/`-i`/`-E`/`-W`, `lua -`, `luac -l`, `luac -o -`, multi-input | **Honestly refused** (127) | source |
| Syntax diagnostics with **ranges** | **Absent** | see §6.1 |
| Pause / breakpoint / step / resume | **Absent** | see §6.2 |

---

## 6. Separate deliverable: diagnostics + debugger feasibility (not implemented)

### 6.1 Native syntax diagnostics with ranges

What is achievable **without touching upstream sources** (the repo treats
`third_party/lua-5.4.8/` as immutable, compare `native/README.md`): `luaL_loadfilex` /
`luaL_loadbufferx` return `chunkname:line: message`. `qfli_lua_check_source` therefore already
yields a **line number**, and the message text for common errors (`unexpected symbol near 'X'`,
`'=' expected near …`, `'<eof>' expected`). Columns are **not** reported by upstream; deriving
them means re-scanning the offending source line for the quoted token, which is a heuristic, not
a range. Exact ranges require instrumenting the lexer in `llex.c` / `lparser.c` (track a column
per token and a line-start table) — i.e. **a patched upstream**, which conflicts with the
current "upstream unchanged" invariants and with Apple/OHOS/Android sharing one source tree.

Proposed **additive** API if approximate ranges are acceptable (a superset of what exists, no
existing signature changed):

```c
/* Returns a JSON array of diagnostics: [{"line":N,"column":C|null,
   "endColumn":C2|null,"severity":"error","message":"..."}].
   column/endColumn are null when upstream only reported a line. */
QFLI_API QfliLuaResult *qfli_lua_diagnostics(const char *source, size_t length,
                                            const char *chunk_name);
```

Limits to state in the UI: line-accurate, column best-effort; only the **first** syntax error
per chunk (upstream stops at the first); no semantic analysis; no name/type diagnostics.

Honest recommendation: ship line-based diagnostics now (already possible), underline the whole
line, and label column ranges as unavailable rather than guessing a wavy span that may be wrong.

### 6.2 Real pause / breakpoint / step / resume

Feasible in principle, but it is not a small addition and it cannot be bolted onto the current
one-shot FFI shape.

Why the current shape blocks it: `startRun` runs one blocking `Isolate.run` per script with a
cancel token; there is no channel to send "pause/step" back into the running VM, and Lua states
are not inspectable from another thread.

What a real implementation needs (all native, additive):
1. The VM on a **dedicated OS thread** (not a Dart isolate), so a hook can block on a
   mutex/condvar while the controller inspects the state.
2. `lua_sethook(L, debug_hook, LUA_MASKLINE | LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, N)`.
   The hook reads `lua_Debug` (`currentline`, `source`, `what`) to match a breakpoint and to
   implement step-in (`MASKCALL`), step-over / step-out (track depth from CALL/RET).
3. Inspection **inside** the hook using only re-entrant-safe API: `lua_getstack`,
   `lua_getinfo("nSl")`, `lua_getlocal`/`lua_setlocal`. Calling Lua code (`lua_pcall`) from the
   hook is illegal, so **expression evaluation / watch values are not available**.
4. A command queue + condition variable, and a new exported surface, e.g.

```c
typedef struct QfliLuaDebugger QfliLuaDebugger;
QFLI_API QfliLuaDebugger *qfli_lua_debug_new(void);
QFLI_API void qfli_lua_debug_free(QfliLuaDebugger *);
/* Async run: returns immediately; events are drained by the host. */
QFLI_API QfliLuaResult *qfli_lua_debug_start(QfliLuaDebugger *, const char *file,
    const char *project_dir, const char *const *argv, int argv_count, int script_index);
QFLI_API void qfli_lua_debug_add_breakpoint(QfliLuaDebugger *, const char *chunk, int line);
QFLI_API void qfli_lua_debug_resume(QfliLuaDebugger *);
QFLI_API void qfli_lua_debug_step(QfliLuaDebugger *, int kind); /* in/over/out */
QFLI_API void qfli_lua_debug_pause(QfliLuaDebugger *);
/* Poll one event as JSON: {"kind":"paused|exited|output","line":N,"chunk":"...",
   "stack":[...],"locals":[{"name":..,"value":..}]} */
QFLI_API QfliLuaResult *qfli_lua_debug_poll(QfliLuaDebugger *, int timeout_ms);
```

5. Dart side must become **polling/async** (`Timer` or a `NativeCallable` port), not
   `Isolate.run`, and cancellation must keep working while paused.

Hard limits that must be surfaced in the UI, not hidden:
- Code can disable the hook (`debug.sethook`), so a breakpoint in hostile/pathological code may
  not fire; upstream also suppresses hooks inside GC finalizers.
- No blocking-native preemption: `os.execute`, `io.popen`, long file reads, and C functions
  cannot be stopped, stepped into, or paused.
- No expression evaluation, no watch expressions, no globals mutation from the debugger.
- Locals are readable by name only via `lua_getlocal` on a live frame; upvalues of C functions
  are not exposed.
- Threads: a paused script blocks its own OS thread only; the Flutter UI must not wait on it.

**Recommendation to root:** do not advertise Debug Console breakpoints/stepping until this
surface exists and is tested on a real device. A "pause" button that cannot actually suspend the
VM would be exactly the decorative feature R7 forbids. The honest interim UI is Run + Stop (both
real today) with breakpoints visibly disabled and a one-line reason.

---

## 7. My artifacts and their provenance (so nothing is misattributed)

Mine, still on disk and unchanged since handover: `qfli_lua_copyright`,
`qfli_lua_run_with_argv` (declaration in `.h`, `install_arg_table` + vararg push + wrapper in
`.c`), the `effective_timeout` / `timeout_ms <= 0` unbounded path, the C test additions for
copyright/argv/no-argv, and the first draft of `lua_terminal_commands.dart` /
`lua_toolchain.dart` argv plumbing (`_RunWithArgvNative`, `commandLine`, `scriptIndex`,
`supportsCommandLine`).

Takeover's: `qfli_lua_check_source`, `qfli_lua_compile_ex`, `LuaToolchain.checkSource`/`load`,
named-parameter conversion of `_invokeNative`, NUL rejection, the rewrite of the delegate body
(`_interpreter`/`_compiler`/`_result`/`_show`/usage texts).

Not mine and not touched: `lib/lua_runner.dart`, `lib/main.dart`, `lib/lua_tools*.dart`,
`assets/content/**`, `tool/**`, `pubspec.*`, `ohos/**`, `../qfli_studio_core/**`.

I have made no commit and no push. Working tree still shows 46 changed paths; peers' new files
(`lib/lua_content_repository.dart`, `lib/lua_tools.dart`, `lib/lua_tools_page.dart`,
`tool/generate_lua_content.dart`, `tool/verify_lua_content.dart`, `assets/content/`,
`test/lua_tools*_test.dart`, `test/lua_offline_platform_test.dart`) are theirs to stage.
