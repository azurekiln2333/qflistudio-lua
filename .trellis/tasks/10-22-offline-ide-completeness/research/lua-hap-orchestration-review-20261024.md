# Bounded HAP orchestration static review — 2026-10-24

Reviewer: `/root/product_contract_review`. Active task:
`10-22-offline-ide-completeness`. Root froze all shipping inputs during its new
C524/Lua530 source/suite/acceptance window. This review reads the proposed HAP
launcher and its builder/inspector interaction; it does not invoke them.
No concrete blocker was found for the reviewed bounded build/receipt/release
path. No source or wrapper repair is proposed from this pass.

## Exact reviewed inputs

| File | SHA-256 |
| --- | --- |
| `build/offline-ide-audit/run_bounded_hap.ps1` (569 lines) | `0B6DFD831B02DAC5041684D66820CA568FD5553E28F33C42300E8F537E5CC526` |
| `tools/build_ohos_audit.ps1` (342 lines) | `12B27C39F986F8F83BD6AB11EC0AAF9EAB6BDAE354DE85CAB88121E96E50E80D` |
| `tools/inspect_lua_hap.py` (233 lines) | `78D9DEC4F42179092A2AD746EA611F98971DB98D961630D9C724A82D6B0D1E02` |
| Existing `build/offline-ide-audit/run_bounded_verification.ps1` | `D76C68BD58B1275D281C656F3E30FFABA8A12276714F4C1C2C2959E13AA15FFD` |

The native C# helper extracted from the HAP launcher AST is identical to the
existing verification helper after normalizing only the namespace:
`QfliLuaAudit` becomes `QfliLuaHapAudit`. This is a source-identity observation,
not a new native compilation or Job execution result.

## Checked control flow and PowerShell semantics

- Launcher lines39–50 require Windows and an explicit nonempty HAP build grant
  naming the requested platform and a real successor. Lines376–385 use
  `FileMode.CreateNew` for the grant-event claim. The wrapper explicitly does
  not authenticate a channel grant; root must supply a fresh agreed HAP window.
  The current source/test grant is not converted into a build authorization.
- Lines53–55 quote generated PowerShell values with single-quote doubling.
  Lines388–412 generate an independent child script, rather than executing
  copied wrapper source. Its ordered dictionary at402–403 is a valid named
  splat into the actual builder parameters (`Target`, `Platform`,
  `FlutterSdkRoot`, `LogPath`, `ReportPath`) at408. The target is fixed to
  `bin/script_acceptance.dart`. SDK/paths are passed as data.
- Lines72–99 record a unique UTC/GUID invocation and explicit timing budgets.
  The remaining main budget is computed after preparation at501–503. Evidence
  and publication have separate short budgets; the recorded reservation adds
  ten cleanup seconds per owned Job. This does not claim a timed package test
  occurred merely because preparation/source parsing succeeded.
- Native helper lines236–263 create a suspended process, configure a new
  kill-on-close Job without breakaway, assign the process before resume, and
  arm its deadline. Lines264–319 observe only that Job, terminate its residual
  descendants and perform bounded Job/root cleanup. No process-name scan or
  shared-process kill was added.
- `Invoke-OwnedStage` lines327–357 hashes its exact generated script/argument
  record and logs; it records PID, exit, deadline/residual termination and Job
  emptiness. Success requires exit0, no helper error, confirmed terminal root,
  empty Job and no residual-tree termination. `Get-UnconfirmedWorkStages`
  lines359–363 prevents release while an attempted build/evidence root or Job
  remains unconfirmed.

## Builder and inspector interaction

- Builder lines170–190 retain the exclusive build lock and create their own
  unique receipt directory. Lines193–230 validate the existing in-product Dart
  target and explicit OHOS/Flutter/package-config binding before constructing
  the actual Flutter snapshot command. Its private/signing exclusions remain
  explicit; source hashes are not a signature proof.
- Builder lines234–269 retain the build log, require exit0 and a fresh HAP,
  prefer a signed filename without claiming signature verification, preserve
  exact bytes under a content-derived name, and inspect that preserved copy.
  Requested x64/ARM64 maps to the corresponding inspector ABI selection.
- Inspector lines162–220 check payload ABI/libraries/27 FFI exports/assets and
  core dependency binding, refuse INTERNET permission, and keep device
  acceptance false. Its CLI writes the report then exits according to the
  package gate (223–233). The builder requires that report's exact HAP
  path/digest, successful package result and device flag false (262–269).
- Builder finally lines273–340 attempt the after-source snapshot and drift
  comparison even on failure, retain available logs/reports, verify recorded
  command/executable/artifact hashes, restore Java options/location and close
  the lock through nested cleanup. Primary build failures remain primary;
  evidence failures cannot produce a successful receipt.
- Launcher capture lines448–470 require exactly one inner receipt matching
  BOTH unique caller log/report paths and the actual target/platform/root/SDK.
  The receipt directory and artifact directory match the builder's real paths.
  `Retain-Ref` lines429–440 verifies allowed-root containment and actual hashes.
  Lines475–489 require all seven receipt-local references, the artifact and
  current builder/inspector hashes, successful source/package gates, and
  explicit false signature/device-verification booleans. Missing/partial
  receipts fail evidence; retained partial files remain inspectable.

## Failure, termination and automatic release

- Build timeout records exit124; a failed build still runs bounded evidence
  capture once the build Job/root are confirmed terminal (503–506). An
  unconfirmed build instead withholds evidence/publication. Source/hash or
  inspection failure cannot pass the combined build/evidence gate (517–519).
- Finally lines525–543 publish only after the fresh grant was locally recorded
  and every attempted work stage has a confirmed terminal root and empty Job.
  The release names the supplied successor and requires their explicit
  acceptance. Build failure does not silently retain an idle reservation.
- Publication itself uses the same contained stage runner. Lines544–555 require
  its successful terminal/empty-Job result and an exact acknowledged message
  event (`kind`, speaker, text, positive sequence). Publication failure or an
  invalid acknowledgement is retained explicitly, with nonzero exit2 after an
  otherwise successful build (556–566). No acknowledgement is inferred from
  silence, an attempted send or a killed publisher.
- Invocation preconditions before a local claim can reject without starting a
  build or publishing a release; a caller still owns its external coordination
  obligations. This matches the wrapper's explicit local-claim boundary and is
  not treated as proof of a granted/build-started run.

## Verification and limits

- PowerShell AST parsing: zero errors in the full launcher, shipping builder,
  existing verification wrapper, and both literal generated child script
  bodies (launcher395 and423).
- Generated publication command quoting and dictionary/argument flow: static
  source review only. No generated child was launched.
- C# helper compilation/Job behavior, lint/type-check, receipt capture,
  timeout/failure scenarios, Flutter/SDK/native work, inspector execution, HAP
  build, signature verification and device operations: NOT RUN.
- No new worker was spawned. Only this review document was written; prior
  product review, peers' documentation, all shipping inputs and Git state were
  preserved.

Root can use this as source review for a later explicitly granted bounded HAP
build. A successful invocation must retain its actual terminal/empty-Job
records, unique inner receipt, unchanged source binding and inspected artifact.
Signature remains a separate gate. Device is currently unavailable per SQL527;
ABI/package evidence must not be promoted to installed acceptance.
