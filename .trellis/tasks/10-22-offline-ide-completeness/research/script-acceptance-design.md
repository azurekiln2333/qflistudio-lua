# Script packaged acceptance design — 2026-10-22

Root delegates only `bin/script_acceptance.dart`, its test and this design.
Existing runtime, analyzers, Lua audit, content, product startup and platform
files remain peer-owned. No delegation, device operations or native rebuilds.

The gap is a durable complete-product runtime acceptance entry, spanning the
682 shipped Lua locations and 600 original JS/TS/Shell locations. Reuse the
actual exported `auditBundledLuaCatalog({workspace,reportFile,bundle,toolchain,
onProgress})` from `bin/lua_catalog_audit.dart`; do not copy its Lua executor.
Load shared tutorial/example assets through the existing typed ContentCatalog.
Keep all 100 lessons and 100 examples per added language even if payloads match.
Independently enforce 682+600=1282 locations and 480 current Lua exact cases.
Missing assets, removed/duplicated identities, unsafe fixtures and unexpected
counts are failures, not skips. Original tutorial fixture provenance is explicit:
own lesson fixtures or linked example fixtures when no lesson fixtures exist.

Every source and fixture stays exact, with SHA256. Run each JS/TS case through
real ScriptToolchain and each Shell case through the absolute executable from
findPosixShell, without runInShell, in a fresh app-owned project. Bound time and
output, close stdin, drain both streams, cancel/kill on watchdog, and retain an
unfinished worker's directory instead of deleting files in use. Native pending
execution aborts later cases with explicit not-run observations. Record runtime
version/path/binary hash; include the official packaged TS compiler asset hash.
Native mapped library paths on OHOS/Linux or exact adapter candidate selection
on desktop provide binary provenance; unavailable hashes remain visible.

Checkpoint each completed case to a flushed append-only JSONL file, and retain
the complete final JSON case list. The existing Lua subreport already flushes
after each case; the top report references it plus its hash. JSON checkpoint
replacement uses a prepared adjacent file. Keep raw stdout/stderr/status and
strict comparison false when expected output omits a final LF. A separate
LineSplitter line-list comparison matches the old terminal rendering policy;
it never trims whitespace or drops blank lines. Exact all-shipped acceptance
and terminal-line acceptance are different fields. Current 480 Lua content
continues to require exact output in either acceptance policy.

Add genuine LuaDebugger smoke with source snapshots: initial pause before
output, primitive locals, nested step into/out and over, actual frame depths,
breakpoint add/remove, final resume/output and paused stop unwinding a `<close>`
local with exact cleanup output and status130. Use current APIs and owned
fixture projects, never an emulated debugger. Add dirty JS/TS/Shell analyzer
probes against exact CRLF/UTF16 snapshots followed by corrected side-effecting
code: hashes of intentionally different saved files must remain unchanged and
marker files must remain absent. Parser failures stay unavailable. Shared core
UI/stale-result rendering remains a separate root acceptance domain.

The Flutter page resolves app-owned storage via AppPaths/AppPrivateRoots, runs
the full audit after its first frame, displays progress/report path, and emits
`QFLI_SCRIPT_ACCEPTANCE` with final report hash and strict/terminal gates. Host
reports always have device gates false; only Platform.operatingSystem==ohos
can set an OHOS device gate, and only after all corresponding checks passed.
Root can pass separately verified domain reports; unprovided domains are
explicitly not evaluated and never implied by runtime acceptance.

Tests inspect the actual full inventories without executing all600. Small real
JS/TS/Shell cases test source/fixture persistence, comparisons and checkpoints.
Actual small debugger/analyzer fixtures prove probes; counts/duplicates,
truncation, missing engine/shell and no-execution safety get direct assertions.

## Implemented verification and handoff

