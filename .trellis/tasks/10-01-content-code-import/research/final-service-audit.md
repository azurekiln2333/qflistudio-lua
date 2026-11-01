# Final Filesystem and Service Audit

Date: 2026-10-01. Reviewer: lua_quality_check.

## Scope

Read the current shared-core and Lua sources against `prd.md`, `design.md`, and
`.trellis/spec/frontend/content-code-import.md`. Production and test files were
not changed. The parent subsequently assigned the registry-write fix below;
it was authored only in root-repository snapshots. No Flutter commands ran.

Core line references below describe the source before registry patch integration.

## Completed Behavior Evidence

| Contract | Current source evidence |
| --- | --- |
| Use edited source for copy and import | `../qfli_studio_core/lib/widgets/code_snippet.dart:40` reads the controller, `:135` copies it, and `:146` snapshots it into the dialog's ExampleCode. |
| Custom basename and destination | `../qfli_studio_core/lib/services/code_import_service.dart:48` validates portable basenames; `:145` and `:196` combine the requested name with the template entry folder. `:111` reserves new files exclusively. |
| Persistent editor copy and home registration | `code_import_service.dart:141` creates an app-owned `code_snippets` working copy, `:161` writes strict entry metadata, and `code_snippet.dart:347` awaits `ProjectStore.addExisting`. `:358` deletes only the new working copy when registration fails. |
| New project custom entry | `../qfli_studio_core/lib/store/project_store.dart:202` constructs the custom relative entry. `:206` removes the generated entry while retaining companion files. `:273` writes the selected source and `:279` writes strict metadata before `:298` registers. |
| Existing entry stays intact | `code_import_service.dart:200` writes only the selected destination and returns the original project; it does not update ProjectConfig. The target template precedes snippet type at `:192`. Resolved parent confinement is checked at `:211`. |
| Entry rediscovery | `../qfli_studio_core/lib/services/runner_service.dart:60` prefers the configured entry after rejecting absolute, escaping, missing and externally resolved paths. Legacy profile/default lookup remains at `:81`. |
| Sequential registration failure and retry | `project_store.dart:147` removes the tentative project inside the write failure callback. `:139` recovers the queue tail; the caller receives error/project-null at `:153`. `:299` discards the new example project on registration failure. |
| Confirmed replacement and backup | `code_snippet.dart:377` checks the existing file and awaits explicit confirmation at `:380`. `code_import_service.dart:78` flushes prepared source, `:79` requests backup, `:83` rejects backup errors, and `:94` renames only after preparation. Cleanup deletes only owned temporary resources at `:95`. |
| Backup preserves original content | `../qfli_studio_core/lib/services/file_backup.dart:65` copies the original and `:66` writes metadata before returning success. Exceptions become an error at `:76`, which the import service treats as failure. |
| Navigation and restored tabs | `code_snippet.dart:163` pushes EditorPage with `initialOpenPath: result.path`. `../qfli_studio_core/lib/editor/editor_page.dart:166` restores existing tabs first; `:173` chooses the explicit path before restored active selection. `../qfli_studio_core/lib/editor/editor_controller.dart:48` selects an already restored file instead of duplicating it. |
| Lua uses the audited core | `pubspec.yaml:14` uses the sibling core. `lib/main.dart:24` declares the offline Lua profile, `:65` installs it before shared QfliApp, and `:71` passes the stores into that app. Core `home_page.dart:217` / `:226` pass these same dependencies into both content pages. `lib/lua_runner.dart:35` executes the discovered Lua entry. |

## Findings

### P2: Registry Write Could Truncate The Existing List

`project_store.dart:129` wrote directly into the registered-projects file.
A write/flush failure after opening the file could leave a truncated registry,
even though the new in-memory entry was removed. The existing failure regression
at `test/code_import_service_test.dart:359` uses a directory as the destination,
so it exercises a failure before the existing file can be truncated.
The parent independently reproduced the Windows locked-file case: the old
direct write truncates before errno 33; staged rename fails with errno 5 while
preserving the old bytes.

