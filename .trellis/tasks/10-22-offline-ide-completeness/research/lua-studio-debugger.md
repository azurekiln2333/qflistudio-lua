# Lua shared debugger adapter

Date: 2026-10-23 (Asia/Shanghai)

## Delivered boundary

`lib/lua_studio_debugger.dart` exports the const-constructible
`LuaStudioDebugger implements StudioDebugger`. It bridges the actual
`LuaDebugger` worker to the shared `DebugSession` contract. Root owns profile
wiring; the adapter does not edit core, the native ABI, or ordinary Run behavior.
`test/lua_studio_debugger_test.dart` exercises the real host native library.

The adapter declares paused-only breakpoint replacement, pause-or-exit output,
asynchronous pause, step into/over/out, stop on entry, stack frames, and copied
primitive locals. It does not offer expression evaluation or object expansion.
Complex locals retain the backend's actual type display and an explicit
unavailable reason, with no pretend child handles or calls to user metamethods.

## Source and breakpoint identity

The runtime debugs saved `.lua` text. Therefore
`supportsDocumentSnapshots == false`; every nonempty `documents` request is
rejected before a worker starts. No dirty buffer is silently ignored, no source
is overwritten, and no temporary source project is invented. The caller must
save its documents and launch with an empty list.

Launch validates language, absolute/NUL-free paths, existing directory/file
types, physical canonical project containment, `.lua` extension, and the entire
breakpoint set before starting execution. Filesystem aliases and symlinks or
Windows junctions are resolved before containment checks. Inputs are limited to
4096 UTF-16 units per path, 256 breakpoints, unique canonical file/line pairs,
and positive signed-32-bit physical lines. Invalid replacement requests throw
without changing the previous real breakpoint set.

Accepted lines remain pending until the backend actually pauses on that exact
canonical file and line. The adapter never guesses nearby executable lines.
An entry-line breakpoint is respected even when stop-on-entry is false.
Only native file-backed frames receive navigable source locations. Generated
chunks with a forged project filename keep a null location; native frame source
identity is preserved by `LuaDebugFrame.fileBacked`.

## Snapshots, bounds, and commands

Updates are broadcast immutable full replacement snapshots, with increasing
adapter revisions and complete retained stdout/stderr buffers. The getter is
updated before publication. The backend is a single main Lua thread; frame IDs
are scoped to a session and observed pause generation. A newly observed pause
gets a fresh token; resume and step invalidate it immediately. Stale, foreign,
missing tokens, unknown threads, and commands in the wrong phase are rejected
without changing execution. Resume acknowledges dispatch rather than awaiting
the next pause, so a running infinite loop can still be paused or stopped.

Concrete limits:

| Data | Bound and loss signal |
| --- | --- |
| stdout, stderr, console | Latest 64 * 1024 UTF-16 units per stream; corresponding truncation flag |
| Frames | At most 64; native cap-reached or adapter omission sets `framesTruncated` |
| Local slots | First 128 native slots per frame, excluding internal names; native cap metadata sets `localsTruncated` even when hidden slots reduce the visible count |
| Local string value | Native 4096 UTF-8 bytes, cut on a valid character boundary; native `truncated` is forwarded |
| Local name/type/value | 1024 / 64 / 4096 UTF-16 units; omission sets variable `truncated` |
| Frame name | 1024 UTF-16 units; omission sets frame truncation and adds a console diagnostic |
| Snapshot message | 4096 UTF-16 units; full retained stderr remains separately available |

Adapter truncation never cuts a valid surrogate pair. Native cap-reached flags
are conservative: they disclose that completeness is no longer guaranteed,
rather than asserting that an unqueried next frame or slot does not exist.

Breakpoint exchange events can arrive while asynchronous filesystem resolution
is queued. Each event captures its command epoch at receive time; resume/stop
advance that epoch. An old paused event cannot restore its frames or token after
a newer command, including when the old event has not begun processing yet.

## Actual worker cleanup

`done`, `stop()`, and `dispose()` wait for `LuaDebugger.dispose()`. The separately
owned runtime changes now wait for native VM free and the worker's isolate exit
notification. Terminal snapshots appear only after that cleanup; status 130 is
a stopped session, and other nonzero program statuses publish a failed snapshot
with a useful message. No absent exit code is replaced with zero. Stop and
dispose are idempotent; dispose closes the adapter updates stream after cleanup.
A failed initialization cleans up both the native runtime and the adapter's own
subscription/broadcast resources before propagating the launch error.

## Verification

Commands executed against the current Windows host library:

```powershell
& 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe' format lib/lua_studio_debugger.dart test/lua_studio_debugger_test.dart
& 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe' analyze lib/lua_studio_debugger.dart test/lua_studio_debugger_test.dart
& 'D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe' 'D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 test/lua_studio_debugger_test.dart
```

Result: scoped analysis clean; **23/23 real-library tests passed**, no skips.
Coverage includes all three steps, entry/cross-file stops, actual locals and
verified locations, stale tokens, a running infinite loop, stop while paused,
close-variable cleanup, cumulative output and revision ordering, Unicode output
tails and primitive value truncation, frame/local cap forwarding, metamethod
non-execution, generated source labels, exact dirty-buffer rejection, canonical
aliases, actual symlink/junction escape rejection, atomic breakpoint validation,
the acknowledgement/resume race repeated five times, stop during breakpoint
validation, native failure/status propagation, unavailable backends, and stream
closure after completion.

The root separately reported the underlying runtime lifecycle/metadata suite
passing 22/22, including worker-exit and UTF-8 boundary regressions. That is
separate evidence from this adapter suite. Root retains full-suite, profile/UI
integration, HAP inspection/build and actual OHOS device acceptance ownership.
Host library tests do not establish packaged OHOS execution. Native I/O,
non-yieldable callbacks and user finalizers can delay cooperative pause/stop;
the adapter keeps stopping/cleanup pending rather than reporting false exit.
