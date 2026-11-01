# Final Commit Dependency Audit

## Verdict

Audit date: 2026-10-01. Shared core HEAD is
`da3a662a78eb3485cfb9f21e2f72589dc77ed67c`. Its index was empty during this
audit. No production files or index entries were changed, and Flutter was not
run.

The current content implementation cannot be committed unchanged on HEAD with
only the files/hunks in the first shared-core batch of `commit-plan.md`.
`CodeSnippet` directly imports two files absent from HEAD, and its storage
path uses several APIs absent from HEAD. The working-tree checks therefore do
not establish that a content-only commit would compile or pass its tests.

The necessary prerequisite set is much narrower than the complete dirty core.
In particular, the content task does not require the current online runner,
retained pages, authentication screens, recovery screens, terminal rewrite,
editor autosave rewrite, or vendor editor changes.

## Ownership Evidence

`.dart_tool/content-before/` is a snapshot of the already dirty core before
content work. Comparing it with current core establishes these distinctions:

| Already present in the before snapshot | Added after the snapshot |
| --- | --- |
| `EditorFonts` usage in the old detail page and `TaskActivityService` reporting in its import action | New `CodeSnippet` and `CodeImportService` |
| `ProjectConfig.readMetadata`, `metadataFromJson`, `strict` writes | Optional `entryFile` write parameter |
| `ProjectStore` language-directory creation through `AppPaths.createProjectDirectory` and metadata-based `addExisting` | Custom filename/template composition and registry rollback |
| Online runner and retained-page imports in editor/home | Imported file selection after restored tabs |
| Online runner support and `src/main.sh` fallback | Configured entry resolution; `src/main.sql` is another concurrent addition |

The snapshot does not contain `editor_controller.dart`, `file_backup.dart`,
`example_code_store.dart`, or the new test. Their exact author cannot be
determined from that snapshot. `commit-plan.md` identifies example persistence
as concurrent content work and backups/recovery as pre-existing parallel work.
The new content test also depends on the controller lifetime fix below.

## Minimum Prerequisites for the Current Behavior

These are exact file/hunk boundaries, not a proposal to stage their entire
parent modules.

### 1. Bundled Code Font

- `lib/editor/editor_fonts.dart` is self-contained and absent from HEAD.
- Add only the four Roboto Mono TTF files and `OFL.txt` currently under
  `assets/fonts/roboto_mono/`.
- Add the corresponding license asset and `fonts` declarations in core
  `pubspec.yaml`.
- The font settings page and editor/settings-store font integrations are not
  required by content. `CodeSnippet` only uses `EditorFonts.bundledFamily` at
  [code_snippet.dart](/D:/MyNewProjects/qfli_studio_core/lib/widgets/code_snippet.dart:49).

These are parallel font changes reused by the content task.

### 2. Activity Reporting

The unchanged snippet reports `open_project` and `create_project` at
[code_snippet.dart](/D:/MyNewProjects/qfli_studio_core/lib/widgets/code_snippet.dart:159),
and the new test initializes that service. Adding the service alone is
insufficient. The smallest existing implementation closure is:

- New `lib/services/task_activity_service.dart`.
- In `lib/community/models.dart`: `UserGrowth`, the expanded `TaskInfo`
  (`eventKey`, `progress`, `target`, serialization and `withProgress`), and
  `DailyTasksSnapshot`. If selecting current `AuthStore` hunks verbatim,
  include `CommunityUser.gatewayUserId`, `avatarUrl`, `growth`, and their
  constructor/JSON fields as well.
- In `lib/services/api_client.dart`: only the `tasks` return conversion,
  `checkin` snapshot return, `checkinDays`, and `reportTaskEvent` methods.
  These methods can use HEAD's existing `_send`, which already accepts `body`
  and `query`. `ApiException.statusCode` also already exists in HEAD.
- In `lib/store/auth_store.dart`: queued persistence (`_writes` and `_persist`)
  including the added user fields, and asynchronous
  `updatePoints(points, streak, growth)` with persistence. The existing service
  awaits that method at
  [task_activity_service.dart](/D:/MyNewProjects/qfli_studio_core/lib/services/task_activity_service.dart:278).
  HEAD has a `void updatePoints` without `growth`.
- Keep these changes as a prerequisite owned by the activity implementation;
  verify its `test/task_activity_service_test.dart` when assembling it.

No current gateway-login, agreement, avatar-cache, rewards UI, point-history
API, logout/revocation, or configuration-origin changes are needed for this
closure. The old HEAD task page consumes the same surviving snapshot fields
and does not construct `TaskInfo` directly.

### 3. Project Directory and Metadata APIs

- In `lib/services/app_paths.dart`: imports of existing `file_service.dart`
  and `project_templates.dart`, plus `languageProjectsRoot`,
  `availableProjectPath`, and `createProjectDirectory` at
  [app_paths.dart](/D:/MyNewProjects/qfli_studio_core/lib/services/app_paths.dart:91).
- In `lib/services/project_templates.dart`: only `directoryName` and
  `fromLanguage` at
  [project_templates.dart](/D:/MyNewProjects/qfli_studio_core/lib/services/project_templates.dart:125).
  `CodeImportService.destinationPath` directly needs `fromLanguage`, while
  current project creation needs the directory-name API.
- In `lib/services/project_config.dart`: the metadata helpers/reading aliases
  and `strict` parameter with rethrow. The task then adds `entryFile` and its
  merged JSON assignment. The before snapshot already has metadata and
  strictness; HEAD has neither.
- In `lib/store/project_store.dart`: retain the current metadata reading in
  `addExisting` and `type: configType`. That preserves the snippet title and
  language/type when its generated directory is registered. Registry metadata
  refresh can be committed with this small foundation, but it is not required
  merely for the new task APIs to compile.

