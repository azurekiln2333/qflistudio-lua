# Commit Plan

## Gate

The implementation and relevant checks are complete. Phase 3.4 of
`.trellis/workflow.md` requires one confirmation of the commit plan and of any
unrecognized changes included in it. Neither repository has staged changes.

Shared core HEAD is `da3a662`; the Lua app HEAD is `4ab1d66`. The content task
was implemented against an already dirty core. Simply staging the touched
files would include parallel work, while staging only task hunks before their
dependencies land can produce a commit that does not compile.

Recommended order: the owner of the parallel foundation commits that work
first, then commit the two task batches below with narrowly selected changes.
If the user authorizes including necessary foundation changes in this session,
prepare them as a separate prerequisite batch before the content commit.

## 1. Shared Core

`feat(content): simplify offline lists and add customizable code imports`

New task files:

- `lib/services/code_import_service.dart`
- `lib/widgets/code_snippet.dart`
- `test/content_code_import_test.dart` (includes concurrent task coverage)

Select only task changes from these overlapping files:

- `lib/pages/local_content_pages.dart`: MD3 lists, shared snippets, dependencies.
- `lib/pages/home_page.dart`: pass stores/settings to offline content routes.
- `lib/editor/editor_page.dart`: explicit imported path wins after restoration.
- `lib/i18n/studio_localizations.dart`: import/replacement labels and errors.
- `lib/store/project_store.dart`: custom entry creation, atomic registry writes,
  pending-registration isolation, stable-tail refresh and rollback notification.
- `lib/services/project_config.dart`: optional entry metadata and strict writes.
- `lib/services/runner_service.dart`: valid configured entry lookup.
- `test/studio_profile_test.dart`: outer lists hide code; details retain copying.

Concurrent content work to retain and explicitly account for:

- `lib/services/example_code_store.dart`: persisted custom examples, queued
  writes, disposal and error behavior used by the verified save/reload workflow.
- Bounded code surfaces, replacement confirmation, and additional filesystem
  and UI assertions in the task files above.

## 2. Lua App

`test(content): verify Lua imports and editor navigation`

- `test/code_import_service_test.dart`
- `test/content_import_workflow_test.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `.trellis/spec/frontend/content-code-import.md`
- `.trellis/spec/frontend/index.md` (only the new guide link)
- `.trellis/tasks/10-01-content-code-import/` (task artifacts and evidence)

The two intentional spec files are ignored by repository defaults and need
explicit staging. Archive and journal commits follow the work commits through
Trellis; do not combine them with implementation or push to the remote.

## Parallel Dependencies Requiring Ownership Confirmation

These changes predate this task and are not silently included:

| Dependency | Evidence and affected paths |
| --- | --- |
| Bundled editor font | `CodeSnippet` and the original detail page use `EditorFonts`; `lib/editor/editor_fonts.dart`, `assets/fonts/`, and core `pubspec.yaml` are uncommitted. |
| Activity reporting | Original and new import routes use `TaskActivityService`; `lib/services/task_activity_service.dart` also relies on parallel API/auth/community-model changes. |
| Project storage and metadata | The original dirty `ProjectStore` already uses APIs missing from HEAD in `lib/services/app_paths.dart`, `lib/services/project_config.dart` and `lib/services/project_templates.dart`. |
| Controller lifetime | Only the `EditorController` disposed/open-path guards are prerequisites for the content regression; online runner and retained-page changes are not required. |
| Backup errors | Only the error-reporting hunks in `lib/services/file_backup.dart` are prerequisites; backup metadata and recovery UI can remain separate. |

The final audit in `research/final-commit-dependencies.md` gives the minimal
model/API/auth and directory/template hunks needed by these prerequisites.
It confirms that online running, retained pages, editor autosave, terminal,
recovery screens, auth screens and vendor work need not enter this batch.

## 3. Startup Follow-Up

`fix(startup): retain native loading progress until Flutter home renders`

- `lib/main.dart`: only the startup deferral/progress/layout handoff hunks.
- `ohos/entry/src/main/ets/pages/Index.ets`: native startup splash builder.
- `ohos/entry/src/main/ets/entryability/EntryAbility.ets`: only startup progress
  handling and matching window background, preserving concurrent agreement work.
- `test/startup_test.dart`.
- `.trellis/spec/frontend/native-startup.md` and its index link.

This follow-up was authorized by the user after the original content plan.
Its commit scope has not been confirmed; it is a separate proposed batch.

## Excluded Dirty Work

All remaining core authentication, community, profile, terminal, tools,
settings, runtime, recovery, vendor and their associated test changes stay
with their original owner unless separately authorized. In the Lua app, the
OHOS agreement entry/page/config changes, `.codex/`, `.trae/`, `.gitattributes`
and `AGENTS.md` are outside this task's proposed commit batches.

## Pending Decision

Confirm the two task batches and how their parallel prerequisite changes will
be committed. Until that decision, keep the code available in the working
trees and leave the task `in_progress`.
