# Script toolchain and diagnostics

## 1. Scope / Trigger

Read when changing Script product runners, native QuickJS, TypeScript assets,
Shell analysis, or platform library packaging. Lua remains governed by
`lua-toolchain.md`. Shared editor/API files belong to the common-core owner.

Audit-report retrieval also follows this spec. Its implementation is confined to
`bin/script_report_export.dart` and `ScriptAcceptancePage` in
`bin/script_acceptance.dart`; export never promotes a runtime acceptance gate.

## 2. Signatures

`ScriptToolchain.startRun(file:, projectDirectory:, timeLimit:)` returns a
`ScriptExecution` with `result` and `cancel()`. `checkSource(source, fileName:,
typescript:, module:)` is compile-only. `transpile(source, fileName:)` returns
actual emitted JavaScript in output. `ScriptToolResult` contains status,
stdout/output, error, and original-source UTF-16 diagnostics.

`ProductCodeAnalyzer` routes Lua, JS/TS, and Shell requests through the frozen
core `CodeAnalyzer.analyze(CodeAnalysisRequest)` interface. `findPosixShell()`
discovers a real local POSIX shell. `ShellCodeAnalyzer` uses `sh -n -s` on stdin.

`LuaProgramRunner(operatingSystem:, shellFinder:, processSupervisor:)` keeps its overrides local
to one runner; null OS uses `Platform.operatingSystem` and the default finder
is `findPosixShell`. Shell Run permits Windows, Linux, macOS, OHOS and Android
to discover a real shell. Android/OHOS discovery probes `/system/bin/sh` then
`/bin/sh`. Unsupported platforms return127 without discovery; a supported host
with no shell also returns127, never a fake successful run. Lua/JS/TS routes
remain independent of this Shell-only platform decision. An optional per-runner
`ProcessSupervisor` supplies the Shell lifecycle owner; null retains the default
shared product supervisor. This injection is a test seam, not a process identity
or descendant-containment guarantee.


### Audit-report export API

- `scriptReportArtifacts(File topReportFile)` returns
  `List<ScriptReportArtifact>` in `top, lua, script, cases` order.
- `scriptReportSha256(List<int> bytes)` returns lowercase SHA256 hex.
- `ScriptReportExporter({ScriptReportSavePicker? pick,
  ScriptReportReadUri? readUri, ScriptReportWriteUri? writeUri,
  bool Function()? isActive})` retains one export lane.
- `export(ScriptReportArtifact artifact)` returns
  `Future<ScriptReportExportResult>`; `dispose()` rejects later writes.
- Picker/read/write hooks match `PickerService.saveDocument(suggestedName:)`,
  `readUri(String)` and `writeUri(String, Uint8List)` from shared core.

`ScriptReportArtifact` carries `role`, `basename`, `file`, `reportDirectory` and
inventory-time `exists`. Receipt `toJson()` carries `role`, `basename`,
`sourcePath`, `runDirectory`, `state`, nullable `sourceBytes`/`sourceSha256`,
`destinationPath`/`destinationUri`, `destinationGuard`,
`readBackBytes`/`readBackSha256`, `message` and stringified `error`.
`sourceBytes` and `readBackBytes` are byte counts, not payloads.

## 3. Contracts

QuickJS uses retained, hash-verified sources; no Node/browser/OS/network bindings
are installed. ES modules resolve explicit relative paths inside the supplied
project snapshot map. The official TypeScript compiler is loaded from Flutter
assets, with an explicit file override only for tools/tests. Checks evaluate the
trusted compiler only; user source is an argument, never inserted into generated
eval text. TS diagnostics cover syntax/options, not semantic project types.

Each native operation owns a fresh VM and has heap, stack, source, output,
project-file-count and timeout limits. Cancellation token lifetime includes
snapshot preparation through native completion. FFI lengths are byte lengths;
returned diagnostic ranges are UTF-16 half-open positions in the original text.
Preserve exact unsaved CRLF/Unicode and revisions. Missing, duplicate, foreign,
oversized or failed snapshots produce unavailable results, not invented errors.

