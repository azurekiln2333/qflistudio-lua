# Full application cloud builds

## Boundary

The existing native workflow compiles runtime libraries without Flutter. Add a
separate application workflow that builds the real lib/main.dart and publishes
complete platform bundles. Keep native library verification available separately.
The user authorized task creation, implementation and GitHub execution.

Product changes include the missing Apple Script integration, a browser editor,
and build compatibility defects demonstrated by cloud compilation. The sibling core and
main-product worktrees are read-only. Local signing configuration and temporary
files are outside this task. No local cache cleanup is included.

## Reproducible inputs

- App: exact workflow source commit, checked out at qfli_lua.
- Core: azurekiln2333/qflistudio-core at
  573d1b6eecf1c2b392ad753264a5a09f62f8335e, checked out beside the app.
- Flutter-OH: public 3.41.9+ohos-1.0.2 tag, expected commit
  62357a93d653bf844f730bb1f4b7cc9e2139d14e. Bootstrap must verify this identity
  and record Flutter/Dart versions. The local modified SDK is not an input.
- HarmonyOS full SDK: mirrored 6.1.1.280 command-line tools, fixed SHA256 from
  research/ohos-app.md. Preserve target API24 and compatible API18. Identify the
  third-party mirror explicitly in metadata and documentation.
- Action references remain pinned to full SHAs. Workflow has contents:read.

## Jobs and outputs

Independent jobs build Windows x64, Linux x64, macOS arm64 and x64, Android APK
and AAB, iOS device app without signing, OHOS arm64 HAP without signing, and Web.
Use fail-fast:false for matrices. Every build targets lib/main.dart.

Windows first builds Script with modern MinGW at the existing prebuilt path,
then uses Flutter/MSVC for the application. Linux already installs both runtimes.
Apple Runner source phases compile Script and QuickJS alongside existing Lua.
macOS resolves Script's linked process symbols before trying dylib paths.

Desktop artifacts contain the entire Flutter bundle. Apple directories are
tarred before upload to preserve executable modes and symlinks. Android APKs
retain the current test signing; AAB is not a store-signed release. iOS and OHOS
outputs are unsigned. No local certificates or signing passwords are uploaded.
OHOS CI sanitizes only its clean cloud checkout's build profile before build.

Each artifact includes root/third-party licenses, checksums, source/toolchain
metadata and logs. Inspect final native bundles for both runtimes, essential
assets and executable/framework files. Check Apple exported bridge symbols.
Metadata keeps compile/package verification distinct from device execution.
Failed jobs upload diagnostics and a failed manifest, never a success package.

## Web boundary

The user selected editing and saving, with native execution disabled. Preserve
lib/main.dart as the single entry, using a conditional browser/native bootstrap.
Move existing native startup/profile unchanged into a native-only module, and
retain its exported profile for existing host tests. Browser imports must not
reach native adapters, dart:ffi or the file-backed core bootstrap.

Implement a real browser workspace with the existing re_editor component,
multiple named source files, create/rename/delete, explicit save and visible
save/error state. Persist a versioned workspace in browser localStorage and
restore after reload. Failed or corrupt storage must not silently replace user
data or claim a successful save. Provide source import/export so users can move
files out of browser storage. No network or native execution is involved.
Run/debug/compile controls clearly state that the browser edition does not
support native execution. This is a functional browser editor with a dedicated
platform shell, not a placeholder page or a claim of full native feature parity.

Keep browser storage behind an interface for deterministic host widget/model
tests. Add actual browser persistence tests and run the compiled Web bundle in
Chrome when available. The sibling core does not require modification.

## Rollout and rollback

Push incremental reviewed changes to ci/native-all-platforms and observe actual
Actions jobs. Record run IDs, exact commits, artifact IDs and verification limits.
Fix failures within the stated boundary and rerun affected jobs. Independent
workflow and Apple integration commits can be reverted without deleting existing
user build outputs or changing the sibling repositories.
