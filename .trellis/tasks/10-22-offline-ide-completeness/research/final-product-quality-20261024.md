# Final product static quality review — 2026-10-24

Reviewer: `/root/product_contract_review`, dispatched `trellis-check`.
Active task: `10-22-offline-ide-completeness`. This is a source review and an
acceptance-boundary record, not a replacement for root's serial checks. No new
concrete Lua-owned source blocker was found in this continuation. No shipping
source, tests, config, core, staging, commit, build or device state was changed.
Only this report was authored. Root froze shipping inputs for the newly granted
C487/Lua474 window while this review was running.

## Context and coverage

Read the complete changed/untracked package list and task PRD/design/plan/check
manifest. Read backend/frontend/guides indexes and their quality files; the
generic quality files are placeholders, so the actual executable contracts are
`backend/lua-toolchain.md`, `backend/script-toolchain.md`,
`frontend/content-code-import.md`, and `frontend/native-startup.md`. Applied
their error matrices/required checks plus the cross-layer/reuse guides.

Reused `static-quality-gate.md`, `runner-final-review.md`,
`script-runtime-review.md`, the content/runtime/debugger designs, original and
current content evidence, `requirements-evidence.md`, and the source-attempt
and build-binding records. Historical findings already repaired were not
reported again as current defects.

Reviewed the affected package boundary as follows:

| Scope | Source reviewed or prior reviewed paths rechecked |
| --- | --- |
| Product wiring/config | `lib/main.dart`, `pubspec.yaml`, `analysis_options.yaml`, dependency/package configuration, current profile hooks and entry/extensions |
| Runtime/editor integration | Lua/Script runner/toolchains, Lua terminal commands, all four language analyzer routes, editor file tools, direct tools/pages and Lua debugger/runtime/shared adapter |
| Content | Lua content repository, product assets, authored topic generator/verifier and paired-content tests; shared aggregate content remains owner-controlled |
| Tests | Current focused/integration test inventory, new initialization-cleanup regressions, actual-profile named workspace fixture, highlighting/dirty analysis/import/offline/startup and acceptance tests |
| Audit entries/tools | `bin/lua_catalog_audit.dart`, `bin/script_acceptance.dart`, content audit/verifier tools; latest validation wrapper, builder and inspector are separately owned and are not edited here |
| Native/platform | Lua and Script native ABI/lifecycle, CMake linkage, retained-input attributes, OHOS ABI/profile/channel/offline configuration; read-only native explorer supplied the independent configuration pass |

Unrelated icons, signing configuration, deviceTypes, editor metadata, scratch
files, unused AgreementReader and peer changes were preserved. This report
does not assign authorship to pre-existing changes.

## Current dependency binding

Read-only inspection observed published core HEAD
`2f9039a3ba95449679b17257b0313c1ee3644a2c`. There was no working-tree diff in
the targeted analysis/debug/profile/controller/page/explorer/retained-host,
workspace or app paths. The actual package configuration resolves core to
`../../qfli_studio_core`, Flutter to `D:/ProgramFiles/flutter_ohos/packages/flutter`,
and re_editor to the sibling core's vendor directory.

The earlier warning that the new controller regression imported unpublished
core source is superseded for this observed published revision. Final execution
still needs the root's source/HEAD manifests; this read-only compatibility check
is not itself a test pass. Common core remains C-owned and was read only.

## Behavior and evidence findings

- The actual offline `luaProfile` wires the product runner, four-language
  analyzer dispatcher, bundled content repository, terminal delegate, individual
  tools grid, editor file tools and genuine Lua debugger. Its Script identity
  remains unchanged. All declared text extensions have grammar tests, while
  bytecode is handled separately rather than presented as editable source.
- Lua/JS/TS/Shell analysis retains exact unsaved text and revision identity,
  root ownership, UTF-16 ranges and honest unavailable results. Checks do not
  execute user programs or write source. TypeScript remains explicitly limited
  to syntax/options diagnostics, not semantic project type checking.
- Tools remain individual cards in the existing Tools tab. JS parsing and TS
  transpilation use actual embedded engines/compiler; Shell uses a discovered
  real parser with execution disabled. Missing parsers are not reported clean.
- Runtime routing preserves actual output/status, project stdin/EOF semantics,
  native cancellation-token lifetime and bounded direct-process Shell Stop.
  Existing Linux descendant evidence does not establish OHOS or every POSIX
  fallback; those documented limits remain.
- The delivered launch-error repair preserves the original initialization
  error/stack after completed cleanup. Incomplete cleanup returns the same
  stopping session, with `done` authoritative and Stop retry available. The
  actual controller integration test retains the busy lane through worker exit
  and disposal. Existing constructor subscriptions and shared APIs are retained.
