# Lua audit diagnostic path repair — October 24, 2026

Scope: `bin/lua_catalog_audit.dart`, `test/lua_catalog_audit_test.dart` and this
note only. No provider/core/runtime/build/device/index change, test execution,
SDK invocation or formatting command was performed by this worker.

## Observed failure and retained evidence

The granted C487/Lua494 full1282 host run completed every location. The owning
root retained its reports unchanged under:

`build/offline-ide-audit/final-verification/20261024T025852658Z-b8193c11985948ec9c7a042e0eea8561/host-reports/`

Read-only inspection of the preserved Lua subreport confirms that only
`dirty-active-crlf-unicode-error-range` and
`dirty-module-crlf-unicode-error-range` failed within the Lua diagnostic probe.
Both actual diagnostic ranges were exactly `[15,16]`, matching expectation.
The audit request path retained `build/offline-ide-audit` with forward slashes
inside a Windows path, while `LuaCodeAnalyzer` returned its normalized path
with backslashes. The probe's raw `filePath == file` therefore failed. Both
corrected snapshots, unchanged source hashes and absent side-effect markers
passed. The root's all1282 terminal-line/480current-exact and Script probe
observations remain evidence of that failed run, not a new whole-gate pass.

The archived manifest binds the top report to
`c6a702f0d6cf6d0c25283b06f444aba93baf7f3e1c2e4946c6ac9dd4c3745dd6`
and its Lua subreport to
`206e0861bc3947d9f1b59fc731ed15d5c33e33477d06c951cb688959f42bdaf9`.
This worker did not rewrite, regenerate or execute either report.

## Narrow repair

`runLuaDiagnosticsAudit` now resolves and normalizes the actual newly created
owned directory before constructing file paths, snapshots or analysis requests.
The original created directory remains assigned for cleanup if canonicalization
fails. The report preserves both `requestedWorkspacePath` and
`canonicalProjectPath`, matching the existing Script probe evidence pattern.

The exact one-diagnostic requirement, raw returned-file equality, exact UTF-16
half-open range assertions, availability checks, corrected-buffer checks,
unchanged source digests, absent execution markers and six-check gate remain
intact. The provider is unchanged. This repairs fixture ownership/identity at
the caller instead of relaxing a diagnostic assertion.

## Regression and pending verification

The new actual-parser regression deliberately passes a caller workspace with
both separator styles on Windows and proves the caller path was not already
normalized. It runs the real six-check dirty-buffer audit, verifies exact
returned file identities/ranges for both Unicode/CRLF sources, checks that both
snapshots belong to the canonical owned project, compares before/after source
hashes, requires absent side-effect markers and confirms project cleanup.
Other hosts retain the canonical ownership/no-write/parser checks.

Earlier tests created normal system-temporary paths, so they did not exercise
the mixed spelling retained by the complete audit's build-directory caller.
The new regression targets that caller boundary explicitly. Source review is
complete; formatting, analysis, this regression, acceptance and the final suite
remain UNRUN until the root obtains the next explicit host grant. No new pass
or device acceptance is claimed.