Fixed in snapshots only:

- `.dart_tool/content-registry-before/lib/store/project_store.dart`
- `.dart_tool/content-registry-work/lib/store/project_store.dart`

The patch creates a unique temporary directory under the registry's own parent,
writes and flushes `registry.json` there, then renames it to the real destination.
Preparation or replacement failure retains the old file. Existing rollback and
queue recovery stay intact. Cleanup removes only its own temporary file and uses
nonrecursive directory deletion. The parent owns integration and the file-lock
regression.

Baseline SHA256:
`141AF8207FFDD36EF318C6B4D7711C8B1BF5BB159F45473BE4E5D77D37EE6CE1`.

### P2: Queued Writes Can Persist A Tentative Registration Early

`project_store.dart:144` adds a project before its persistence operation runs;
`project_store.dart:123` serializes the full live list when any queued write runs.
With an earlier queued write Q and registration A waiting behind it, Q can
successfully persist A before A's own write runs. If A's write then fails, its
failure callback removes A from memory but Q's registry still contains A.
Refreshing can restore the failed registration, whose new import directory has
already been deleted. Two overlapping registrations can produce the same case.

This was a source-derived scheduling gap, not a dynamically reproduced failure.
The parent assigned its fix after review. It is now fixed in the same registry
work snapshot, with no additional production or test edits:

- `:59` tracks pending local registrations in a Set<Project>. Project has no
  custom equality or hashCode, so membership uses object identity.
- `:180` still adds the project immediately for duplicate-path checks, and
  `:182` marks it pending before enqueueing its own persistence.
- `:134` serializes accepted projects plus only this operation's registration.
  Earlier generic writes therefore exclude A; A's write excludes pending B.
- `:151` accepts the registration only after successful file replacement.
  `:187` clears pending status inside rollback before later queued writes run.
- `:123` also clears its pending status on the existing storage-null success
  path, avoiding a permanently excluded registration.

The existing enqueue/rollback revision increments and refresh revision guard
are retained. The parent identified an additional refresh timing case: a new
registration can enqueue while refresh awaits an earlier tail. The work snapshot
now loops at `:96` until the awaited tail is still identical to the current
`_writes` at `:100`. Refresh takes its revision snapshot only after that stable
tail, so an already-enqueued registration cannot be erased by stale disk data.
Mutations during the subsequent asynchronous read still invalidate that read.
No current regression forces failure only on the later write, so the parent
should exercise a controlled queued-write failure when integrating this patch.

### P2: A Failed Pending Registration Can Remain Rendered

The public `projects` getter copies all `_projects` before sorting (original
`project_store.dart:70`, work snapshot `:71`), including pending registrations.
Successful registration A notifies listeners while B is pending. Home/list
listeners can render B at that point. If B then fails, its queued callback
removes B but the catch returns an error without notifying listeners (work
snapshot `:187` and `:192`). A rendered failed import can therefore remain until
the next unrelated rebuild, even though the in-memory list has been rolled back.

This is also source-derived; no Flutter commands were run to reproduce it.
The parent selected the narrow rollback notification fix. Work snapshot `:193`
now calls `notifyListeners()` after the awaited write failure and its queued
rollback complete. The public list and duplicate-check semantics stay intact;
listeners see the removed failed item before the error result returns. The
parent owns the regression checking the final listener snapshot.

## Verification

- Registry snapshot `dart format --set-exit-if-changed`: pass.
- Snapshot whitespace check: no diagnostics.
- Baseline matches the actual core source by SHA256 at handoff.
- Lint/type-check/tests: not run in this reviewer assignment; parent owns them.
- Registry integrity, tentative-entry serialization, and refresh-tail findings
  are fixed in snapshots. Failure rollback now also notifies list consumers.
- Production integration and regression execution remain with the parent.
- No device debugging, connection or installation occurred.
