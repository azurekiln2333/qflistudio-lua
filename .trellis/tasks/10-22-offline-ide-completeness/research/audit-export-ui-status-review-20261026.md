# Audit report export user-facing status review — 2026-10-26

## Scope and method

Read-only source review of the exported-status surface in
`bin/script_acceptance.dart` after the previous ownership release. The reviewed
surface is the export receipt text, the artifact tiles, the run/failure status
lines, the per-attempt digest binding, the acceptance-flag defaults and the
mounted/dispose guards. `bin/script_report_export.dart` was read to confirm the
states and messages the page consumes; `test/script_report_export_test.dart` was
read for coverage only. No shipping source, common-core file, helper, test,
SDK, formatter, analyzer, build, device, index, commit or network operation ran.
The earlier `symlink`/old-path helper review is not repeated here.

Reviewed at:

| File | SHA256 |
| --- | --- |
| `bin/script_acceptance.dart` | `E7C82D5D0A4886BF2114D386B81E8FE4891B3F863F989AA2A8AB99DA6EC06EBB` |
| `bin/script_report_export.dart` | `5796CF28241CCA406768DFEC3F09139F897D501E26D7700AD70B8F8364353E5E` |
| `test/script_report_export_test.dart` | `EA9743CCA4DFCFC2E6690FEE5E0E559FE78B702EAD8F4BED17D6E7877A877A78` |

## Concrete defects

### D1 — Unverified receipt repeats the same phrase (cosmetic)

`bin/script_acceptance.dart:1832-1833` renders

`'Written but unverified: read-back unavailable (${receipt.message})'`

and the exporter message for that state is `'Read-back unavailable'`
(`bin/script_report_export.dart:444`). The user sees
`Written but unverified: read-back unavailable (Read-back unavailable)`.
The state is honest; only the wording duplicates. Low severity.

### D2 — Per-artifact receipt carries no partial/failed attempt label (contract gap)

The retrieval contract in
`.trellis/tasks/10-22-offline-ide-completeness/research/lua-report-retrieval-readiness-20261024.md`
item 3 requires an incomplete or failed attempt to export its existing
checkpoints "explicitly labelled partial/failed". The page-level status does
this: the failure branch sets `_status = 'QFLI_SCRIPT_ACCEPTANCE FAILED'`
(`bin/script_acceptance.dart:1758`) and the on-screen summary carries `ok:false`
(`bin/script_acceptance.dart:1722-1726`). The per-artifact receipt does not: the
`verified` branch (`bin/script_acceptance.dart:1818-1821`) prints only source
bytes, source SHA256, destination, digest binding and URI guard. The tile title
(`bin/script_acceptance.dart:1860-1864`) prints the basename or
`(not produced by this run)`, never a partial/failed token. A reader who copies
a failed attempt's top checkpoint therefore sees `Verified saved: …` with the
attempt's failure visible only elsewhere on the page. Severity: moderate; the
transfer verdict is true, but the attempt-level label required by the contract
is absent from the receipt. No acceptance flag is involved.

### D3 — `(not produced by this run)` equates absence with non-production (low)

`bin/script_acceptance.dart:1863` labels a missing artifact
`'${artifact.basename} (not produced by this run)'`, using the `exists`
snapshot taken by `scriptReportArtifacts`. If the audit wrote the file and it was
removed before the inventory snapshot, the label over-claims non-production.
Both branches stay honest about the transfer (a later race yields the
`Unavailable: source file missing or unreadable` receipt,
`bin/script_acceptance.dart:1830`). Low severity, wording only.

## Confirmations — no finding

- **Old/missing inventory.** Each run still allocates a fresh
  `run-*/reports/` directory (`bin/script_acceptance.dart:1651-1658`) before the
  fixed basenames, so an old companion cannot appear in the inventory. The
  inventory lists all four basenames with a real `exists` snapshot; a missing
  file shows the not-produced label and a disabled button
  (`bin/script_acceptance.dart:1849-1850`). No old file is offered.
- **Busy / abandoned / mismatch / unverified / failed / cancelled / refused.**
  Each `ScriptReportExportState` maps to exactly one honest receipt
  (`bin/script_acceptance.dart:1812-1844`). `cancelled` claims no write and does
  no write. `failed` prints the exporter's own message and never claims the
  destination is unchanged. `writtenUnverified` claims written-but-unverified.
  `digestMismatch` claims verification failure. `destinationUnsafe` claims
  refusal with evidence unchanged, which the guard enforces before any write.
  No state is promoted to a clean success.
- **Per-attempt digest, fatal path.** The failure branch persists the fatal
  checkpoint (`bin/script_acceptance.dart:1737-1743`) and only then records
  `failure['reportSha256']` from the written bytes
  (`bin/script_acceptance.dart:1746`). If the checkpoint write fails,
  `reportWriteError` is set and no digest is recorded, so `_digestBound` stays
  `null` and `_bindingText` prints nothing (`bin/script_acceptance.dart:1794-1800`)
  rather than a false "matches". The success summary records its digest from the
  settled report file (`bin/script_acceptance.dart:1705`).
