# Lua packaged-content and diagnostic audit

## Boundary

The audit is an alternative Flutter entry at `bin/lua_catalog_audit.dart`.
It uses the actual package asset bundle, existing `LuaToolchain`, and existing
`LuaCodeAnalyzer`. It does not edit production startup, profiles, native code,
platform configuration, or shared-core files. Device/build ownership stays with
the root coordinator. No device commands were run by this worker.

## Complete inventory

The current package declares five relevant documents:

| Document | Required runnable locations |
| --- | ---: |
| Product `assets/content/lua_tutorials.json` | 240 lessons |
| Product `assets/content/lua_examples.json` | 240 examples |
| Shared package `assets/content/tutorials.json`, Lua only | 100 lessons |
| Shared package `assets/content/examples.json`, Lua only | 100 examples |
| Shared package `assets/tutorials/lua.json` | 2 legacy lessons |
| Total | 682 |

Counts are explicit release expectations, independent of the assets. Every
location executes separately, including identical tutorial/example bodies.
Missing documents, duplicate identities, count drift, current pair differences,
unsafe fixtures, and missing pairs are inventory failures. No missing entry is
silently skipped. Asset byte lengths and SHA256 hashes identify the package
content; each result retains source text/hash, expected output/status, fixtures,
actual stdout/stderr, exit status, and duration.

## Execution and durable evidence

The entry resolves storage using `AppPaths` and confirms it through
`AppPrivateRoots`. Each run creates its own audit workspace. Each snippet gets
a fresh project directory and Lua state. Fixtures preserve nested paths;
`stdin` maps to the runner's `input.txt`. Fixtures cannot replace `main.lua` or
leave the project. The audit does not normalize stdout or rewrite expectations.

The report is `<resolved app storage>/qfli-lua-catalog-audit.json`. It is flushed
and replaced after every location. Setup/fatal failures preserve completed
checkpoint rows. A native watchdog requests cancellation after the normal Lua
time limit plus ten seconds, then waits another five seconds for completion.
An unconfirmed worker retains its project, stops subsequent native launches,
and leaves acceptance false. Cancellation is never treated as termination.

The final screen displays `QFLI_LUA_CATALOG_AUDIT FINISHED`, the full report
path, counts, and gate values. The log line beginning
`QFLI_LUA_CATALOG_AUDIT ` includes the same concise summary and report SHA256.
The root coordinator can collect the named report using its authorized device
session. This worker makes no assumptions about the host-visible sandbox path.

## Exact output and legacy evidence

New curriculum stdout is compared exactly as returned by the bridge, without
whitespace or newline normalization; expected status is zero. Stderr is retained
verbatim. Original shared aggregate
expectations omit print's terminal LF, so their exact comparison is expected to
fail unless the package content is deliberately corrected by its owner. The
report records a separate comparison that removes at most one final LF/CRLF.
That compatibility observation never makes strict acceptance pass.

`allShippedExactGatePassed` and `deviceGatePassed` cover every shipped location.
`currentCurriculumGatePassed` and `currentCurriculumDeviceGatePassed` identify
the new curriculum separately. Inventory, actual Lua 5.4.8 identity, completed
execution, and the diagnostic probe remain mandatory for both. Only an actual
`Platform.operatingSystem == 'ohos'` run can set a device gate; host execution
cannot. OS version, Dart version and actual FFI ABI are recorded.

## Unsaved source probe

Two app-owned Lua files deliberately contain malformed disk text. Captured
dirty buffers use different text and revisions. The real analyzer checks both
active and module buffers individually with both snapshots present, verifies
exact UTF-16 ranges after Chinese text, emoji and CRLF, then checks corrected
unsaved snapshots without changing disk. The corrected code would create marker
files, delete source and require a nonexistent module if executed. The report
requires absent markers and unchanged disk SHA256s. All six checks are retained
with source snapshots, revisions, diagnostic ranges and messages.

This adapter probe does not claim shared-editor debounce, stale-result disposal,
wavy rendering, or Problems navigation. Those retain their separate workflow
tests and target UI gate.

## Build and verification handoff

The root coordinator builds with its approved serialized OHOS build procedure,
selecting `-t bin/lua_catalog_audit.dart`; no checked-in production entry or
platform configuration needs replacement. After collecting audit evidence, the
root restores the production application through the normal `lib/main.dart`
build. Target build, ABI inspection, installation, launch, screenshot/report
collection, and production reinstall are separate evidence steps.

`test/lua_catalog_audit_test.dart` protects all-location inventory, omitted and
duplicate payloads, exact output comparison, fixture safety, raw legacy mismatch
reporting, nested-file/stdin execution and the real diagnostic probe. The native
tests use the normal library lookup, or `QFLI_LUA_LIBRARY` when explicitly set.
They do not skip a missing engine. The worker coordinates any Flutter test run
with the root to avoid competing SDK/test processes.
