# Browser workspace contract

## Scope

Read when changing lib/main.dart, lib/app_native.dart, lib/web or Web tests.
The browser edition supports editing and saving. Native execution is unavailable.

## Entry and interfaces

- lib/main.dart conditionally imports the browser bootstrap when
  dart.library.js_interop is true. Native profile exports remain available on VM.
- app_native.dart retains the native QfliApp bootstrap and product capabilities.
- WebWorkspace owns workspace format, file identity, selection and save state.
- WorkspaceStorage.read/write abstracts synchronous persistence.
- BrowserWorkspaceStorage uses the qfliscript.workspace.v1 localStorage key.
- SourceFileTransfer separates browser file selection/download from UI tests.
- The browser shell uses the existing vendored re_editor component.

## State contracts

Store version 1, selected file ID and complete named file contents together.
Validate the entire restored document before exposing it as a saved workspace.
Unknown schema, invalid entries and inaccessible storage must preserve the
original stored value, block overwrite and show recovery/error state. A default
example displayed after recovery failure is not evidence that user data restored.

Editor changes enter WebWorkspace immediately. Switching files cannot discard
the last edit. Preserve source Unicode and CRLF through the editor boundary.
Save updates the saved snapshot only after storage.write succeeds. Quota/permission
failure retains unsaved state. A prior other-tab write is detected by comparing
the current stored value before saving; this is not transactional isolation for
simultaneous saves. Browser data is origin-scoped and can be cleared by the user.

Run, debug and compile controls remain disabled and visibly identified as
unavailable. Browser source imports must not pull in dart:ffi, dart:io, native
adapters or the core's file-backed bootstrap. Never represent an unsupported
runtime as a successful empty result.

## Validation and error matrix

| Condition | Required result |
| --- | --- |
| Storage read fails or document is invalid | Preserve stored bytes; expose recovery state; block overwrite |
| Storage write fails | Preserve dirty state and surface the error |
| Stored value changed in another tab | Reject overwrite; retain current unsaved edits |
| User changes selected file | Retain previous file edits including Unicode/CRLF |
| User attempts native action | Disabled control with explicit unavailable state |

## Good, base and bad cases

- Base: edit, save and reload restores the same file contents and selection.
- Good: failed storage writes retain unsaved edits; external changes are detected.
- Bad: corrupt storage falls back to a default document and overwrites user data.

## Validation

- Host: flutter test test/web_workspace_test.dart test/web_app_test.dart
  test/startup_test.dart test/lua_app_test.dart.
- Browser: flutter test --platform chrome test/web_browser_test.dart. Use a
  distinct test storage key and remove only that test key during teardown.
- Release: flutter build web --release --target lib/main.dart.
- Retain evidence separately for host tests, real browser persistence, release
  compilation, visual startup and actual file-picker/download interactions.

The pinned Flutter-OH test server has a Windows CanvasKit routing bug: converting
a request URL to a Windows path before checking a slash prefix yields 404 even
when the resources exist. Linux Chrome CI avoids this path conversion problem.
Do not report a failed Windows bootstrap as a passing browser test or alter the
global SDK merely to hide the failure.

## Wrong versus correct

Wrong: use an in-memory fake to claim actual browser reload persistence or import
success; render a disabled runtime action as a successful empty result.
Correct: use host tests for state transitions and real Chrome localStorage tests
for persistence. Report release-bundle and OS file-picker/download acceptance
separately. Leave native execution visibly unavailable.
