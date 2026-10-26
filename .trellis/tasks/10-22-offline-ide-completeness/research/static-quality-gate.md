# Product static quality review — 2026-10-23

Reviewer: `/root/static_quality_gate` (`trellis-check`). Root assigned source-only
review while the shared host execution slot belongs to other coordinators.
Read the original attachment, the full saved hook context, `check.jsonl`, its
referenced specifications, PRD/design/implementation plan, and the current
Script toolchain specification. No shared-core, sibling, acceptance harness,
native runtime, signing, icon or startup edits were made by this reviewer.

## Findings fixed

- `test/lua_offline_platform_test.dart`: a regression assertion required the
  pre-existing untracked `AgreementReader.ets` to exist. The authored commit
  deliberately excludes that unused local file, so a clean checkout would fail
  despite correct offline routing. Removed the existence requirement. The test
  still requires the route table to contain only `pages/Index` and all other
  platform `.ets` sources to have no reference to `AgreementReader`.
- `lib/lua_code_analyzer.dart`: root, active and auxiliary document identities
  containing NUL were accepted if their lexical paths were otherwise inside the
  root. Only duplicate active documents were rejected; conflicting duplicate
  auxiliary snapshots could return a clean parse. Added NUL identity rejection
  and a normalized canonical key set for every snapshot, matching the frozen
  request validation invariant and the Script provider. Added a regression in
  `test/lua_code_analyzer_test.dart` with an intentionally successful parser
  stub, so an unavailable native library cannot mask the invalid-identity case.
- `tools/inspect_lua_hap.py`: the package gate checked four Lua exports and two
  Script exports, while Dart also requires token controls, result release and
  the remaining debugger functions. A missing `qfli_lua_debug_resume` or
  `qfli_script_free` could therefore pass package inspection and fail during FFI
  initialization. Added the complete actual required lookup sets (21 Lua and 6
  Script symbols). The optional copyright fallback remains optional. Symbol
  inspection also rejects hidden/internal dynamic symbols instead of treating
  their names as callable exports. ABI/asset/permission semantics are unchanged.
- `lib/lua_debugger_page.dart`: the direct debugger tool ignored
  `LuaDebugFrame.fileBacked`, so a generated `load` chunk labeled with the exact
  absolute path of a project file could preview and mark unrelated disk source.
  Gate preview/current-line mapping on native file identity, clear pending
  preview reads for generated/native frames, and show an explicit unavailable
  disk-source message. Selecting a genuine parent frame remains available.
  Added a real-runtime regression in `test/lua_debugger_page_test.dart` using a
  generated label equal to `main.lua`, followed by parent-frame selection.
- `assets/.gitattributes`: `core.autocrlf=true` was active while the
  byte-pinned compiler and retained license/provenance assets had no text rule.
  Added the narrow `runtime/** -text` rule so a clean Windows checkout preserves
  the actual vendor bytes and the pinned compiler hash. Keeping the rule above
  the declared runtime asset directory avoids bundling Git metadata. Removed
  only this reviewer's temporary `assets/runtime/.gitattributes`; that path is
  absent in the final source and temporary checkout. Compiler/license/notice
  content and the pre-existing root `.gitattributes` were not changed.

## Vendor byte-retention proof

Used a temporary `GIT_INDEX_FILE`, an empty temporary index, and only
`assets/.gitattributes` plus `assets/runtime` paths. For every retained payload,
`git cat-file blob :<path>`
matched its pre-operation working bytes exactly. Then
`git -c core.autocrlf=true checkout-index --all --prefix=<temporary checkout>/`
recreated all four retained payloads byte-for-byte. The formal repository index bytes were
captured before this operation and compared afterward: unchanged. All original
working asset bytes and the pre-existing root `.gitattributes` were likewise
compared afterward: unchanged. No source
candidate script, formal staging, Dart/native process, build or runtime test was
used. `git check-attr text eol` now reports `text: unset` for every path below.

