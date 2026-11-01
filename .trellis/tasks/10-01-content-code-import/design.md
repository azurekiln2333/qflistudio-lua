# Design

The UI lives in sibling `qfli_studio_core`, especially `local_content_pages.dart`
and the offline routes in `home_page.dart`. Lists become ordinary Material
ListTiles with titles, two-line summaries and chevrons. Runtime implementation
text and code previews are removed from outer pages. Details use a framed code
tool surface with copy/editor/project icon actions and standard Material dialogs.

Add a shared code-import service for filename validation, persistent editor
working copies, and writes to existing local projects. New-project imports reuse
`ProjectStore.createProjectFromExample`, extended with an optional filename.
Create the selected code as the project entry before registration and record a
relative `entryFile` in `ProjectConfig`; `RunnerService.findEntry` uses it before
legacy names. Existing-project imports keep the project's existing entry.

Editor import writes an app-owned working copy and registers it through
`ProjectStore.addExisting` so it remains accessible from the home list, as
confirmed by the user during verification. Project import selects an existing local project or creates a registered
project using the real store. Both navigate to `EditorPage.initialOpenPath`.
Explicit initial paths must override restored active tabs while keeping the
remaining restored tabs.

Thread the existing auth/store/settings dependencies through both content tabs
and detail routes; optional parameters retain compatibility with read-only uses.
Use existing localization dictionaries and icon conventions. Preserve current
user work in the dirty core repository by authoring narrow changes against a
snapshot of the current files and applying a contextual patch.

Concurrent workspace updates introduced explicit replacement confirmation and
bounded code surfaces; retain these behaviors. Replacement prepares and flushes
a temporary file, verifies the existing backup API succeeded, and then replaces
the original. Failed project registration removes the tentative memory entry;
the persistence queue remains usable for refresh and retry.

Registry saves flush a unique temporary file beside the destination and rename
it only after preparation succeeds. Track pending local registrations so an
earlier save cannot publish another registration before its own save succeeds.
Rollback clears pending and memory state inside the queue, then notifies the
UI. Refresh waits until the latest queued tail settles before reading disk;
the revision guard still protects mutations during the read.

## Startup Follow-Up

Use the reference `qflistudio` native splash builder in HarmonyOS FlutterPage.
The Lua entry defers the first frame before runApp, reports local-load progress
through `qflistudio/platform`, and allows the frame only after bootstrap and
home layout. Native removal follows FlutterPage's first-frame notification.
Release the deferred frame in a finally block and unsubscribe native progress
listeners when the splash disappears. Verification uses the real entry test
and a release HAP; it does not connect to a device.