Shell analysis pipes text into the absolute parser with execution disabled,
predictable locale and startup-script environment cleared. Drain both streams,
bound output and wall time, and await process termination. Do not create a source
file or invoke PowerShell for `.sh`. OHOS runtime discovery checks system sh;
its target availability must be demonstrated by an actual target run.

Shell execution is noninteractive: open the project's regular `input.txt` before
launch, feed its exact bytes in bounded chunks, and close stdin at EOF. Missing
input means immediate EOF. Reject nonregular/unreadable input before source
execution; a child closing stdin early must retain its actual exit status.
The product wrapper drains both output streams immediately. Stop delegates only
to `ManagedProcess.cancel()` and then waits for input cleanup and observed output
completion. Never force a root PID, cancel output subscriptions or synthesize130
to satisfy a deadline. Pending cancellation keeps the run result and output open.
Cancellation errors propagate to the caller while actual exit/input/output
observation continues. When those observations settle, a failed Stop still
completes the result with an error instead of status130. The supervisor caches
failed cancellation attempts; repeated Stop returns the same attempt and does
not claim a new cleanup retry. No bounded-success promise replaces ownership.
A Boolean Windows tree-termination command or direct fallback does not prove all
Windows descendants exited; exact private-Job verification remains independent.
Common-core commit `9b0c01f` adds Linux descendant tracking
through verified pidfd/procfs ancestry and bounded TERM-to-KILL cleanup. Its four
actual Linux tests prove owned descendants terminate, final output survives and
an unrelated sibling remains alive; the owner also reports 48 focused tests.
This does not establish OHOS support. Other POSIX systems, old-libc/procfs
fallbacks and detached ancestry retain their stated limits; direct-PID fallback
is not evidence of complete descendant cleanup. Native Lua/Script Stop retains
captured output emitted before cancellation and the real status.

All selected ABIs need `libqfli_script` alongside Lua and Flutter. Native-only
legacy GCC/MSVC can build Lua alone; Windows app packaging must require an
explicit modern-compiler Script DLL or fail with the build prerequisite.
Retained hash-pinned runtime/compiler inputs must use nested Git attributes
with `-text`, including QuickJS and `assets/runtime`. Preserve upstream bytes
and license notices rather than trimming their whitespace. A worktree hash is
insufficient: verify candidate Git blobs and checkout filters also retain the
recorded digest when `core.autocrlf=true`.

### Audit-report provenance and byte transfer

The page creates `<storage>/qfli-script-acceptance-runs/run-<unique>/reports/`
for each attempt, with four basenames:

```text
qfli-script-acceptance.json
qfli-script-acceptance.json.lua.json
qfli-script-acceptance.json.script.json
qfli-script-acceptance.json.script.json.cases.jsonl
```

The helper derives all four names beside the supplied top file.
Missing artifacts remain listed but unavailable; never substitute an older
attempt's companion. Inventory appears after completion or settled fatal
checkpoint persistence. The page prefixes each artifact tile and receipt, and
sets export-log `attemptLabel`, solely from `_summary['executionComplete']`:

| Value | Exact attempt label |
| --- | --- |
| `true` | `Attempt: execution complete (acceptance gates separate)` |
| `false` | `Attempt: partial/failed execution` |
| Missing/unknown | `Attempt: status unavailable` |

These labels do not change transfer verdicts or acceptance flags.

Choose a destination before reading source bytes. Preserve raw JSON/JSONL bytes,
including Unicode, CRLF, final-LF differences and embedded/malformed bytes. Do
not parse/reserialize, append an extension, derive another destination, or use
whole-app backup/text sharing. A nonempty local `path` takes precedence over a
URI. Write local bytes with flush or await `PickerService.writeUri` using the
unchanged opaque URI. Read back through `File.readAsBytes` or `readUri`; only
matching byte length and SHA256 produce `verified`. Transfers buffer one whole
artifact; the current picker API supplies no streaming guarantee.

