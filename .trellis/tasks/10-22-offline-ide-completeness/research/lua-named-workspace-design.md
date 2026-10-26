# Lua named-workspace integration contract

Status: READY / UNRUN, October 24, 2026. Source review only; this addition has
not run formatting, Dart analysis, Flutter tests, builds or device operations.
The coordinator must obtain a new explicit host slot before those checks.
Read-only API/flow inspection and `git diff --no-index --check` found no
whitespace errors; Git emitted only the repository's LF-to-CRLF conversion
warning. No staging or other Git-index operation was performed.

## Boundary and acceptance

The product gap is evidence that the actual offline `luaProfile` can save and
reopen a named, multi-root workspace through its normal Home/editor UI. The
behavior lives in the C-owned shared Home, FileExplorer, retained-editor host,
workspace store and editor session restoration. This batch changes only
`test/lua_named_workspace_test.dart` and this design record. It changes no
common-core source, product identity, profile capability, runner or persistence
contract, and it does not execute user programs.

The test imports the real `luaProfile` and mounts `QfliApp`. Two registered Lua
projects deliberately share `main.lua` and `nested/detail.lua` basenames. All
files, registration, workspace metadata and source saves use a temporary real
filesystem; auth and settings stores have explicit isolated storage files.

1. Open the primary project from the actual Home card. Save a named workspace
   containing both roots through FileExplorer's `工作区项目` dialog.
2. Open the secondary `main.lua` from its own root. Check ordered absolute
   paths, owning roots/names, Lua types and the active secondary owner.
3. Expand both nested directories, edit only the secondary live buffer, and
   set distinct real editor cursors. Close/reopen the sidebar and check the
   same editor/buffer, dirty text and expansion while disk remains unchanged.
4. Minimize to Home and open the secondary project as a standalone retained
   session. Its buffer reads the original disk text. Reopen the named Home
   workspace card and check that its original live editor/dirty buffer/cursors
   survived. The retained host must have exactly one session for this workspace.
5. Collapse the primary root, retaining its expanded nested directory. Save
   edited source through the actual editor menu and wait for clean state plus
   exact persisted bytes before unmounting `QfliApp` and all retained editors.
6. Drain queued workspace/project history/registry work. Assert persisted tab
   order, owner paths, active tab, cursors, nested expansion and distinct root
   expansion flags. Named-session changes must preserve the primary project's
   standalone history bytes.
7. Force reload `WorkspaceStore.instance`, recreate all three product stores,
   mount a new `QfliApp`, and open the actual saved Home workspace card. Check
   a new editor identity, saved text, clean tabs, ownership, cursor restoration,
   collapsed primary root and expanded secondary root. Reopen the primary root
   and verify its nested expansion was retained too.

Workspace session JSON stores document identities, cursor and tree state; it
does not promise unsaved-text recovery after process destruction. Dirty-buffer
assertions end before the explicit editor save. Reconstruction checks the
saved bytes rather than inventing a recovery feature.

## Current composed-core dependencies

- `StudioProfile.supportsSavedWorkspaces` defaults true independently of main
  product identity. Lua retains `StudioProductCatalog.scriptKey` and offline
  policy. Home exposes its `工作区` scope to this actual profile.
- FileExplorer supplies the named `workspace-name-field` dialog, member key
  `workspace-project-<id>`, `workspace-root-<absolute path>` roots and promotion
  callback into the retained editor host.
- `RetainedEditorHost.controller.sessionInfos` exposes read-only session
  identity. Named sessions resume by workspace id; standalone sessions are
  separate and keep their own history.
- `EditorProblemsBar.analysis.editor` supplies read-only access to the actual
  mounted editor controller, including files, owner metadata and selections.
- `WorkspaceSessionSnapshot` contains `primaryPath`, ordered `documents`,
  per-root `expandedDirs` and `rootExpanded`. `WorkspaceStore.load(force:true)`
  and `settle()` provide reload and queued transaction completion.
- Editor `更多` / `save` performs the owned save/backup path. Session persistence
  remains in workspace metadata and does not overwrite standalone history.

These are dependencies on the current composed shared checkout. C remains the
owner of publication/integration; a product test passing against dirty shared
source is not evidence of a published common-core commit.

## Validation and limits

After an explicit host-slot grant, format the new test, run package analysis,
then run `flutter test test/lua_named_workspace_test.dart`. The root's current
bounded validation wrapper should record source/HEAD fingerprints around each
phase. Rerun broader checks only if failures or later edits justify them.

Helpers use bounded condition polling with actual I/O opportunities, initialize
cached services outside widget fake time and start sidebar animations with a
zero-duration pump before advancing time. They avoid `pumpAndSettle` and use
hit-testable controls to expose missed UI actions. Full teardown drains writes
before deleting the fixture directory.

This is host integration coverage. OHOS package installation, installed target
execution, all 1282 catalog cases, physical ARM64 and full umbrella acceptance
remain separate coordinator-owned gates.
