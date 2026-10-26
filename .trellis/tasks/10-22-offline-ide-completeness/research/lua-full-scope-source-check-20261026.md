# Full-scope Lua umbrella source check — 2026-10-26

Scope: R1–R14, product source adapters, content/runtime assets, audit/export,
publication candidate and authored verification coverage. This is a source-only
review. C owns the host slot and all shared-core writes. Only this report was
written. No SDK, formatter, analyzer, tests, CMake, native process, package or
device command ran.

## Finding identified and subsequently repaired

### F1 — Android Shell Run contradicts the offered discovery path

`lib/lua_runner.dart:46` permits Shell execution only on Windows, Linux, macOS
or OHOS. Android reaches `_notReady` before `_commandFor` and therefore before
`findPosixShell`, even if `/system/bin/sh` exists. In contrast,
`lib/shell_code_analyzer.dart:12` explicitly discovers Android `/system/bin/sh`
or `/bin/sh`, and the README describes that Android discovery route. The
product profile offers `.sh` without a platform-specific exclusion.

The check/run split is concrete: Shell diagnostics can select the Android
parser while Run always returns unavailable. This restriction is inherited
from the earlier desktop-only runner but remains in the current integration.
`test/lua_runner_shell_test.dart` exercises real host discovery/execution and
has no injected Android platform branch, so the existing host pass cannot
catch it.

Root should make an explicit product choice: enable the same supported Android
runtime route with a platform-selection regression and later target evidence,
or state the current Android Run restriction consistently in capability/docs.
Do not claim Android Shell execution merely from parser discovery. Source was
frozen/owned elsewhere, so this reviewer did not change shipping code.

## Source coherence reviewed

- `lib/main.dart` wires the real runner, product analyzer, debugger, local
  content factory, terminal delegate, tool tab and editor actions. Offline is
  explicitly enabled. The visible entry list covers Lua/bytecode, JS/TS and
  Shell; the profile declares `.lua/.luac/.js/.mjs/.ts/.sh`.
- `ProductCodeAnalyzer` routes Lua, JS/TS and Shell to their actual providers.
  Unsupported languages return unavailable. Providers distinguish missing,
  duplicate, foreign, stale and oversized editor snapshots from a clean parse.
  They return offsets in the original Dart string. Compile-only native parsing
  and Shell `-n -s` preserve the no-user-program-execution contract.
- The debugger validates saved root-owned Lua files, rejects unsaved documents,
  and retains session/runtime cleanup after launch initialization failure.
  Host cleanup tests exist, but target execution remains a separate gate.
- Terminal Lua/luac commands use the bundled Lua toolchain. Unsupported flags
  produce errors. Tools expose nine direct tool definitions rather than one
  product gateway.
- The local content repository keeps Lua ownership and delegates non-Lua
  Script content to the shared filtered catalog. Actual Lua assets contain
  **240 example entries and 23 tutorial entries**. Pubspec includes both
  `assets/content/` and `assets/runtime/`.
- Highlighting tests cover every declared textual extension, case variants,
  exact CRLF/Unicode tokens and `.luac` binary refusal. Actual editor-analysis
  composition tests and named-workspace tests are present. Shared UI/state
  implementations remain C-owned and were not modified.

## Audit/export boundaries

The complete audit consists of **682 Lua locations + 600 JavaScript,
TypeScript and Shell locations = 1,282**. `bin/script_acceptance.dart:907`
checks all these counts separately. `_scriptLanguages` names only the 600
non-Lua component; it must not be used to describe all1,282 as non-Lua.
The current READMEs now state the correct split.

The opt-in `SCRIPT_FULL_ACCEPTANCE` test asserts terminal-line equivalence
while deliberately retaining strict byte-output mismatches in original
expected outputs. It explicitly asserts `allShippedExactGatePassed == false`
and overall `ok == false`. Therefore a future green host acceptance test can
mean the documented host/terminal-line gate passed; it cannot be relayed as
strict all1,282 exact acceptance or installed OHOS acceptance. Preserve the
800 historical final-LF differences rather than replacing expected output.

The exporter source contains one busy lane, active/dispose/run guard before
new writes, current-run four-artifact inventory, exact raw-byte copy and
length/SHA256 read-back. It distinguishes cancellation, unavailable source,
unsafe destination, failed write, written-unverified and mismatch. A failed
write does not prove that zero destination bytes were written. Opaque URI
mapping cannot be inferred from a string. The independent export review closes
B1/B2/B3 and the Windows/POSIX symlink/`..` test issue in source only. Its final
helper/test hashes match the reviewed files. Pi6 is separately changing the
page attempt labels after this reading; rebind its final hash after release.
No new concrete exporter blocker was found by this review.