The following SHA-256 values are identical for original, temporary staged blob,
and temporary Windows checkout:

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `typescript.js` | 9112572 | `3ae902c92cc44dace175c0e69e13a4b0899f6983c6121d76b9ab8dd5795e7675` |
| `TYPESCRIPT-LICENSE.txt` | 9197 | `a7d00bfd54525bc694b6e32f64c7ebcf5e6b7ae3657be5cc12767bce74654a47` |
| `TYPESCRIPT-ThirdPartyNoticeText.txt` | 37824 | `1af3c68039c57e539422da82a4faada506ce6d0ea6f90e0b699d02dbcdb7a90c` |
| `TYPESCRIPT-SOURCE.json` | 535 | `e2cadce1d20a9653fbb5da23330a1454321c4027ab99032e1267adf03227904b` |

The compiler hash also matches `compilerSha256` in the retained provenance JSON.

## Follow-up lifecycle finding fixed in source

Root subsequently granted `lib/lua_studio_debugger.dart` and
`test/lua_studio_debugger_test.dart` ownership to repair the reported stop error
path. `_stop()` formerly awaited `_runtime.stop()` before `_finish()` without
an error recovery path. A rejected stop skipped disposal and `done`; memoized
failed stop/dispose futures prevented recovery.

- Stop failures are retained in bounded console/message text while disposal is
  still attempted. No zero/success program exit code is invented.
- Independently observe the actual runtime `workerExited` future. A successful
  dispose acknowledgement cannot terminalize the session or complete `done`
  before that event. An unexpected exit also starts owned cleanup and retains
  a failure reason.
- In-flight stop/finish/dispose futures remain shared and idempotent. Rejected
  attempts clear only their own cache, allowing another cleanup attempt while
  the session remains stopping and rejects run/step commands.
- A rejected cleanup while the worker is alive preserves ownership, leaves
  `done` pending and keeps the update stream open. The actual Lua runtime has a
  nested disposal `finally` that can finish cleanup/exit and then propagate an
  earlier stop error; that case retains the failure and can finish the adapter.
- Added one protected, product-only `startRuntime` factory seam for controlled
  lifecycle transport tests; the shared interface/request and native ABI remain
  unchanged. No changes to `lib/lua_debugger.dart` were necessary.
- Added four regressions: stop failure still disposes and waits actual exit;
  incomplete cleanup retains ownership and permits dispose retry; unexpected
  worker exit is observed and cleaned up; an earlier stop failure propagated
  after completed cleanup remains failed. Assertions include output/error
  retention and update-stream closure only after `done`.

These four tests have been authored but not run during the held host slot.
There are no remaining concrete unfixed findings in this static review's
claimed product scope. The umbrella runtime/device gates below remain open.

## Reviewed paths and bounds

Read product profile/analyzer dispatch, all three syntax providers, the runner
and its input/cancellation wrapper, terminal delegate, direct tool pages,
debugger adapter and worker, package inspector/build script/Hvigor wiring,
OHOS route/permission/platform channels, and their current focused tests.
The reviewed source preserves actual-unavailable versus checked-clean results,
compile-only user-code checks, exact captured text and UTF-16 ranges, local
Tools cards, offline OHOS routes, and separate package/device gates. This review
does not establish their runtime outcome or close the umbrella R1–R13 ledger.

## Verification

- Python AST parse of `tools/inspect_lua_hap.py`: PASS.
- Static comparison of inspector export sets with the literal required FFI
  lookups in `lua_toolchain.dart`, `lua_debugger.dart`, and
  `script_toolchain.dart`: PASS; all 21 Lua and 6 Script required symbols covered.
- PowerShell AST parse of `tools/build_ohos_audit.ps1`: PASS.
- Runtime-asset temporary Git blob and `core.autocrlf=true` checkout identity:
  PASS for all four retained payloads; formal index, root attributes and original
  payload bytes unchanged. The narrow rule is `assets/.gitattributes`, outside
  both declared content/runtime asset directories.
- `git diff --check` for the claimed paths: no tracked whitespace errors;
  new/untracked files still require the root's final formatter/check pass.
- Dart lint/type-check: NOT RUN, respecting the current global host slot.
- Flutter/native/Python runtime tests, builds and package reinspection: NOT RUN.
- Device commands, installation and UI execution: NOT RUN.

Root must run the changed analyzer/page/offline tests, Dart format/analyze, and
all debugger adapter/runtime regressions, plus the updated inspector on the
freshly built final HAP after receiving the host slot. The Lua toolchain spec's
lifecycle paragraph should record retryable stopping ownership after cleanup
failure and the independent actual-exit gate. Existing historical reports are
not proof of these latest edits. The
full 1,282-location target audit and genuine debugger/diagnostic target gates
remain independent pending evidence.

