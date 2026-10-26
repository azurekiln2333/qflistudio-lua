# Script report export source review — 2026-10-26

Scope: read-only independent review of `bin/script_acceptance.dart`,
`bin/script_report_export.dart`, and `test/script_report_export_test.dart`.
Herdr p6 retains shipping ownership while its destination guard patch settles.
Only this report was written. No SDK, formatter, analyzer, test, native helper,
build, device, index, commit or network operation ran.

## Findings requiring repair

### B1: Physical-resolution failures become apparently canonical paths

`bin/script_report_export.dart:539` catches `FileSystemException` from
`resolveSymbolicLinksSync()` and returns the unresolved `existing` spelling.
Consequently `_canonicalPath` can return a non-null lexical path and the
exporter can label it `outsideRun`, even though physical resolution failed.
That contradicts the new `unprovablePath` fail-closed contract and the claim
that a local destination has been proven outside the evidence directory.
Propagate the resolution failure to `_canonicalPath` so it returns null and
refuses the write. Do not silently substitute the original path.

### B2: Lexical normalization precedes physical resolution

`bin/script_report_export.dart:514` calls `p.normalize(p.absolute(path))`
before resolving links, but the eventual write uses the original picker
`path`. Those two operations can name different physical files where a
symlink is followed by `..`. Source-level POSIX counterexample: an external
`link` points to `<run>/reports/subdir`; the picker returns
`<external>/link/../qfli-script-acceptance.json`. The guard lexically collapses
this to `<external>/qfli-script-acceptance.json`, while the original path can
resolve to the top report inside `<run>/reports`. The existing symlink test
has no `..` segment and does not cover this distinction.

Resolve the actual existing destination or its longest existing ancestor
using the original absolute spelling before lexical collapse. Alternatively,
explicitly refuse dot-segment paths if their physical meaning is not proven.
Keep the selected write destination unchanged. Add a regression combining a
symlink with `..` that requires rejection and unchanged report bytes. This
counterexample was derived from the source; it was not executed in this review.

### B3: Unsupported symlink test returns a passing result

`test/script_report_export_test.dart:602–606` catches symlink creation failure
and returns from the test. The runner then records a pass even though the
symlink assertion never ran. Record an explicit skip with the actual reason
or provide an injected filesystem-resolution failure test. Lexical alias
checks do not prove physical symlink resolution, despite the current comment.

## Behavior supported by the reviewed source

- The page creates a fresh `run-*/reports/` directory before choosing the four
  fixed basenames. Failure checkpoints read only that fresh attempt's top path.
  Missing current companions remain listed as not produced, with save disabled.
- The exporter chooses a destination before reading source bytes, passes exact
  opaque URIs to the existing `PickerService` methods, preserves the chosen
  basename/path, and copies `Uint8List` bytes without JSON serialization.
- Read-back compares both byte count and SHA-256. Cancelled, unreadable,
  mismatched, failed, abandoned and busy outcomes are distinct. URI-to-local
  mapping remains explicitly unproven rather than guessed.
- The helper owns one busy lane. Disposal and run identity are rechecked after
  picker and source reads before a destination write can begin. A write that
  has already started is not cancellable by the shared picker contract.
- Export receipts carry source path/run directory and a top-report digest
  binding. Export does not rewrite acceptance flags.
- Tests exercise exact raw bytes (Unicode, CRLF, invalid bytes and no final LF),
  local path/URI methods, cancellation, retry, read-back failure/mismatch,
  disposal, run replacement, old companion exclusion, partial/fatal report
  bytes and `.jsonl` naming. The tests have not run in this review.

## Remaining limits

There is no page-level widget regression for the disabled/save state and its
wiring to the exporter. Existing helper tests exercise the guards through the
injected `isActive` seam. Actual page composition, Flutter static analysis,
complete source/suite/full1282 execution, actual OHOS picker transfer and host
collection remain unrun gates. A write that throws can have partially changed
the destination; the `failed` state is appropriate, but the convenience
`wroteDestination == false` getter must not be treated as proof of no bytes
written after a write error. The UI currently does not make that claim.

No definite Dart compile/type defect was established by manual inspection.
That is not a type-check pass. Final review must bind the repaired source hashes
and follow p6's explicit release before a new execution grant is accepted.

## Narrow repair re-review

Reviewed repaired helper SHA256
`01dba1e96bd0fc4a4907f1d5df52e55cbd94d04af42cc8ffd77391167ba973c6`
and tests SHA256
`322bdc661930f555d95f51e9a60bb825307babc2a0790609eeda11c67f071d43`.

- **B1 source repair closed:** resolution errors now propagate to the outer
  catch, yielding null/unprovablePath. Dangling links are explicitly refused.
- **B2 production source repair closed:** existing destinations/ancestors are
  physically resolved from the original spelling before canonicalization.
- **B3 source repair closed:** a capability probe now supplies explicit skip
  reasons instead of returning from a passing test.