## Candidate/publication review

Inspected `build/offline-ide-audit/prepare_source_candidate.py` and its existing
203-path candidate `source-candidate-20261025T185636541761Z` with read-only Git
blob commands. The helper uses a separate index and verifies the actual index
hash remains unchanged. The current actual index is empty.

- Explicit exclusions preserve app icons, signing build-profile and the
  unrelated AgreementReader file. The module overlay restores only the
  pre-task `deviceTypes` field in the candidate, leaving the worktree alone.
- The broad selected path prefixes require a final path-by-path review after
  regeneration; this is a candidate builder, not an authorship proof.
- The existing candidate is stale for the acceptance/export source and tests,
  all three READMEs and several research records. Do not commit this old tree.
- README command/link dependencies are present in the candidate but several
  are absent at HEAD. A docs-only publication would advertise absent tools and
  source wiring. A coherent source+docs candidate remains necessary.
- Candidate blobs for TypeScript compiler, TypeScript license and QuickJS
  `quickjs.c` exactly equal the current worktree bytes. TypeScript compiler
  SHA256 is `3ae902c92cc44dace175c0e69e13a4b0899f6983c6121d76b9ab8dd5795e7675`.
  Nested retained-input attributes are included. This spot check is not a
  substitute for the final complete provenance manifest review.

## Verification actually performed

- Read the task PRD/design/implementation and curated Lua/Script/content import/
  startup contracts, package indices, baseline and current evidence records.
- Static Python scan found no missing relative `.dart` import/export/part
  targets under lib/bin/test/tool. The first naive scan also matched JS text
  fixtures; a suffix/line-filtered scan removed those false positives.
- Read-only candidate/path/blob/byte checks described above.
- Actual Lua JSON entry counts 240/23.
- No shipping source, core, Git index, commits or remotes changed.

## Open gates and disposition

This is **not** a full quality pass. Analyzer/type-check/lint/runtime tests are
UNRUN under the granted source-only scope. The dated October24 suite passed
345 assertions, while the enclosing process-containment gate failed and
full1,282 was not executed in that attempt. New natural-drain controls and the
export helper need the fresh named host window. Root reports READY649 was explicitly withdrawn660 for the later
page attempt-label repair. A new readiness identity is required after Pi6
release. Grants are not inferred from readiness or silence.

Current core has live WIP beyond published HEAD; future verification must bind
actual source hashes before/after phases, not only `2f9039a`. The Lua launcher
contains that actual-file manifest mechanism. Current-source full1,282 HAP,
ABI/signature verification, reachable assigned OHOS device, report retrieval
and normal-app restoration remain separate open gates. Commit/push remains
open. R1–R14 remains active.


## Narrow re-review: Android Shell route repair

F1 is **closed in the reviewed source snapshot**. Pi3 added per-runner
`operatingSystem` and `shellFinder` seams. A null platform uses actual
`Platform.operatingSystem`; the real finder remains the default. The shared
supported-platform set now includes Android and controls both the launch gate
and unavailable-message selection. The finder is called for a supported Shell
route; missing discovery returns127 honestly. Lua and JS/TS return through
their pre-existing embedded branches before either seam is consulted.

The three authored regressions exercise: Android selection with an actual
host-discovered shell and captured output, Android discovery returning null
and status127, and an unsupported platform refusing before discovery. The
host-backed test explicitly skips if no real shell exists. It proves only the
injected Android selection when later run on the host, not an Android device.
No synthetic output or mocked successful process replaces the real command.

Static scoped `git diff --check` passed. Formatter, analyzer, test execution
and Android/OHOS target execution remain UNRUN. No new concrete blocker was
found in this narrow re-review. Source-ready for the next named host gate;
root must bind the final released bytes if Pi3 changes comments afterward.

Observed SHA256:

- `lib/lua_runner.dart`: `49bbb6c1d5f0f60f31c220768e4a7897a0b41c6463b9cfe5ab7b5cb0b1777f19`

- `test/lua_runner_shell_test.dart`: `b439bc7591be61a5736cd0fd2db168c93d97efc06b9ef69a3a75944534f46a81`