HEAD's existing `storageDirectory`, `projectsRoot`, `FileService` filename
validator, `Project.create(type: ...)`, `TemplateFile`, and
`EditorPage.initialOpenPath` already exist. They do not need replacement.

The language-directory foundation matters to current assertions: the failed
registry test inspects `dartProjects` at
[content_code_import_test.dart](/D:/MyNewProjects/qfli_studio_core/test/content_code_import_test.dart:156).

### 4. Backup Error Reporting

HEAD already has `FileBackup.backupBeforeOverwrite` with the correct signature,
but returns success on backup failures and missing storage. That is a semantic
dependency, even though it is not a compilation dependency.

Select only the missing-storage error return and the exception-to-error return
inside `backupBeforeOverwrite` at
[file_backup.dart](/D:/MyNewProjects/qfli_studio_core/lib/services/file_backup.dart:45).
The task's replacement code explicitly relies on a non-null error to preserve
the original. The test at
[content_code_import_test.dart](/D:/MyNewProjects/qfli_studio_core/test/content_code_import_test.dart:419)
fails without that change.

Backup metadata files, `directory()`, metadata filtering in `listVersions`,
restore behavior, and recovery/recycle changes are not required for the
content task. Keep them with their original owner.

### 5. Editor Controller Lifetime

The current new test verifies that disposing during a pending read cannot add
or notify a tab at
[content_code_import_test.dart](/D:/MyNewProjects/qfli_studio_core/test/content_code_import_test.dart:162).
HEAD lacks the necessary protection.

The minimum independent fix in `lib/editor/editor_controller.dart` is the
`_disposed` flag, its assignment before disposal, and `openPath` guards before
opening and after asynchronous reads. Keep the corresponding guards if using
the current asynchronous `stat` step. This fix can retain HEAD's file reading
and exclude `modifiedAt: stat.modified`.

Do not stage the controller's autosave callback, save queue, revision tracking,
backup import, or `OpenFile.modifiedAt` work just to obtain those guards. Those
would pull in `open_file.dart` and the editor autosave foundation unnecessarily.

### 6. Concurrent Example Persistence

Include the current `lib/services/example_code_store.dart` default-storage,
load-once, queued write, failure-state, and disposal changes as the concurrent
content batch already called out in the commit plan. Its only additional
dependencies are existing `AppPaths.storageDirectory` and `path`.

The verified HomePage workflow creates a default store; HEAD's store only
persists when a storage file is injected. Omitting this change would leave
the saved-example UI enabled while losing edits across reopening.

## Narrow Content Commit After Prerequisites

| File | Include | Exclude |
| --- | --- | --- |
| `lib/services/code_import_service.dart` | Entire new file | None |
| `lib/widgets/code_snippet.dart` | Entire new file, including confirmed replacement | None once font/activity prerequisites are present |
| `lib/pages/local_content_pages.dart` | MD3 lists, shared detail snippets, forwarded stores/settings, content save handling, bounded layouts | No old font/activity imports are needed in this page after moving their behavior to the snippet |
| `lib/pages/home_page.dart` | `ExampleCodeStore` import/field/disposal and tutorial/example route parameters | ValueNotifier navigation rewrite, retained-page caching, activity refresh and unrelated project/cloud actions |
| `lib/editor/editor_page.dart` | `_restoreSession` ordering/mounted guards and `_openInitialFile` mounted guard | All online, SQL, retained-page, font, autosave and document-tool changes |
| `lib/i18n/studio_localizations.dart` | Import/name/error/save labels in all three locales and simpler example count | Formatting-only hunks |
| `lib/store/project_store.dart` | Import service, `_persist` rollback queue, `_registerLocalProject`, custom `fileName`/entry/template composition, prepared writes and failure cleanup, registration through the helper | `remapCloudId`, mutable cloud-ID dependency and changed recycle-bin call |
| `lib/services/project_config.dart` | `entryFile` parameter and merge assignment | Foundation handled in prerequisite batch |
| `lib/services/runner_service.dart` | `project_config.dart` import and configured entry validation block | `online_program.dart`, online hints, `src/main.sh` and concurrent `src/main.sql` fallback additions |
| `test/content_code_import_test.dart` | Current task coverage once lifetime/example prerequisites are included | Do not remove assertions to hide missing prerequisites |
| `test/studio_profile_test.dart` | Outer list code absence and detail copy checks | None |
| Core `pubspec.yaml` / `pubspec.lock` | Direct dev dependency on `path_provider_platform_interface` and its direct-dependency lock classification | Font declarations belong to the font prerequisite |

The full current `ProjectStore` cannot be staged as one file: `remapCloudId`
depends on the parallel mutable `Project.cloudId`, and its recycle call uses a
parallel API. Neither is needed by imports. Similarly, using full current
editor/home/runner files would reintroduce the much larger dependency set.

## Alternative Without Parallel Foundations

A HEAD-based task implementation could use HEAD's `monospace` styling, omit
activity integration, retain HEAD's flat project directory scheme, and only
add custom-entry, rollback, backup-error, lifetime, and saved-example changes.
That would require changing the staged new snippet/test harness and adapting
directory assertions. It would not be the currently verified implementation,
and must not be produced by silently excluding import/reporting lines from
the index while claiming the working-tree checks prove that commit.

Prefer the narrow prerequisite batches above if preserving the current
working behavior. The remaining blocker is ownership/authorization for those
pre-existing font, activity, project-directory/metadata, backup-error and
controller-lifetime hunks. It is not a requirement to commit the whole dirty
core or wait for online/recovery/authentication UI work.

Before committing, assemble the selected result against HEAD and run analysis
and relevant tests on that assembled result. This report is a source and hunk
audit, not a compilation result for that prospective commit.