- **No acceptance-flag promotion.** Export writes only `_receipts` and
  `_digestBound` (`bin/script_acceptance.dart:1783-1786`). The flag set is the
  false-initialized `_fatalAcceptanceDefaults` (`bin/script_acceptance.dart:1915`)
  and the audit's own summary. Retrieval state never alters a gate.
- **Mounted / dispose guards.** `_exportActive` requires
  `mounted && !_disposed && !_running && _runSerial == _exportSerial`
  (`bin/script_acceptance.dart:1637-1638`). `dispose` sets `_disposed` and
  disposes the exporter (`bin/script_acceptance.dart:1630-1633`). `_export`
  rechecks `!mounted` after the awaited export before any setState
  (`bin/script_acceptance.dart:1782`). `canExport` requires
  `!_running && _exporting == null && !_disposed`
  (`bin/script_acceptance.dart:1849-1850`). A disposed page cannot start a new
  export and no receipt is written after disposal.

## Boundary notes (not defects in the export UI)

- The fatal checkpoint spreads `..._fatalAcceptanceDefaults()` then `...prior`
  (`bin/script_acceptance.dart:1738-1743`). A gate value written earlier in the
  same attempt can survive while `ok`/`executionComplete` are forced false.
  Export never reads flags, so there is no export-side promotion; preserving the
  prior checkpoint is the documented intent.
- `_export` calls `setState` (`bin/script_acceptance.dart:1769-1771`) before its
  first mounted recheck. `canExport` disables the button once disposed, so this
  is only reachable in a rare tap-then-dispose race. Robustness note, not a
  status claim.
- The `busy` receipt (`bin/script_acceptance.dart:1842`) is not reachable from
  the page because `_export` and `canExport` already gate on `_exporting`. The
  message is honest but unused there.
- The `abandoned` message says "page closed or run changed"
  (`bin/script_acceptance.dart:1840`); the page-closed case returns before a
  receipt, so only the run-changed case is observable. Wording is broader than
  the reachable case.
- `run-*` directories are retained under the app-owned runs directory, so no
  prior evidence is overwritten or deleted. This is intentional retention, not a
  status concern.

## Status

- Source-ready. One cosmetic defect (D1), one contract-level receipt gap (D2)
  and one low wording nuance (D3); no dishonest transfer status was found.
- Runtime verification is **UNRUN**: no analyzer, formatter, test, build, device
  or SDK execution accompanied this read-only review.
- Only this file was written. The three scoped shipping files are unchanged and
  remain released to root.

## Repair applied 2026-10-26 (D1/D2/D3)

Root accepted D1/D2/D3 and granted exclusive ownership of
`bin/script_acceptance.dart` plus this report. Minimal UI honesty repair:

- **D2.** New `_attemptLabel()` derives the attempt state from
  `_summary['executionComplete']`: `true` →
  `Attempt: execution complete (acceptance gates separate)`; `false` →
  `Attempt: partial/failed execution`; otherwise
  `Attempt: status unavailable`. The label prefixes every artifact tile
  (`SelectableText('${_attemptLabel()} — $name')`) and is added to the
  `QFLI_SCRIPT_REPORT_EXPORT` log metadata as `attemptLabel`. `_receiptText`
  returns `'${_attemptLabel()} — $transfer'` so each copied receipt is
  self-contained, not only the surrounding tile. The label never says accepted
  or passed; gates stay separate.
- **D1.** The `writtenUnverified` receipt is now
  `Written but unverified: read-back unavailable`, dropping the duplicated
  `(${receipt.message})` interpolation.
- **D3.** The missing-file tile label changed from
  `(not produced by this run)` to `(missing at inventory)`.
- **Guard.** `_export` now enters via `if (_exporting != null ||
  !_exportActive()) return;`, preserving the single export lane and rejecting a
  stale or queued tap before the first `setState`.
- No helper, test, core, README or other file changed. No SDK, analyzer,
  formatter, test, build or device ran.

Post-repair hashes:

| File | SHA256 |
| --- | --- |
| `bin/script_acceptance.dart` | `8A054A58F9BCEE1950015D2A04B4DC535BB656CC5B278D3F049BB5EF558E2A31` |
| `bin/script_report_export.dart` | `5796CF28241CCA406768DFEC3F09139F897D501E26D7700AD70B8F8364353E5E` |
| `test/script_report_export_test.dart` | `EA9743CCA4DFCFC2E6690FEE5E0E559FE78B702EAD8F4BED17D6E7877A877A78` |

Root readiness gate must rebind to the new `bin/script_acceptance.dart` hash
before any execution grant.