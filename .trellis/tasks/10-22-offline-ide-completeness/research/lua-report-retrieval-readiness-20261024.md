# Lua OHOS audit report retrieval readiness — 2026-10-24

## Scope and conclusion

Source-only review of the packaged Script acceptance entry and existing document
export boundary. No shipping source, common-core file, runtime/tool script,
device, SDK, build, test or Git state was changed for this review.

The current audit page cannot export its reports: it displays a selectable
private path and a summary. The smallest scoped addition is four per-file
**Save report** actions in the audit entry, using the existing
`PickerService.saveDocument` and path/opaque-URI write APIs. This needs no new
native method, permission, dependency, common UI change or normal product entry
change. Source support is present; actual OHOS picker/write/read-back and host
collection are still unrun gates.

## Current evidence

| Evidence | Source |
| --- | --- |
| Audit entry resolves app-owned storage, chooses a fixed top report filename, and creates a distinct execution workspace. | `bin/script_acceptance.dart:1615–1628` |
| UI exposes status/progress, report path and JSON summary; no save/export action exists. | `bin/script_acceptance.dart:1720–1738` |
| Success summary logs the actual report path, SHA256, OS and ABI. | `bin/script_acceptance.dart:1638–1674` |
| Report checkpoints flush a `.next` file and rename it; export must not use that temporary file. | `bin/script_acceptance.dart:325–334` |
| Top report records `startedAt`, `reportPath`, `workspace`, environment and separate false-initialized acceptance flags. | `bin/script_acceptance.dart:675–704` |
| Lua companion is derived from the top path and its SHA256 is recorded when present. | `bin/script_acceptance.dart:787–814` |
| Script companion path and final case-journal reference are recorded separately. | `bin/script_acceptance.dart:831–850`, `970` |
| JSONL is created/truncated for the Script phase, flushed per row, and remains authoritative while checkpoint summaries omit `caseResults`. | `bin/script_acceptance.dart:349–415` |
| Fatal failure preserves the prior top checkpoint with failure metadata and false completion flags. | `bin/script_acceptance.dart:1682–1706` |

The intended four-file family is:

1. `qfli-script-acceptance.json`
2. `qfli-script-acceptance.json.lua.json`
3. `qfli-script-acceptance.json.script.json`
4. `qfli-script-acceptance.json.script.json.cases.jsonl`

The present fixed top path is reused between launches. Older companions can
survive an early failure or a skipped phase. In particular, the top code can
record `scriptReportPath` even when unfinished Lua execution skipped the Script
runner. Filename existence and a recorded path therefore do not establish a
complete current-run family. The fatal-failure path can also read a previous
top report if this attempt failed before replacing it. These are provenance
constraints for a new exporter, not evidence that any particular collected
report has already been misidentified.

## Existing export contract

`../qfli_studio_core/lib/services/picker_service.dart:6–21,46–56,81–99` provides:

```dart
PickedDocument({String? path, String? uri, String? name})
PickerService.saveDocument({String suggestedName = 'qfli-project.json'})
    // Future<PickedDocument?>; null means cancellation.
PickerService.writeUri(String uri, Uint8List bytes) // Future<void>
PickerService.readUri(String uri)                 // Future<Uint8List>
```

Desktop save returns a local `path`. The native channel
`qflistudio/platform` returns an opaque `uri`. Keep the returned URI unchanged;
neither `File(uri)` nor a shell path reconstructed from it is valid usage of
this contract. Reject a non-null selection containing neither a nonempty path
nor a nonempty URI.

The product already dispatches picker methods through
`ohos/entry/src/main/ets/entryability/EntryAbility.ets:13,86–87`.
`PickerBridge.ets:31–38` uses `DocumentViewPicker.save`, with the suggested
basename and its final extension; `.jsonl` is passed through despite the
chooser's generic `JSON` label. `PickerBridge.ets:49–56` opens the granted URI
to read/write bytes and closes the descriptor in `finally`. Channel errors
become `PICKER_ERROR`. Read/write currently each issue a single native I/O call;
write acknowledgement alone is not proof of a byte-identical transfer. This
source observation does not establish an actual device failure.

Follow the destination selection, mounted checks, busy guard and error/finally
flow in `../qfli_studio_core/lib/pages/home_page.dart:959–998` and
`pages/settings_page.dart:253–307`. For these reports, write the actual selected
destination; do not append an extension and silently overwrite a different
path. Prefer destination selection before reading a large source file.

`shareText` is plain-text sharing only (`EntryAbility.ets:67–85` and
`../qfli_studio_core/lib/services/share_service.dart:9`). There is no existing
file-family share method. Logs, clipboard text and summary sharing cannot
replace raw report bytes. `AppBackupService.exportToFile/exportAll` exports
whole private app data, so it is unsuitable for this scoped retrieval action.

## Recommended audit-only implementation contract

1. Keep this inside `bin/script_acceptance.dart`, optionally extracting a small
   audit-only helper such as `bin/script_report_export.dart`. Do not edit
   common-core, native picker code, normal `lib/main.dart`, production settings
   or general backup behavior for this addition.