Physically resolve the source and destination, or their longest existing
ancestor plus remaining tail, before canonical comparison. Do not lexically
collapse `..` before resolving links: POSIX resolves a preceding symlink first,
whereas Windows resolves the dot segment first. Fold case only on Windows.
Require the source inside its own report directory. Refuse a local destination
equal to or inside that directory, including aliases, companions, new names
and symlinked parents. Unresolvable/dangling links fail closed, with no lexical
fallback. These are check-time physical-path guards, not an atomic filesystem
reservation. URI local mapping stays unproven: `opaqueUriUnverified` can coexist
with byte-transfer state `verified`; never invent a local or `hdc` path.

Keep one exporter per page and one busy lane. Check disposal/run activity at
entry and after picker/source reading before starting a destination write.
Disposal cannot cancel a write already started. Clear busy state in `finally`.
The page binds top receipt `sourceSha256` to the settled success/failure
`reportSha256` log value as `digestBoundToLoggedReport` (`true`, `false`, or
`null` when not comparable). `QFLI_SCRIPT_REPORT_EXPORT` logs that binding,
receipt and attempt label. Binding, transfer verification and execution/device
acceptance remain independent; never rewrite source reports or acceptance flags.

## 4. Validation & Error Matrix

| Condition | Outcome |
| --- | --- |
| Actual clean parse/run | Status 0 |
| Source syntax error | Status 3 with actual source diagnostic |
| Runtime failure | Status 1 with captured error |
| Timeout / cancellation | Status 124 / 130 |
| Missing VM/compiler/preparation | Status 127, analyzer unavailable |
| Bare/remote/escaping module | Runtime error, no network or external read |
| TS semantic type mismatch only | No semantic-check claim |
| Shell failure without recognized source location | Analyzer unavailable |
| Shell input missing | Close stdin, immediate EOF |
| Shell input is nonregular or cannot be opened | Status 127 before execution |
| Child exits before consuming input | Drain streams and preserve real exit status |
| User stops native execution | Preserve pre-stop output and actual cancellation status |

### Audit-report export outcomes

| Condition | Receipt state / destination guard |
| --- | --- |
| Read-back length and SHA256 match | `verified`; `verified` getter true |
| Picker cancelled | `cancelled`; no source-byte read or destination write |
| Neither nonempty path nor URI | `invalidDestination` |
| Local destination inside report directory | `destinationUnsafe` / `insideRun` |
| Local physical path cannot be proved outside | `destinationUnsafe` / `unprovablePath` |
| Local path proven outside | Continue with `outsideRun` guard |
| Opaque URI | Continue with `opaqueUriUnverified`; local mapping is not established |
| Source missing, foreign or unreadable | `unavailableSource` |
| Destination write acknowledged, read-back unavailable | `writtenUnverified` |
| Read-back differs in length or SHA256 | `digestMismatch` |
| Picker/write failure | `failed`; do not assume a failed write left the destination untouched |
| Disposed/inactive before write, or lane occupied | `abandoned` / `busy` |

`wroteDestination` is true only for `verified`, `writtenUnverified` and
`digestMismatch`. Destination-guard refusals occur before source-byte reading and writing.
Retain originals and permit retry; never delete the selected destination to
undo a failed export, since it can be an existing user document.

## 5. Good / Base / Bad Cases

Base: JS prints an array sum and TS emits then runs a typed local variable.
Good: dirty emoji/CRLF syntax error maps back to the original UTF-16 buffer;
correcting it clears diagnostics without changing disk or creating side effects.
Bad: parser catches a missing DLL and reports an empty clean result.

Audit export base: save one current artifact to an outside local path and verify
its exact bytes. Good: an opaque URI round-trip matches bytes while the receipt
still says its local mapping is unproven. Bad: an old companion or successful
export is presented as a complete, accepted device run.

## 6. Tests Required

Run actual native tests for JS/TS modules, syntax-only nonexecution, Promise
jobs/rejections, original dependency locations, embedded NUL and cancellation.
Run adapter tests for revisions/paths/missing backends and exact offsets. Shell
tests include substitutions, `source`, `exit`, and loops that must not execute
under `-n`. Test runner profile wiring, then inspect current HAP libraries,
symbols, compiler/catalog hashes and permissions. Host proof is never device proof.

