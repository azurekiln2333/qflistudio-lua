# Lua Toolchain Contract

## Scope / Trigger

Read this before changing the native bridge, Dart FFI, runtime packaging, or
editor Lua tools. The upstream Lua 5.4.8 source stays unmodified; app behavior
belongs in `native/src/qfli_lua.c` and `lib/lua_toolchain.dart`.

## Signatures

- `qfli_lua_run_with_token(file, project_dir, timeout_ms, token)` executes a source
  or bytecode chunk in a fresh state.
- `qfli_lua_check(file)` loads text without executing it.
- `qfli_lua_compile(file, output_file)` loads text and dumps Lua bytecode.
- `qfli_lua_check_source(source, length, chunk_name)` parses exact unsaved UTF-8
  bytes without opening standard libraries or executing user code.
- `qfli_lua_run_with_argv` supplies both the `arg` table and main chunk varargs.
- `qfli_lua_compile_ex(file, nullable_output, strip)` also accepts VM bytecode.
- `LuaDebugger.start` creates a persistent worker owning one native session;
  `resume`, `setBreakpoints`, `pause`, `stop`, and `dispose` control it.
- `LuaDebugger.workerExited` observes the isolate's actual `onExit`; `dispose`
  resolves only after VM cleanup and that exit event.
- `qfli_lua_free(result)` releases a result exactly once.
- `LuaToolchain.startRun(...)` returns a result future and cancellation callback.
- `StudioProfile.editorFileTools` contributes current-file actions to the shared
  editor. The editor saves current changes before invoking a tool.

## Contracts

Default stdin is per Lua state: read the project's regular input.txt through
both io.stdin and io.read. Missing input means immediate EOF via an owned null
device stream. Reject non-regular input and report metadata/open failures before
loading the entry. The state closes its descriptor; never redirect or close host
stdin. Keep explicit io.input selections and the existing public C ABI intact.
Windows metadata lookup must convert UTF-8 paths using the same wide-path helper
as source/file loading, otherwise input fails under non-ASCII project directories.

`QfliLuaResult` stores `int status`, `char *output`, `char *error`, followed by
`size_t output_length` and `size_t error_length`. Dart mirrors pointer-sized
lengths with `@UintPtr()`. Decode exact byte lengths with UTF-8 replacement for
malformed bytes; C strings alone truncate valid embedded NUL bytes.

Each ordinary operation owns one Lua state. Cancellation tokens remain allocated until
the worker isolate finishes. `lua_close` runs before transferring captured
buffers to the result because finalizers can append output and reallocate them.

Temporary files are project-owned. `os.tmpname()` exclusively creates and
reserves a unique file in the canonical project root and returns its absolute
path; the caller removes it. `io.tmpfile()` owns an exclusive read/write file
there and removes it on close, GC, or state shutdown. Never fall back to `/tmp`,
process TEMP or cwd. POSIX creation uses mode 0600; Windows uses wide-path
exclusive creation. This contract applies to ordinary and debugger states.

Debugger VM calls stay on one persistent worker. Only atomic pause/stop flags
cross threads. Line/count hooks yield before the stopped line executes; paused
time is excluded from execution limits. Inspect bounded primitive locals without
calling metamethods. Close the suspended coroutine with `lua_closethread` before
closing its parent state, then transfer finalizer output/errors. Closing only
the parent drops suspended `<close>` cleanup. Debug mode rejects user coroutine
operations and hook replacement; non-yieldable callbacks defer stopping with a
diagnostic. The normal Run mode retains ordinary Lua behavior.

Preserve native source identity through `LuaDebugFrame.fileBacked`; an absolute
looking generated chunk label without Lua's file marker must not become a
navigable disk location. `framesTruncated` marks the 64-frame inspection cap;
`localsTruncated` marks the 128-slot cap, including hidden slots. Primitive value
`truncated` marks byte-length truncation at 4096 bytes. Cut valid UTF-8 at a scalar
boundary before decoding, so truncation does not invent replacement characters.
Observe the worker's exit independently of its native-free acknowledgement.
Launch/command failures must not leave an unobserved persistent worker.

The shared product adapter must attempt runtime disposal even when `stop()`
rejects. Retain the original failure in console/terminal state, await the actual
`workerExited` event independently of any dispose acknowledgement, then publish
terminal state and complete `done`. If cleanup fails before exit, remain stopping
with ownership retained and clear only the failed in-flight attempt so a later
`stop()`/`dispose()` can retry. Do not memoize rejection forever or advertise
cleanup complete merely because an acknowledgement or timeout arrived. Direct
tool disk previews and current-line markers require `LuaDebugFrame.fileBacked`,
just as shared navigable locations do.

After a post-creation `LuaStudioDebugger.launch` initialization failure, retain
the original error and stack before attempting disposal. Once session `done`
confirms cleanup, rethrow the identical original error with
`Error.throwWithStackTrace`; a subsequent stop/disposal error must not replace
it. If disposal rejects while `done` is pending, return the same stopping
`DebugSession` to the editor controller. Keep the original failure/stack in its
bounded console, reject resume/step, and permit explicit Stop/dispose retry.
The controller must retain its busy lane until actual worker exit and cleanup
complete. Do not throw away that partially cleaned session, advertise a clean
launch, or add an unbounded background retry timer.

