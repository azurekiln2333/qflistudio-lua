# Runner final read-only review — 2026-10-22

## Authorized follow-up implementation and verification

Root subsequently authorized product-local fixes, exclusively in
`lib/lua_runner.dart` and `test/lua_runner_shell_test.dart`. The original review
below describes the earlier source and is retained as evidence. Its stdin,
embedded-output and uppercase-title findings are now fixed. Direct-process
cancellation is bounded. The current common-core Linux implementation is
updated below; OHOS descendant cleanup remains unverified.

- Shell validates and opens regular `input.txt` before launching user source,
  feeds exact64KiB chunks concurrently with both output drains, closes stdin at
  EOF or immediately when input is missing, and closes its own file handle.
  Nonregular input returns an explicit127 pre-execution failure. An early child
  exit/closed pipe does not replace its true status with an EPIPE failure.
- `_ShellRun` immediately subscribes to both managed output streams and retains
  data in its product-owned streams while input is fed. It handles asynchronous
  input failures explicitly and closes output on normal or cancelled completion.
- Stop first invokes the supervisor; after300ms it sends SIGKILL to its owned
  direct PID and waits at most a further2s plus bounded input cleanup. It reports
  termination/cleanup failures and settles the product result instead of leaving
  the terminal indefinitely pending. Selected absolute Shell executables start
  directly with `runInShell:false`, avoiding an unnecessary host command wrapper.
- Embedded Lua/JS/TS results preserve their actual captured stdout/stderr even
  when the user stops the run. Disposed terminal sessions already ignore those
  events in the shared UI. TypeScript titles now lowercase the extension before
  choosing their language label.

Current verification:

```powershell
& 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe' analyze lib/lua_runner.dart test/lua_runner_shell_test.dart
# No issues found; Dart format also passes.
& 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe' 'D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 test/lua_runner_shell_test.dart
#9/9 pass against real local Shell, Lua and TypeScript runtimes.
```

Tests prove missing-input EOF, Unicode/tab/unterminated-line input, exact NUL
pipe bytes, rejection before script side effects, early-exit EPIPE/status7,
bounded Stop with1MiB blocked input and a TERM trap, retained native output/error
prefix/status130, and the actual uppercase `.TS` compiler route/title. This is
Windows host evidence; OHOS execution remains a separate root-owned gate. The
serial Flutter window was explicitly released to root after these tests.

### Shared supervisor follow-up, October 23

Common-core owner published `9b0c01f` after this review. It adds verified-owned
Linux pidfd/procfs ancestry tracking with bounded TERM-to-KILL cleanup. The owner
reports 48 focused tests plus four actual Linux checks covering descendant
termination, retained final output and an unrelated surviving sibling. The
earlier recommendation below describes the reviewed baseline, not the current
Linux implementation. OHOS remains unverified; other POSIX/old-libc/procfs
fallbacks only bound the parent and detached ancestry is not claimed. Lua has
not changed the shared supervisor or promoted those host checks to target proof.

### Original shared supervisor recommendation

`ManagedProcess` exposes an owned PID and cancel callback, but has no process-group
or descendant handle. The product wrapper therefore cannot honestly guarantee
POSIX child-tree cleanup; a timed fallback on Windows also only addresses the
direct PID if supervisor cancellation is blocked before its tree terminator.
Root should coordinate the shared supervisor owner to introduce an owned
process-group/job lifecycle, bounded graceful→forced termination and reaping,
with real descendant tests. Do not use broad process-name termination or touch
sibling product processes. No shared/core source was changed here.

Reviewed `lib/lua_runner.dart` (observed modification time21:18:59), the actual
`luaProfile` in `lib/main.dart`, `ProductCodeAnalyzer`, shared RunnerService,
ProcessSupervisor and TerminalPane, plus the Lua toolchain terminal contracts.
No source edits or heavy tests were performed. Findings below are demonstrated
by the live ownership/data flow; reproduction inputs are specified for root's
next serial test window rather than claimed as newly executed tests.

## Findings, ordered by impact

### P1 — Shell stdin is permanently open and has no writer

`lib/lua_runner.dart:59–75` starts a managed shell and returns output, exit and
cancel only. It never reads `input.txt`, writes `process.stdin`, or closes that
sink. `ProgramRunResult` has no input handle (`core/lib/services/studio_profile.dart:329–346`),
and the profile path forwards only these same fields through
`core/lib/services/runner_service.dart:132–138` to TerminalPane. Therefore a
noninteractive project containing `IFS= read -r value; printf '%s\\n' "$value"`
waits for data forever, including when `input.txt` is absent. The UI has no way
to send its awaited input. This affects the actual run button, not just a direct
process test.