The HAP payload gate must include the three shared catalog assets used by the
complete audit, alongside product content/runtime assets. Resolve the core
package from the app's actual `.dart_tool/package_config.json` and require it
matches the declared `../qfli_studio_core` dependency. Missing or ambiguous
source/asset bindings fail the gate. Receipts record logical asset keys, source
paths and expected hashes against packaged hashes. Archive inspection cannot
prove the selected Dart entry or authenticate signing; record those separately
from the build invocation and SDK signature verification. Package inspection
always leaves installed-device acceptance false.

The complete audit entry is `bin/script_acceptance.dart`, the default target of
`tools/build_ohos_audit.ps1`. Its independent denominator is 1,282 locations:
682 Lua and 600 JavaScript/TypeScript/Shell, with no code deduplication. The older
`bin/lua_catalog_audit.dart` remains an explicit Lua-only target. Per-case JSONL
is flushed before final reporting. Keep exact output and terminal-line gates
separate: 800 original expected values omit a final LF, while all 480 current
Lua locations must match exact bytes. Do not rewrite expected outputs from
captured results or present line-policy success as strict-byte success.

`SCRIPT_FULL_ACCEPTANCE=true` opts the full host test into this audit. It checks
the current runtime identities, counts, dirty-snapshot analyzer probes, native
debugger probes and shared debugger-adapter probes. Compare canonical paths
using the platform path library, not raw Windows separators. A host report must
leave device acceptance false. Package inspection must verify every native
symbol that the shipped Dart FFI loader looks up, in addition to library ABI,
assets, hashes and offline permissions. A successful HAP build/inspection alone
does not prove the installed audit ran.

`runScriptOfflinePlatformProbe` separately invokes the actual OHOS platform
channel for `openAgreement` and `openUrl`: 14 argument vectors per method,
bounded to two seconds each. Only `PlatformException(code: 'OFFLINE_ONLY')`
passes; success, other errors, missing channels and timeouts fail. Host runs
report `not_evaluated`, with no native calls. Injected test calls or OS identity
can never become native evidence. Both device gates additionally require the
actual native probe; host runtime gates remain independently interpretable.

### Audit-report assertions and evidence status

`test/script_report_export_test.dart` exercises the real picker boundary with
`forcePlatformChannel`, resetting the hook/handler after each test. A mocked
`saveDocument` response crosses `StandardMethodCodec`; return its wire payload
`Map<String, Object?>` (for example `{'uri': uri}`), or null for cancellation.
Do not return `PickedDocument` from a method-channel handler. That custom Dart
object is not supported by `StandardMessageCodec` and fails before picker
conversion or export lifecycle checks. Deferred picker tests must complete a
`Completer<Map<String, Object?>?>` with the same payload. Preserve:

- Exact path/URI bytes, basename, byte counts and source/read-back hashes;
  no appended extension, extra destination or source mutation.
- Cancellation/invalid selection, busy serialization, disposal/run replacement,
  write failure/retry, read-back failure and digest mismatch remain distinct.
- Four-name current-attempt inventory excludes old companions; missing sources
  do not open a picker; fatal checkpoints retain false acceptance flags.
- Receipts retain source/run identity and opaque URI limitations.
- Self, companion, new in-directory name, normalized alias and symlinked parent
  destinations are refused; outside destinations succeed.
- Symlink followed by `..` physically re-entering the report directory is
  refused on POSIX; Windows records an explicit platform-semantic skip.
  Hosts without symlink support record the actual skip reason. Dangling links
  return `unprovablePath`; original source/companion bytes stay unchanged.

These authored assertions are not pass receipts. This spec update ran no SDK,
tests or runtime: exporter runtime and actual OHOS picker/save/read-back/host
collection evidence are **UNRUN in this assignment**. Record their later exact
source-bound receipts separately. Mock URI tests do not establish device
permissions, host retrieval or installed full1282 acceptance.

Shell cancellation regressions inject a `ProcessSupervisor` through the existing
`ProcessStarter` seam. A process double asserts a pending tree request shares one
Stop future, keeps output/result open and retains the active owner even after
root exit. A throwing cancellation keeps observations/ownership until actual
exit, propagates the original error and never reports130. These tests launch no
real process and prove no Windows descendant containment. Preserve the real
1MiB blocked-input/ignored-TERM scenario; the outer exact private Job must retire
naturally. Forced cleanup fails that integration gate.

