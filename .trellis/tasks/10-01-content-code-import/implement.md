# Implementation

- [x] Snapshot relevant dirty core files and finish package/spec context loading.
- [x] Implement import service, custom new-project entry and runner entry lookup.
- [x] Simplify lists and add shared detail code actions, import forms, localization and route dependencies.
- [x] Make explicit editor initial paths take precedence over restored active tabs.
- [x] Add real filesystem, custom filename, existing project, history and cancellation/error workflow tests.
- [x] Capture narrow/wide MD3 views and inspect them; run analysis and regression tests.
- [x] Review changes and record contracts.
- [x] Preserve registry bytes on failed writes; isolate pending registrations,
  stable-tail refresh and rollback notifications with regressions.
- [x] Match reference native startup progress/first-frame behavior and verify
  the actual Lua entry.
- [x] Build the final release arm64 HAP and inspect compiled UI and native ABIs.
- [ ] Confirm commit scope, commit task-owned changes separately and archive.

## Verification Updates

- User confirmed editor-import registration on the home list.
- Retain concurrent overwrite-confirmation and bounded code-height changes.
- Review found destructive overwrite and failed-registration recovery risks.
- Both risks were fixed; all 43 Lua app tests pass, including backup failure,
  registry rollback/refresh/retry, replacement confirmation and write errors.
- Narrow/wide captures were inspected without clipping or overlapping controls.
- Shared core content and profile tests now pass (38 tests). Lua app full tests
  were repeated against the current shared core and all 43 pass.
- A real Windows exclusive file lock demonstrated old registry truncation.
  Three new regressions failed on the previous code, then passed after atomic
  replacement, pending filtering, stable-tail refresh and failure notification.
- An additional three shared-core regressions pass for existing refresh,
  cloud merging and bootstrap configuration failures.
- All twelve narrow/wide captures were refreshed against the final code.
- Final full-scope review found no new code defects. Release HAP builds with
  the final registry changes; ArkTS and all four AArch64 libraries are present.
- Lua app full analysis and shared core `lib test` analysis report no issues.
- The earlier full core run exposed older failures around language-folder
  paths, backup metadata counts and activity timers. Full core analysis also
  includes unresolved vendor example imports. These wider checks are not green;
  see `verification.md` for their exact scope and limits.
- The test harness now reinstalls asset mocks, initializes caches outside
  widget fake time, waits for routes/layouts and dismisses transient notices
  before clicking footer controls. Windows I/O errors use the failing path
  instead of assuming one exception subclass name.
- No files are staged or committed. Shared core has pre-existing uncommitted
  dependencies; `commit-plan.md` records the proposed order and ownership gate.

## Ownership

Service implementer: `code_import_service.dart`, `project_store.dart`,
`project_config.dart`, and `runner_service.dart` in the core snapshot.
Main agent: content UI, home route dependencies, editor initial path priority,
localization, tests, final integration and commits. Existing unrelated core
changes must be preserved.