- Default focused fixtures: **8/8 PASS**, including real JS/TS/POSIX execution,
  raw-vs-terminal comparison, independent1282 inventory, separate identical
  locations, unsafe/missing backends,13 real debugger checks and9 dirty-parser
  checks. The paused-stop probe retains both NUL-bearing cleanup stdout and the
  actual `Lua execution cancelled` stderr diagnostic with status130.
- Final scoped Dart analysis: no issues; both Dart files formatted. Root owns
  the final suite after the last checkpoint/metadata assertions were added.
- Binary identities are persisted before any Lua case starts, so interrupted
  Lua subreports retain matching top-report runtime hashes. Script cases append
  and flush one JSONL record each before progress notification. Pending runtime
  cancellation retains its fixture directory and prevents subsequent probes.
- Explicit full audit registration exists only with
  `--dart-define=SCRIPT_FULL_ACCEPTANCE=true`. Normal tests do not register a
  skipped whole-corpus test. The full integration fixture uses rootBundle and
  current default real engines, a15-minute timeout, and an owned temporary
  workspace under `build/offline-ide-audit/script-host-runs/`.
- Full report path: `build/offline-ide-audit/script-host-current.json`, plus
  `.lua.json`, `.script.json`, and `.script.json.cases.jsonl` subreports. It
  asserts coverage/execution/runtime identity/current480 exact/probes/terminal
  comparison, while preserving old raw exact mismatches as false strict gates.
- The full1282 integration audit was **not executed by this worker**, as root
  explicitly owns serialized host and target execution. Build the app entry
  with `-t bin/script_acceptance.dart`; final UI/log marker is
  `QFLI_SCRIPT_ACCEPTANCE`, carrying report path/hash and both gate policies.

Repeatable host command (root runs after other focused workers release):

```powershell
& D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe `
  D:/ProgramFiles/flutter_ohos/bin/cache/flutter_tools.snapshot test --no-pub `
  --concurrency=1 --dart-define=SCRIPT_FULL_ACCEPTANCE=true `
  test/script_acceptance_test.dart
```

## OHOS offline bridge proof — 2026-10-23

The acceptance entry now records `offlinePlatformProbe` before loading or
executing the catalog. On OHOS its default call path invokes the actual
`qflistudio/platform` MethodChannel. Both `openAgreement` and `openUrl` receive
14 vectors each: HTTPS, HTTP, network-relative, mailto, tel, custom, javascript,
file and data URIs, a malformed URL, absent arguments, absent URL, a non-string
URL and a non-map argument. Each invocation has a two-second timeout. Only a
`PlatformException` with exact code `OFFLINE_ONLY` passes; successful null/true
results, different error codes, notImplemented/missing channels, transport errors
and timeouts fail. The probe invokes no login, picker or sharing method.

Host runs return `evaluated:false`, `status:not_evaluated`, `ok:false`, no checks
and `nativeEvidence:false` without invoking a native method. This does not alter
host runtime strict or terminal-line gates. Both OHOS device gates now also
require `offlinePlatformGatePassed`, which requires actual native probe success.
The injectable OS/call seam always labels its evidence `injected` and cannot
produce native evidence, even when all simulated errors match `OFFLINE_ONLY`.

The persisted report retains every method, vector, exact argument and observed
outcome/error code. `QFLI_SCRIPT_OFFLINE_PLATFORM` emits a bounded summary marker;
the final acceptance UI/marker shows evaluation, status, pass, evidence kind and
the native gate separately. The 1282 inventory, per-case output comparisons and
host runtime gating stay unchanged.

Added source tests cover host non-evaluation, all 28 injected rejection calls,
success/null/true, wrong codes, missing bridge, unexpected errors, timeouts, and
the aggregate failure caused by one successful call. The opt-in full audit now
asserts native offline proof on OHOS and explicit non-evaluation on hosts.

Verification for this increment is source/static review only, per the root's
serialized execution restriction. Formatting, Dart analysis and runtime tests
are pending an explicit execution slot; no new pass claim is made here.