2. Give each page-run a fresh report directory while retaining the four
   basenames. A fresh directory can be created beneath the already app-owned
   audit-runs directory; choose a dedicated `reports` child rather than using
   the Lua/Script execution subdirectories. Pass its top `File` to the existing
   audit API. This avoids old companions without deleting or overwriting prior
   evidence, changing the JSON schema, or changing host CLI callers. Preserve
   and display/log the resulting actual path.
3. Build the export inventory only for that run after the audit future has
   returned or its fatal checkpoint write has settled. Only offer files
   actually produced in the fresh report directory. Missing/skipped files
   remain unavailable. A failed or incomplete attempt may export its existing
   checkpoints, explicitly labelled partial/failed; neither presence of all
   four files nor successful export changes an acceptance flag. Recovered
   legacy files need an explicit historical/unverified label unless their
   run identity has independently been established.
4. Offer one save action per available artifact. Call `saveDocument` with its
   basename, honour cancellation, and read the source as raw `Uint8List` only
   after a valid destination is chosen. Hash those exact bytes with the
   existing `OfflineDigest.sha256Bytes`/`_hashBytes` implementation. Do not
   parse and reserialize JSON/JSONL or normalize whitespace, final LF, CRLF,
   Unicode or embedded bytes. Metadata parsing must never supply export bytes.
5. For a local destination write the exact bytes with flush; for a URI await
   `writeUri(uri, bytes)`. Keep a single export busy lane, disable export while
   report writers are active, and recheck mounted/run identity after async
   selection/reading before initiating the destination write. A disposed page
   must not start that write. An already-started write is not cancellable by
   the current service contract.
6. Read back the selected path or call `readUri` and compare byte length and
   SHA256 before showing **verified saved**. Distinguish cancelled, failed,
   written-but-read-back-unavailable and digest-mismatch outcomes. A read-back
   failure must not be silently promoted to verified success; permit retry and
   leave source evidence unchanged. Do not delete the granted destination on
   failure, since the picker may have selected an existing document.
7. Show a small receipt per artifact: run/workspace identity, original basename,
   source byte count and SHA256, destination returned by the picker, and
   read-back state. Bind the top digest to the final logged digest when one
   exists; also record a digest for failed-attempt top checkpoints. Keep all
   acceptance/completion flags separate from retrieval state.

Per-file export avoids a whole-app backup, new ZIP format, base64 envelope and
simultaneous buffering of all four files. The current channel still buffers a
whole selected file, and read-back adds another buffer. Release buffers between
files and do not claim a source-proven maximum file size or streamed transfer.
If an explicit size limit is necessary, report the artifact as unavailable at
that size; never truncate evidence or silently skip JSONL rows.

## Required verification for a later implementation

Use the existing `PickerService.forcePlatformChannel` seam and mock
`MethodChannel('qflistudio/platform')`, restoring the hook/handler after each
test. Existing examples are
`../qfli_studio_core/test/picker_service_test.dart:8–31` and
`test/home_search_archive_test.dart:111–158`; the latter asserts actual
`saveDocument` suggested names and typed `writeUri` bytes for path/URI branches.
The new tests belong to the Lua audit code, not those C-owned files.

| Case | Meaningful assertion |
| --- | --- |
| All four source files, path and opaque-URI destinations | Exact source bytes, byte count and SHA256 survive export; correct basename and channel arguments; source files unchanged. Include Unicode, CRLF/final LF and raw-byte cases. |
| Current-run inventory | Fresh attempt excludes deliberately planted old companions; early failure/skipped Script phase cannot claim four current files or completion. |
| Partial/fatal checkpoint | Existing current-attempt files can be exported with accurate partial/failure status; no acceptance flag is rewritten. |
| Cancel or empty selection | No read/write or success receipt after cancellation; invalid destination becomes an explicit error. |
| Duplicate action or disposal | One picker/write per active lane; disposal or run replacement during picker/source read prevents a later destination write. |
| File, platform or missing-plugin error | Busy state clears, retry works, originals stay unchanged and no verified receipt appears. |
| Read-back mismatch/unavailable | Different length/hash fails verification; denied read-back remains written-but-unverified rather than clean success. |
| Destination fidelity and offline scope | No extension-derived second destination, guessed sandbox path, network/browser request or `shareText` transfer. |

After implementation, run focused audit helper/widget tests plus scoped format
and analysis in an explicitly granted host window. Tests described above were
not added or run in this source-only assignment.

## Remaining target gate

A fresh explicit device grant, reachable established target, current source-bound
full1282 package, and actual picker save/read-back are required. Collect all
available report files from the actual user-selected destination and compare
host bytes/lengths/SHA256 with the page receipt and top log digest. The returned
URI is not automatically an `hdc` path. Use an observed/supported document export
or collection route; do not invent private sandbox prefixes. Record partial
retrieval honestly. Verify normal-app restoration separately.

This review neither accepts an old device window nor changes the Lua defer,
host queue or C-owned common-core boundary. It provides a source-supported
implementation recommendation, not completed report retrieval or target proof.