Minimal recommendation: after starting Shell, concurrently attach/drain both
output streams and feed the project's regular `input.txt` into owned stdin;
close stdin when the feed ends. Missing input must close immediately. Reject
nonregular/read-failing input explicitly, without leaving the child running.
Cover shared position/EOF, absent input, Unicode paths, input failure and cancel
during feeding with actual Shell executions.

### P1 — POSIX Stop neither guarantees child cleanup nor bounded termination

`lib/lua_runner.dart:74` directly returns `ManagedProcess.cancel`.
`core/lib/services/process_supervisor.dart:256–275` has tree termination only
on Windows; other systems call `process.kill()` once and then await the direct
process indefinitely. There is no POSIX process-group/descendant termination,
no signal escalation and no deadline. Thus `sleep 60 & wait` can leave its child
running after the shell is killed; a shell running
`trap '' TERM; while :; do :; done` can ignore the sole signal and leave Stop
pending forever. OHOS follows this non-Windows branch.

Minimal recommendation: coordinate the shared supervisor owner before changing
its contract, or provide a product-owned Shell lifecycle wrapper. Start an owned
process group when supported, terminate its tree, use bounded TERM→KILL
escalation, reap the child and settle both streams. Keep unsupported platform
capability explicit. Add tests proving no descendant remains and that a TERM
trap cannot indefinitely block cancellation.

### P2 — User Stop discards all prior embedded runtime output

`lib/lua_runner.dart:150–157` publishes the completed Lua/JS/TS output only when
`canceled` is false; the same result's public Stop callback sets it true at
line173. Since these embedded runtimes return captured buffers when execution
ends, `print('before'); while true do end` (or equivalent JS) returns a real
`before` buffer from its VM on cancellation, but the adapter deliberately drops
it along with its captured stderr. TerminalPane's Stop action invokes this same
cancel callback (`core/lib/editor/terminal_pane.dart:987` and1311); the loss is
not limited to editor disposal.

Minimal recommendation: preserve the finished buffers for a user-stopped run.
The terminal already ignores events for disposed sessions at1007/1014, so do
not conflate Stop with suppressing an abandoned UI session. Verify a printed
prefix and stderr before an infinite loop survive Stop and status130 remains.

### P2 — Uppercase .TS executes TypeScript but claims JavaScript

Dispatch correctly lowercases extensions at `lib/lua_runner.dart:39–45`, and
the embedded toolchain lowercases again at `lib/script_toolchain.dart:116`.
However `_runScript` constructs its title using a case-sensitive `.ts` comparison
at `lib/lua_runner.dart:113–114`. A saved `main.TS` therefore executes through the
TypeScript compiler but displays `javascript main.TS`.

Minimal recommendation: lowercase the title's extension comparison and add a
profile-run assertion for a `.TS` entry. Ordinary `.js`, `.mjs` and `.ts` titles
already describe the embedded language rather than falsely claiming Node/Deno.

## Checked integration and correct behavior

- `main.dart:28–49` actually installs `LuaProgramRunner`, the bundled content
  repository, terminal delegate and `ProductCodeAnalyzer`. The supported
  extensions include Lua, bytecode, JS/MJS, TS and Shell. The analyzer dispatch
  routes all advertised language labels to the appropriate offline provider.
- Shell discovery is shared with the analyzer at `lua_runner.dart:179–183`.
  `findPosixShell` tests `/system/bin/sh` then `/bin/sh` on OHOS and uses bounded
  `where`/`which` discovery for `sh` then `bash` on desktops. It returns an
  absolute existing path and does not substitute PowerShell. Actual OHOS process
  execution still needs target evidence; file existence alone does not establish
  executable permission.
- A missing shell and a selected shell that fails to launch are distinguished:
  `lua_runner.dart:54–56` versus76–83 and198–204. Both honestly use127. Once a
  process starts, its own nonzero exit status/stderr propagate instead of being
  replaced with an unavailable result. The embedded Script backend also returns
  an explicit127 result when loading/preparation is unavailable.
- With both streams attached, natural managed completion waits for stdout and
  stderr EOF (`core/process_supervisor.dart:278–286`), and TerminalPane separately
  awaits both line streams before publishing completion at1020–1021. UTF-8
  decoding uses replacement rather than throwing on malformed output. Embedded
  noncancelled results also close both stream controllers. No source-level
  natural-completion drain defect was established in this review.
- Shared managed forwarding uses broadcast streams before the product consumer
  subscribes (`core/process_supervisor.dart:149–152,190–205`). That deserves a
  delayed-subscriber regression when its owner next changes the supervisor;
  this review did not run a timing reproduction, so it is not counted above as
  a newly proven product failure.

## Verification boundary

This narrow pass was read-only source tracing. No build, emulator action or
Flutter/native suite competed with the workers' serialized window. Existing
Shell tests cover a no-input command and normal completion only; they do not
cover the stdin/cancellation cases above. Root owns implementation decisions,
the necessary focused regression runs and the final full-product gate.