The CMake library target is `qfli_lua_engine`, separate from the Flutter
executable `qfli_lua`. Its artifact is `libqfli_lua` with the platform suffix.
Windows bundles the DLL beside the executable; Linux bundles the shared
library under its `lib/` directory. Android and HarmonyOS compile the same
vendored sources through their native build integrations.

iOS and macOS compile the bridge and all 32 Lua library C files in the Runner
source phase. Their Debug, Profile, and Release configs select C11, shared
headers, and upstream `LUA_USE_IOS` or `LUA_USE_MACOSX`. Never include the
Lua CLI entry points, native tests, or Windows adapters in these targets.
Apple `QFLI_API` must retain `used` and default visibility; Runner uses
`STRIP_STYLE = non-global` so dynamically looked-up symbols survive Release
dead stripping and final stripping. iOS loads `DynamicLibrary.process()`;
macOS prefers process symbols and keeps a dylib fallback for standalone
development commands. Explicit library paths still take precedence.

Only iOS `liolib.c` force-includes `ios/Runner/QfliLuaIos.h`, using upstream
customization macros to disable unavailable `popen`/`pclose` calls.
`LUA_USE_IOS` already disables `system()` in upstream `loslib.c`. Keep
these platform adaptations outside the vendored source.

The Windows CMake build alone force-includes `qfli_lua_windows.h` and
compiles `qfli_lua_windows.c`. UTF-8 file names supplied by Dart/Lua are
converted before `fopen`, `freopen`, `remove`, and `rename` reach the wide
Windows CRT APIs. Cover source loading, module files, bytecode output, and
script file operations under non-ASCII paths; do not alter upstream Lua.

Native and Flutter ABIs must match in the final package. Android's Flutter
plugin initially selects all native ABIs; `android/app/build.gradle.kts`
overrides build-type filters from `target-platform` for non-split builds while
preserving `split-per-abi` and `disable-abi-filtering` behavior. NDK 27 also
receives `ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON`; inspect 64-bit ELF LOAD
alignment and final APK ZIP alignment rather than treating the setting alone
as evidence of 16 KiB compatibility. HarmonyOS defaults
`buildOption.externalNativeOptions.abiFilters` to `["arm64-v8a"]` in the entry
profile and uses `buildOption.nativeLib.filter.excludes` with `x86_64/**` and
`armeabi-v7a/**` to exclude dependency HAR libraries for other architectures.
The packaging filter is necessary because Flutter's Hvigor plugin defaults
to ARM64 and x64 when IDE builds omit `TARGET_PLATFORM`. The entry Hvigor plugin
uses ARM64 when absent, accepts explicit `ohos-arm64`, `ohos-x64`, or both, and
sets native ABI filters plus opposite-ABI package exclusions together. Do not
rewrite the checked-in profile per build. Inspect all packaged libraries and
the Flutter engine for each requested ABI. `tools/build_ohos_audit.ps1` preserves
a hashed HAP and runs `tools/inspect_lua_hap.py`; successful packaging does not
set a device acceptance gate.

On Windows, the project's native Ninja compile pool and Gradle worker count
are limited to two; Gradle uses a 2 GiB heap. Pagefile/thread exhaustion during
packaging is an environment failure and must be distinguished from a source
compile failure.

### Terminal presentation

Lua runner titles flow unchanged through `RunnerService.runProject` into the
shared `TerminalPane.attachOutput`. Use `lua <filename>` for Lua source and
bytecode, and the selected executable command for desktop script runners.
Keep host diagnostics short and in English; distinguish a missing language
runtime from a discovered executable that failed to launch.

User filenames and stdout/stderr line content remain unchanged, including
Chinese characters and parentheses. Never strip text based on a banner pattern.
The shared terminal owns completion display: status 0 returns silently to the
prompt, while a nonzero status retains its number. Preserve the existing 127
not-started and 130 cancellation semantics.

Verify the runner title and both drained streams using a real Lua file with a
Unicode name containing parentheses. Keep the shared terminal success/error,
session and cancellation tests, and distinguish widget render checks from a
packaged application or device run.


## Validation & Error Matrix