## Static continuation — 2026-10-24

Reviewer: `/root/product_contract_review`. Re-read the full saved hook context,
the prior review, current analyzer/direct-debugger/shared-adapter/acceptance
sources and their targeted tests. Root accepted a new host window at global406;
this reviewer made no Dart/test edits during that frozen validation window and
started no formatter, analyzer, compiler, runtime, build or device process.

The targeted production calls do not require the currently dirty common-core
API additions: published core HEAD is still
`e025805b60435fdedafd33e60082dc660afebe5a`; `code_analysis.dart`,
`debug_session.dart` and `studio_profile.dart` have no working-tree diff.
`HighlightThemes.themeFor` gained an optional `ownerType` in dirty source, but
the Script highlighting tests call the already-published signature without
that argument. The bytecode-open test uses existing `EditorController.openPath`
and binary rejection; it does not use dirty `shouldOpen`/`shouldSave` parameters.
This is source/API compatibility evidence only, not a clean-core execution pass.

One error-preservation finding was sent to root for the next permitted source
change: `LuaStudioDebugger.launch` awaits cleanup in its `catch` before
rethrowing. A different cleanup rejection can therefore replace the original
initialization error. The lower `LuaDebugger.start` already guards cleanup to
preserve its original failure. Repair must also retain actual-worker-exit
ownership; simply ignoring an incomplete-cleanup rejection would weaken the
lifecycle contract. No code change or new pass is claimed for this finding.

Remaining current-source proof is root's serial format/analyze/focused result,
then whole suite and complete1,282 host rerun, current full audit HAP inspection,
actual OHOS execution/diagnostic/debugger/offline probes, and normal-main restore.
The current review leaves those gates open. Historical adapter/runtime passes
do not cover the latest lifecycle regressions or native offline probe increment.

## Initialization cleanup follow-up — 2026-10-24

Root subsequently authorized source edits only in
`lib/lua_studio_debugger.dart` and `test/lua_studio_debugger_test.dart`, plus this
review note. The pending initialization-error finding above is now repaired in
authored source; it has not received an execution pass.

- `launch` captures the original initialization error and stack, records them
  in bounded session failure/console text, and attempts owned disposal. If
  cleanup completes, it rethrows the identical original error with its original
  stack. A different stop/cleanup error cannot replace it.
- If disposal rejects before session `done` completes, `launch` returns that
  same stopping session. The editor controller retains its busy execution lane
  and a subsequent Stop can retry cleanup. No orphan registry or retry timer
  was added. `done` remains authoritative even if subscription cleanup rejects
  after actual worker exit.
- The rare pre-session constructor-failure path separately awaits the actual
  runtime exit after disposal, preserving the original error. The existing
  constructor/subscription layout and the shared API/native ABI are unchanged.
- Added two regressions: original error/stack identity after a different
  cleanup failure following actual exit; and incomplete initialization cleanup
  through the actual `EditorDebugController`, including retained busy lane,
  rejected second start/commands, retried disposal, and release after exit.
- The controller integration regression explicitly imports the currently
  unpublished C-owned `editor/editor_debug_controller.dart`. Root must bind
  validation to the composed core revision and retain the core publication
  dependency. The earlier production-call compatibility assessment does not
  establish this new test against published core HEAD.

Static reinspection found no additional concrete local issue in these two
files. Formatting, lint/type-check and tests were NOT RUN by this reviewer;
the current global host slot remains respected. Root's previous analysis exit
0, focused 125-test pass and formatter result predate these edits and do not
validate them. The prior125 preservation manifest distinguishes exact untouched
test bytes from reconstructed product source; no prior run-input source hash
was available, so no cryptographic binding to that run is claimed.

No shared-core source, formal index, staging, commit, device or build operation
was performed for this follow-up. Root retains final formatting, analysis,
focused/full-suite and complete1,282 acceptance checks. Suggested Lua spec
addition for root's owned integration step:

> After a post-creation initialization failure, preserve the original
> error/stack. Rethrow only after cleanup completes. If cleanup rejects before
> `done`, return the stopping session to the editor controller so Stop can retry
> and the execution lane remains owned until actual worker exit and disposal
> complete.