- The actual-profile named-workspace test captures primary standalone-history
  bytes AFTER promotion and queue drain (line140), then compares them after
  full app disposal (line265). Its secondary standalone session owns the other
  project's history. Current core `_saveHistory` routes named sessions to the
  workspace document and returns; named explorer expansion also routes there.
  No concrete Lua-side reason to weaken the strong history assertion was found.
  Another product's history-equality failure requires its own execution evidence
  to distinguish fixture normalization from a common isolation defect.
- Ports is a real shared preview-listener view: EditorPage passes its actual
  preview session to `EditorPortsPanel`, which displays the listener URL/port
  and owned Stop, or an explicit empty state. This is not global port scanning
  or a Lua/QuickJS socket/debug transport capability. Embedded runtime/native
  console limits remain explicit. Installed listener behavior is a target gate.
- Native/config review found no new concrete blocker in CMake/ABI linkage,
  OHOS ABI overrides and opposite-ABI exclusions, exact-length ABI/export
  declarations, compile-only checks, project stdin/temp cleanup, source-byte
  attributes or offline native refusals. Apple Xcode integration currently
  contains Lua without QuickJS/qfli_script; Apple Script bundling/execution is
  an existing unestablished boundary, not a passed platform capability.

## Full R1–R13 acceptance boundary

| Requirements | Current static conclusion and remaining proof |
| --- | --- |
| R1–R2 | Product has 240 paired Lua topics/net+140 and retained historical 480 exact host executions. Full1282 keeps all shipped locations and preserves original expectations. Its terminal-line gate is separate from strict byte equality; 800 original missing-final-LF expectations must remain visible mismatches. A passing host test must not be described as a strict all-shipped exact or installed-device pass. Fresh full1282/current-native/HAP/target evidence remains root-owned. |
| R3 | Shared filters/badges and Lua/fallback catalog routing are wired; final composed widget/installed multi-language evidence remains separate. |
| R4 | Six Lua tools including real debugger plus JS/TS/Shell tools are directly wired; current full tests and installed tool operation remain separate gates. |
| R5 | Real analyzer contracts and dirty-buffer/error/correction/no-write coverage are present; final shared renderer/navigation and installed probes remain necessary. |
| R6 | Actual Lua Home/named multi-root/live dirty-session/reconstruction fixture retains owner/cursor/tree/history assertions; its current execution result and installed workflow remain open at review time. |
| R7 | Genuine Lua pause/step/breakpoints/stack/primitive locals/output, retryable cleanup and real preview Ports semantics are represented; current suite and installed lifecycle evidence remain open. No JS/TS/Shell debugger, REPL, Node/browser APIs or arbitrary process-port discovery is claimed. |
| R8 | Production grammar/tokenization checks cover declared text variants and reject bytecode editing; host tokens are not installed visual proof. |
| R9–R10 | C user headers and Python module/pip feasibility remain those product owners' independent runtime/target gates. Lua source review cannot close them. |
| R11 | Offline profile/native-route/permission policy is represented. Full audit requires actual native OFFLINE_ONLY refusals on OHOS; host/injected checks explicitly remain not_evaluated or nonnative evidence. |
| R12 | Current product APIs resolve to the published C-owned core above; source freeze/manifests and final cross-product compatibility remain required. |
| R13 | No staging, commit or push performed by this review. Root retains exact staging/provenance review, Conventional Commits and normal pushes while preserving peer work. |

## Verification and handoff

- New reviewer formatter/lint/type-check/tests/runtime/build/device: NOT RUN,
  as explicitly instructed by root's host-slot and source-freeze rules.
- The earlier 125 focused tests and analysis exit0 predate subsequent debugger
  and named-workspace edits and do not validate them.
- C464/Lua465 source attempt466 is retained as a FAILURE: format74/2 changed,
  analyzer43 historical build-copy issues plus2 redundant imports; suite and
  full1282 were unrun. Root subsequently added `build/**` exclusion and removed
  the redundant imports. Static inspection confirms the narrow exclusion and
  retains the historical files, but does not turn that repair into a pass.
- Root's new C487/Lua474 source/full1282/suite execution must publish its own
  results, source fingerprints and process cleanup. This report does not infer
  completion from a granted window or running process.
- Latest builder/inspector receipt changes are source-reviewed deliveries with
  their own notes; exercise them in a fresh explicitly serialized build, inspect
  the preserved current full HAP, verify signature and obtain a new exact device
  grant before installed full1282/diagnostic/debugger/offline/UI acceptance and
  normal-main restoration.

No additional local code fix was needed in this continuation. The suggested
initialization-cleanup spec paragraph remains in `static-quality-gate.md` for
root's owned spec integration. This report leaves all independent umbrella
gates open until their direct evidence is published.