The Shell runner platform regression tests exercise an injected Android route
through a real host shell, missing Android discovery returning127, and unsupported
platform rejection before discovery. This is host branch coverage, not Android
or OHOS installed execution. Their runtime status remains UNRUN until a fresh
named verification gate.

## 7. Wrong vs Correct

Wrong: use regex to erase TS annotations, then call it a compiler.
Correct: use the bundled compiler's `transpileModule` and preserve its diagnostics.

Wrong: choose a compiler from cwd or silently omit a packaged native library.
Correct: bind the compiler to shipped assets and verify every requested ABI.

Wrong: normalize `external/link/../report` lexically and declare it outside, or
label an acknowledged URI write as verified without read-back.
Correct: resolve platform physical-path semantics before comparison, fail closed
when resolution is unprovable, and require matching read-back length/SHA256.
Keep `opaqueUriUnverified` even when that byte comparison succeeds.
## Scenario: coordinated host validation ownership

### 1. Scope / Trigger

Apply this contract when a host validation grant requires an automatic final
ownership release. Validation results and ownership release are separate facts.
The ignored `python-owned-command-v1` observer is source-only until independent
review, explicit coordinator protocol approval and a later named grant.

### 2. Signatures

The observer accepts `GrantEvent`, exact `GrantText`, `NextOwner`,
`PreparedManifest`, `PreparedManifestSha256`, `MaxSeconds` and `TotalSeconds`.
The Python bridge accepts `--request`, `--request-sha256`, `--helper`,
`--helper-sha256` and `--python-sha256`. Request `kind` is `ack` or
`owned-command`. Use the byte-identical reviewed ctypes `OwnedJob` helper.

### 3. Contracts

Freeze complete product/core source inventories and HEADs, the proposed Git
tree, scripts and Python executable. Bind actual protocol approval and later
grant events. Atomically claim each grant once. Requests bind command, cwd,
output/result paths, observer/grant identity, absolute `executionDeadlineQpc`,
`qpcFrequency` and cleanup reserve. ACK, validation and final publishing each
use suspended creation, private Job assignment before resume, and retained
root HANDLE/PID/creation-time evidence. The observer retains every bridge.

### 4. Validation & Error Matrix

Hash/inventory/event drift refuses before ACK. An unconfirmed ACK forbids SDK
launch. Child exit nonzero is an application result, independently of terminal
root/Job-zero cleanup. Uncertain cleanup retains exact handles and persists
HOLD. A report-write failure must not unwind uncertain ownership. Job closure
is permitted only after terminal/root and active-zero observation. A live
control-plane sender never claims its own future terminal state.

### 5. Good / Base / Bad Cases

Base: ACK Job finishes, validation fails analysis, all owned Jobs finish, and a
bounded final publisher reports the failure honestly. Good: all required phases
also pass while device acceptance remains independently false. Bad: root exit,
pipe EOF, kill-on-close or elapsed runner time is treated as complete release.

### 6. Tests Required

Source parsing does not prove Windows execution. Under a fresh named grant,
check natural exit, exact timeout cleanup and an unrelated surviving sibling.
Observe nested Jobs, actual bridge terminal/result and final publisher terminal
before successor eligibility. Charge request/hash/startup/report IO against the
same clock. Require the observer's post-write timing observation. Late completion
remains failed-budget even if payload tests passed. The original tool's actual
terminal confirmation must also meet the total handoff deadline; an internal
post-write sample cannot stand in for that later observation. Record a late
confirmation as a failed handoff budget even when source/tests and natural
cleanup passed. Preserve partial/unavailable
results and record runtime controls as UNRUN until actually executed.

### 7. Wrong vs Correct

Wrong: close an uncertain Job, dispose the only root handle, then infer cleanup.
Correct: retain exact ownership on HOLD until terminal and active zero are
observed. Never promote a later cleanup into an earlier bounded success.