| Case | Required outcome |
| --- | --- |
| Valid source check | Status 0; no script side effects |
| Valid compile | Status 0; standard Lua chunk signature |
| Syntax/runtime error | Nonzero status; diagnostic in stderr |
| Missing runtime before run | App reports status 127 |
| Cancellation observed by VM hook | Status 130 |
| Embedded NUL / malformed UTF-8 | Preserve NUL; replace malformed bytes without losing the result |
| Project relative file | Resolve through per-state project path, without process-wide `chdir` |
| Missing input.txt | Empty reads / EOF, without touching host stdin |
| input.txt is a directory or another non-regular path | Nonzero status and diagnostic, no entry execution |
| Default HarmonyOS packaging | Every packaged native library is ARM64 |
| Explicit HarmonyOS x64/both selection | Lua, Script and Flutter libraries match every selected ABI |
| Temporary storage unavailable | Explicit Lua I/O failure; no global temporary fallback |
| Debugger stop while paused | Pending line does not run; `<close>` and owned files are cleaned up |
| Initialization fails and cleanup completes | Rethrow the identical initialization error with its original stack |
| Initialization fails and cleanup rejects before actual exit | Return the stopping session; keep the controller busy and permit explicit Stop retry |
| Parser/backend unavailable | Nonempty unavailableReason; never an empty successful diagnostic result |

Diagnostic audit fixtures must canonicalize their newly created owned project
directory before constructing snapshot and request paths. Keep the requested
caller spelling in evidence, but compare the returned diagnostic against the
exact canonical file identity. On Windows, exercise a caller containing both
separator styles with the real parser. Preserve exact UTF-16 half-open ranges,
unsaved Unicode/CRLF text, corrected-clean checks, source hashes, absent execution
markers and cleanup checks; path normalization must not weaken these assertions.

Cancellation is cooperative. Lua VM hooks cannot interrupt native I/O, external
commands, finalizers with disabled hooks, or programs that replace/catch the
hook. The runtime is an embedded interpreter, not an OS sandbox.

## Good / Base / Bad Cases

- Base: `print(6 * 7)` returns `42` through the editor runner.
- Good: Check a dirty editor buffer, report syntax errors, then compile corrected
  code and execute the generated bytecode.
- Bad: A library installs correctly on a host but is missing from the APK/HAP.
  Packaging inspection and a device run are required before advertising it as
  available on that target.
- Bad: A single-ABI package contains Lua libraries for additional ABIs without
  matching `libflutter.so` and `libapp.so`. Inspect all packaged native paths,
  not just the presence of `libqfli_lua.so`.
- Bad: Restrict HarmonyOS CMake to ARM64 but leave dependency HAR libraries
  unfiltered; IDE builds can still package x64 Flutter libraries.

## Tests Required

With available host toolchains, run native CTest, `flutter analyze --no-pub`,
and `flutter test --no-pub`. Keep
assertions for source/bytecode execution, project modules and file paths,
standard output/error and redirection, Lua 5.4 conversion behavior, finalizer
output, malformed output bytes, syntax errors, timeout, cancellation, and
Windows non-ASCII file paths. Verify a desktop standalone command beside its
packaged native library to exercise executable-relative loading.

Cover initialization errors with a distinct subsequent cleanup failure. Assert
original error identity and stack after completed cleanup. Through the real
`EditorDebugController`, assert incomplete cleanup retains its session and busy
lane, rejects a second launch/resume, and permits Stop retry. Release that lane
only after the controlled runtime's actual exit and session cleanup complete.

Native CTest also checks shared io.read/io.stdin position, missing-input EOF,
host stdin preservation and non-regular input rejection. tools/lua_stdin_smoke.dart
requires six real-library checks, including a non-ASCII project directory,
source-free bytecode input and recovery. Run it through Dart on Windows with the
actual DLL, and through the application on each available mobile ABI. Apple
builds and ARM execution remain separate gates; host tests do not establish them.

Source/configuration inspection is not platform compilation or runtime
evidence. Skip unavailable platform tests and record the missing environment:
Visual Studio for a full Windows Flutter app, macOS/Xcode for Apple, and an
accessible Linux host for Linux. For Apple source checks, compare both Runner
source phases with the complete shared source set and inspect all three
target configurations, visibility, and stripping settings.

A successful test command and an empty owned process tree are separate gates.
Record both. A root process exiting zero does not prove all its descendants
have retired. If an owned-Job cleanup force-terminates a descendant, retain the
test assertions as passed where supported but fail the containing verification
gate. Any short natural retirement interval must stay inside the original
deadline, with exact owned-Job membership and residual identity evidence. Never
terminate a process selected only by executable name or an unrelated peer's PID.

For device builds, confirm the engine exists in the final package with matching
Flutter ABIs and exported bridge functions. Inspect HarmonyOS HAP output
and require every native library to be under `arm64-v8a` with ELF machine
183 (AArch64); include Flutter and dependency libraries in this check.
Run check, compile, and bytecode
execution only when device testing is authorized and available. Restore
`lib/main.dart` after using a probe entry; keep probes separate from product
startup. If device debugging is declined, do not connect or install a probe;
record the runtime/UI verification gap.

## Wrong vs Correct

- Wrong: Transfer an output pointer, then close Lua and let `__gc` print.
  Correct: Close Lua first, then transfer the final pointer and length.
- Wrong: Read output with `toDartString()` and assume it has no NUL bytes.
  Correct: Decode `pointer.asTypedList(length)`.
- Wrong: Name both executable and native library targets `qfli_lua`.
  Correct: Use `qfli_lua_engine` and install that target's artifact.
