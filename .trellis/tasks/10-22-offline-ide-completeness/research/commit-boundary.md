# Commit boundary and preserved work

Baseline: Lua `main` at `327b7c5`. Initial status was captured on
2026-10-21T18:22:57.605Z and contained32 dirty/untracked paths. Current task is
in progress; stage exact paths only after final serialized checks, never `git add .`.

## Product integration to review and commit

The runtime, content, tools, analyzers and real debugger are one product behavior
boundary. Include their Dart/native sources, bundled compiler/runtime licenses,
product-owned content and generator/verifier, matching focused/integration tests,
native packaging integration, and the audit entrypoints/build inspector.
No generated DLL/HAP/build directories are source changes.

Some related integration was already authored before this task: Lua default
`input.txt` support, Unicode regular-file checks, initial ARM64 packaging filters,
native startup progress, code import tests and runner routing. Preserve their
behavior, review them with the current implementation and record their provenance
rather than claiming new authorship. The current changes extend these areas and
the clean commit must include all source/test dependencies it requires.

Review startup as a separate related batch: `lib/main.dart` startup function,
`ohos/entry/src/main/ets/pages/Index.ets`, the preserved startupProgress branch in
EntryAbility, and `test/startup_test.dart`. Product profile imports/settings in
main belong to the offline IDE batch. Prefer selective staging if these batches
can compile and test independently; otherwise document the integration dependency.

Offline shell integration includes removal of AccountKit/browser/remote agreement
registration and INTERNET permission. It preserves existing picker/share/startup
behavior. The native ABI selection now supports explicit x64 and keeps ARM64 as
the IDE default. Package inspection and actual device execution are separate gates.

## Leave outside staging

- Existing app icons: `assets/app_icon.png`, OHOS AppScope app_icon and entry icon.
- Existing signing/credential configuration: `ohos/build-profile.json5`.
- Existing local metadata: `.codex/`, `.trae/`, `.gitattributes`, root `AGENTS.md`.
- Existing unrelated Trellis tasks10-01-content-code-import,
  10-08-ohpm-lock-repair and10-09-terminal-polish.
- Existing untracked remote `AgreementReader.ets`: preserve on disk unused;
  clean-checkout tests must not require this unstaged file to exist.
- Scratch `.tmp_bytecode_block.txt` and any generated or captured build output.
- All sibling product and common-core files, including their current dirty work.

The tracked OHOS module also contains an earlier deviceTypes expansion. Review
that hunk separately and leave it unstaged if not required by this task.
Main-pages route currently matches HEAD after removing its pre-existing remote
route; no forced change is needed just to create a diff.

Retained QuickJS and TypeScript inputs carry narrow nested Git byte-retention
rules. These are new product-source prerequisites, separate from the unrelated
root `.gitattributes`. Keep the compiler/license/notice bytes intact. Vendor
whitespace is retained deliberately; authored sources still require whitespace
checks. The TypeScript compiler digest must survive both Git staging and a
Windows `core.autocrlf=true` checkout, not just match the current worktree.

## Review candidate, not a publication

Root prepared an alternate-index candidate under
`build/offline-ide-audit/source-candidate-*`. It includes exact selected source,
tests, content, retained dependencies and task/spec files; the actual user index
was byte-verified unchanged. The unrelated `deviceTypes` hunk is restored to
phone in the candidate blob only, while the worktree keeps its original change.
No icons, signing configuration, local editor metadata, unused agreement page
or sibling/core files enter the candidate. Each candidate has per-file hashes,
Git blobs and a tree ID. This is not a commit, final verified source freeze or
new HAP. Regenerate after final source/spec edits and serialized checks.

## Publication gate

Grant871 passed controls, formatting/analysis, the complete373-pass/1-skip
Flutter suite and all20complete1282 host-acceptance assertions. All exact Jobs
retired naturally. Historical800final-LF strict-byte mismatches remain. The
actual original-tool terminal observation took355967ms after ACK, exceeding
the330000ms complete-handoff budget; internal245544ms is not a broader pass.
See lua-host-gate-20261026.md and its exact source/terminal receipts.

A new reviewed candidate must bind the formatter-produced Shell test bytes.
Publish this verified foundation with the three READMEs, preserving the excluded
work above. Use an explicit staged-file review, Conventional Commit and normal
pushes. No commit may claim complete R1-R14 or installed acceptance. Fresh
complete1282 audit HAP, actual OHOS run, report retrieval and normal-app restore
remain open. Common-core and sibling gates retain their own ownership and
source/commit/device boundaries. Future runtime work needs a new named grant.