### Remaining concrete test defect: POSIX semantics asserted on Windows

The new `refuses a symlink followed by ..` test always expects insideRun and
rejection when symlinks are available. The pinned SDK explicitly documents
platform-dependent behavior in
`D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/lib/io/file_system_entity.dart:312`:
Windows resolves `..` before symlinks, while other platforms resolve a symlink
before applying the following `..`. In this fixture the Windows destination
therefore names an external file and the repaired exporter can correctly
accept it. The test will fail on a Windows host that supports symlinks.

Make this exact POSIX bypass regression explicitly POSIX-only, or branch its
expected destination/verdict on actual platform semantics. A Windows branch
can require a successful external copy and unchanged source/companion bytes.
Keep the plain symlink-inside-run regression on all capable platforms. This
finding comes from the pinned local SDK source; no SDK tool or test ran.

The repaired helper comment claiming link-first behavior on every platform
should also describe native platform resolution instead. The actual code uses
the native resolver and therefore follows the matching later write semantics.

## Final narrow source closure

The POSIX-specific symlink/`..` regression now uses `dotDotSkip`: Windows
records an explicit platform-semantics skip; other platforms retain the
capability probe's actual skip reason. The ordinary symlink-inside-run and
dangling-link tests continue to use `symlinkSkip` on every capable platform.
The helper comment now states the native Windows/POSIX distinction. The sole
remaining Windows test defect identified above is closed in source.

Final reviewed SHA256:

- `bin/script_acceptance.dart`:
  `e7c82d5d0a4886bf2114d386b81e8fe4891b3f863f989aa2a8ab99da6ec06ebb`
- `bin/script_report_export.dart`:
  `5796cf28241cca406768dfec3f09139f897d501e26d7700ad70b8f8364353e5e`
- `test/script_report_export_test.dart`:
  `ea9743cca4dfcfc2e6690fee5e0e559fe78b702ead8f4bed17d6e7877a877a78`

No remaining concrete blocker was found in this narrow source review. Earlier
findings remain above as dated repair history. This closes review only; lint,
type-check, helper tests, page composition, full source/suite/full1282 and
actual OHOS transfers remain UNRUN here. No shipping files or core were edited.

## Final page-label and lifecycle addendum

Reviewed page SHA256
`8a054a58f9bcee1950015d2a04b4dc535bb656cc5b278d3f049bb5ef558e2a31`.
The exporter/helper and tests retain the final hashes listed above.

The narrow page changes introduce no concrete source regression:

- `_export` now checks `_exportActive()` before the first `setState`, rejecting
  disposed/stale queued actions while preserving its single-lane guard.
- Top-report digest binding is unknown when a result has no source digest;
  cancellation/refusal no longer appears as a digest mismatch.
- Attempt labels use only the current summary's `executionComplete`: true is
  execution complete with acceptance gates separate, false is partial/failed,
  and other values are unavailable. The tile, copied receipt and export log
  carry that distinction. Export success still does not imply run acceptance.
- Missing files are described as missing at inventory, which does not assert
  that a phase never produced them. Save stays disabled for the captured
  missing inventory entry.
- The read-back-unavailable receipt no longer repeats the same phrase.

No remaining concrete blocker was found in this final page-only source review.
The absence of a page widget regression remains an execution/coverage limit,
not a new source failure. No lint/type-check/test/SDK/build/device operation
ran, and no shipping/core files were edited by this reviewer.

## Grant698 repair source review

Reviewed only the helper/test repairs after the parent-reported grant698 run.
Current SHA256 values:

- `bin/script_report_export.dart`:
  `0569f172093526e20e2efd361f2c35dc479a76fe06208cc7f5bfaea8bd142560`
- `test/script_report_export_test.dart`:
  `8b0d84196ed2386b39cd5817a6aa8a427b90ae2a775bd7d097a274ec30a00c35`

The fatal-checkpoint fixture now passes the completed string from
`File(destination).readAsStringSync()` to `jsonDecode`. It retains the exact
byte assertion, all four false acceptance/execution flag assertions, and the
fatal-failure map assertion. This fixes the former Future/string mismatch
without promoting failed or partial execution to acceptance.

The helper's local-path write and read-back retain the same `hasPath` branch.
Removing the two redundant non-null assertions uses the existing promoted
path. Adding braces retains the original branch boundaries and return behavior.
The test still imports Flutter services, which supplies its `Uint8List` use;
removing its redundant typed-data import does not remove a required symbol.
No concrete source regression was found in these narrow repairs.

Parent execution evidence: grant698 controls PASS and source format PASS
(76 files checked, four changed); analyzer reported five issues before these
repairs. Suite and full1282 remain UNRUN. This source review does not establish
that the analyzer is now green. Lint, type-check, tests, formatter, SDK, build,
and device operations were not run by this reviewer. Shipping files and common
core were not edited. A new authorized execution grant must verify the repairs.
