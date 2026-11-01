# Content Lists and Code Import

## Requirements

- Tutorial and example outer pages use simple Material Design 3 lists; do not show code on the outer pages.
- Keep actual bundled content and existing primary navigation.
- Detail code blocks offer direct import into the editor and import into a project.
- Both import actions let the user customize the filename.
- Project import supports a new project or an existing local project and automatically opens the project and imported file.
- Preserve example editing, copying, resetting and saving where already available.
- Show validation and write errors without silently replacing an existing file.
- Support Simplified Chinese, Traditional Chinese and English through the current localization layer.
- Continue to respect the user's earlier request not to debug/connect/install on a device.
- Startup follow-up: match `D:/MyNewProjects/qflistudio` with a native progress
  surface that waits for Flutter home rendering to prevent the startup blank screen.

## Acceptance

- [x] Outer tutorial and example pages contain titles/summaries and no visible source code.
- [x] Tutorial and example details both expose copy, import-to-editor and import-to-project actions.
- [x] A custom filename is written with exactly the selected/edited snippet, then opened in the editor.
- [x] Editor import persists its working copy and registers it on the home project list, as confirmed by the user; project import persists new projects or adds a file to the chosen local project.
- [x] Existing project session history does not hide the imported file on navigation.
- [x] Cancellation, invalid names, occupied filenames and write errors preserve existing files and leave the user in a usable state.
- [x] Replacing an existing file requires explicit confirmation, preserves a backup, and does not truncate the original on a preparation or backup failure; registration failures roll back memory state and allow retry.
- [x] Narrow and wide MD3 views render without layout exceptions; functional tests cover real filesystem writes and navigation.
- [x] Analysis and the relevant regression tests pass.
- [x] Native HarmonyOS loading remains visible until the prepared Flutter home
  is allowed to render; the real entry has a regression test.
- [x] Release arm64 HAP builds and contains compiled native UI plus matching
  Flutter, app and Lua libraries.
- [ ] Task changes are committed without unrelated user changes after commit
  scope confirmation.
