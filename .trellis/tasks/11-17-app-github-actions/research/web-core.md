# Web and shared-core build audit

## Source identity and access

- Public GitHub repository: `azurekiln2333/qflistudio-core`.
- An unauthenticated GitHub API GET returned `private: false`, `default_branch: main`, `archived: false`.
- Local committed HEAD and remote `refs/heads/main` both resolved to `573d1b6eecf1c2b392ad753264a5a09f62f8335e` during this audit.
- Use that exact SHA in CI, checked out beside the application as `qfli_studio_core`.
- Application `pubspec.yaml` depends on `../qfli_studio_core`, and its `re_editor` override depends on `../qfli_studio_core/vendor/re_editor`.
- The sibling checkout contains many unrelated modified/untracked files. All findings below about core behavior use `git show HEAD:<path>` or `git grep HEAD`. Do not copy, commit or upload the dirty sibling work to make CI pass.

## Immediate Web compilation boundary

`lib/main.dart` unconditionally imports product adapters that reach native FFI:

| Main import | Native dependency |
| --- | --- |
| `lua_runner.dart` | `lua_toolchain.dart`, `script_toolchain.dart` |
| `lua_editor_tools.dart` | `lua_toolchain.dart` |
| `lua_terminal_commands.dart` | `lua_toolchain.dart` |
| `lua_tools_page.dart` | Lua/Script toolchains and `lua_debugger.dart` through tool pages |
| `product_code_analyzer.dart` | Lua and Script analyzers and their toolchains |
| `lua_studio_debugger.dart` | `lua_debugger.dart` |

`lua_toolchain.dart:2`, `script_toolchain.dart:2`, and `lua_debugger.dart:3` import `dart:ffi`. They contain native pointers, dynamic-library lookup, and isolate-backed native calls. The current SDK's `lib/libraries.json` does not provide FFI in the dart2js target. `kIsWeb` checks inside otherwise imported native implementations cannot make these imports valid.

The app currently declares `runtimeStatus: available` unconditionally in its profile. A browser build must not keep that claim if native runtimes are unavailable.

## Existing useful seams

- `StudioProfile` already accepts optional `runner`, `codeAnalyzer`, `debugger`, `toolsTabBuilder`, `terminalCommandDelegate`, and `editorFileTools` capabilities.
- Core `services/process_supervisor.dart` already conditionally imports `process_identity_ffi.dart` only when `dart.library.ffi` is true, with `process_identity_stub.dart` otherwise.
- Core `terminal/shell/local_shell.dart` already conditionally exports an IO process backend and a browser stub. The stub reports that process execution is unavailable.
- The bundled content repository is web-friendly: `lib/lua_content_repository.dart` reads assets through `rootBundle` and uses Flutter `compute`.

A narrow compilation seam could conditionally select native product-profile adapters versus browser capability adapters, while keeping the real `QfliApp` and bundled content. Alternatively, split the three FFI toolchain files into interfaces/models plus conditional backends. Native adapters remain unchanged. Browser run/check/compile/debug actions must return explicit unavailable results, not successful empty output. A placeholder page replacing `QfliApp` is not a full application build.

## Compilation is not browser usability

The committed shared core has 73 `lib/` files importing `dart:io`. Dart2js provides IO types with unsupported-operation patches, so this count is not itself proof of 73 compile failures. It is evidence that a successful JS compilation alone cannot establish browser functionality.

Concrete startup/runtime blockers:

1. `services/app_paths.dart:49` reads `Platform.environment` outside a catch while searching for a writable directory. Browser IO patches reject this operation.
2. `services/app_backup_service.dart:601` calls `_primaryStoragePath`, which calls `AppPaths.storageDirectory`.
3. `splash_screen.dart:69-85` treats any restore exception as a recovery condition. A browser unsupported-IO error can route the app to the recovery screen before normal stores load.
4. `store/project_store.dart` resolves a `File` registry and creates projects with `Directory` and `File`. It has no browser file-store implementation.
5. `store/auth_store.dart` and `store/settings_store.dart` also persist with files. `LocalMemoryBackend` exists in `services/local_store_backend.dart`, but those stores do not expose it as their current backend.
6. `editor/editor_fonts.dart:19-48` uses `Platform.isWindows/isMacOS/isIOS/isLinux` for font choices and platform families.
7. `editor/terminal_pane.dart:292,1923` assumes file-backed working directories and reads the host OS for prompts.
8. Editor, imports/exports, backups, Git and process operations continue to depend on actual local filesystem behavior.

To claim a usable browser editor, the shared core needs a browser workspace/storage implementation and explicit unsupported capability handling. A native-only CI change cannot supply that behavior. Keep browser compilation evidence separate from navigation, project editing, persistence and execution acceptance.

## Standard Flutter versus OHOS fork

The current app and committed core directly reference the fork-only enum member `TargetPlatform.ohos`. Standard Flutter cannot resolve that member even when an expression starts with `!kIsWeb`.

Affected locations:

- App `lib/main.dart:71`.
- Core `lib/config/client_platform.dart:54`.
- Core `lib/interop/interop_transport.dart:113`.
- Core `lib/pages/auth/agreement_page.dart:48`.
- Core `lib/pages/auth/huawei_quick_login_view.dart:117`.
- Core `lib/pages/auth/login_page.dart:194`.
- Core `lib/services/app_private_roots.dart:21`.
- Core `lib/terminal/shell/local_shell_io.dart:84`.
- Core `lib/terminal/widgets/terminal_input.dart:54`.

Use a verified OHOS fork SDK for each host if it supports all required artifacts, or introduce a deliberate cross-SDK platform abstraction in product/core source. Do not silently rewrite enum references in the checkout during CI and call that the same source build.

## Recommended execution boundary

1. Pin and fetch the public committed core source independently of its dirty local checkout.
2. Establish the Flutter SDK compatibility choice before starting seven builds.
3. Build the actual `lib/main.dart` for web to capture the first concrete compiler failure.
4. If browser support is included in implementation, introduce conditional native capabilities and real browser storage/platform handling in an isolated core checkout/branch.
5. Validate real QfliApp startup and editor operations in a browser. Do not equate an uploaded web bundle with native execution or project-persistence parity.

No source files were changed and no Web build was run by this read-only audit.
