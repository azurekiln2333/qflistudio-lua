# Application build verification

## License prerequisite

GPL v3 alignment was committed as a2ee30c and archived as ce3839b. Both are on
github/ci/native-all-platforms. The committed LICENSE blob remains 35,149 bytes
with SHA256 3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986.

## Apple integration

- Implementation and independent review cover both Runner Xcode projects and
  lib/script_toolchain.dart.
- Six Script/QuickJS sources per Runner, source paths, object IDs, macro escaping,
  Apple API visibility and existing non-global stripping were checked.
- Dart format and targeted analysis passed. Script toolchain tests passed 16/16.
- No actual Xcode compile or application startup has been performed yet.

## CI and Web implementation

- Independent CI review passed. Seven helper regression tests, Python syntax,
  actionlint and Chinese documentation checks passed.
- Web focused analysis and 34 host tests passed, including native bootstrap/profile
  regressions and CRLF preservation. Actual lib/main.dart Web release build passed.
- The local Windows Chrome test compiled but could not start: Flutter's CanvasKit
  route converts URL slashes to Windows backslashes before a slash-prefix check.
  The required JS/WASM files exist locally and in the fixed SDK archive. This is
  an environment failure, not a passing browser test. Linux CI will run Chrome.
- Browser source import/download has not received end-to-end file-picker evidence.
- Independent Web review found no source-level blockers. Sequential other-tab
  saves are detected; this does not establish simultaneous-write isolation.

## Remaining verification

Cloud application jobs and Web storage/browser checks remain pending. Local SDK
and shared-core worktrees have unrelated changes; local tests do not establish
the reproducible pinned cloud build.
