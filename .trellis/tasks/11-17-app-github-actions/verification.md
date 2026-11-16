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
- A headless Chrome screenshot of the actual local release bundle showed the
  editor, source contents, file controls and disabled native actions. CanvasKit
  resources loaded with HTTP200 through an ordinary local HTTP server.
- Independent Web review found no source-level blockers. Sequential other-tab
  saves are detected; this does not establish simultaneous-write isolation.

## Remaining verification

Cloud application jobs and Web storage/browser checks remain pending. Local SDK
and shared-core worktrees have unrelated changes; local tests do not establish
the reproducible pinned cloud build.

First cloud run: 43945934915, source c95351adda65b83eee650f39590418973478b945.
All implementation commits were pushed to github/ci/native-all-platforms.

The first run finished cancelled after Android, Linux and Web exposed the same
SDK setup defect: fetching a tag only into FETCH_HEAD omitted its local tag ref,
so Flutter reported 0.0.0-unknown and dependency resolution failed. Remaining
jobs were cancelled to avoid repeating this known failure.

The fix retains the real remote release tag, verifies its peeled commit and
checks the reported framework version. The pinned fork's version parser retains
the full OHOS tag suffix. Independent review and all nine helper regression
tests passed, including a real temporary Git-remote tag fetch test.

Second cloud run: 43947518174, source c81ef0fe85a6d3485f190e3d128a67d6db0dd599.
Flutter bootstrap now passes. Linux, Web and Android resolve Dart dependencies
but pub get exits with "No Hmos SDK found" during OHOS platform regeneration.
Pinned SDK source confirms enable-ohos controls this regeneration; non-OHOS jobs
must disable that feature before dependency setup. OHOS keeps it enabled.
Windows hit the same dependency-generation error after its native prerequisite
and 22 Script probes passed. OHOS passed SDK setup, Flutter setup and dependency
generation, then failed in the Flutter HAR's OhosAutoFillHelper.ets: the API24
SDK's autoFillManager lacks the referenced types and requestAutoFill method.
The actual ArkTS compiler reported 15 errors. This is an upstream HAR/SDK API
compatibility issue; no application HAP was published by that run.
Source inspection confirmed the missing APIs were introduced in API26. The next
toolchain revision uses the fixed-hash 26.0.0.821 mirror and sets compile SDK26
only in the clean cloud profile. Target24 and compatible18 remain unchanged.

Independent final review also injected license-copy and checksum failures. Those
paths could retain package success flags, so finalization needs the same failure
invalidation as build failures. Web source Chrome evidence must remain distinct
from release-bundle browser acceptance.
The fixes include a main-entry regression that preserves an existing artifact
byte-for-byte when init refuses reuse. Sixteen helper tests pass, along with
Python compilation, actionlint for both workflows, scoped Chinese lint and
whitespace checks. Independent final review passed, including all sixteen tests
with Python site-packages disabled. macOS x64 independently reached the same
non-OHOS pub-get failure before Xcode, confirming the shared configuration fix.

The earlier successful native Linux artifact was downloaded locally. Its manifest
matches source 560eea3841dc78d89551c62f7a550f51565f2eb8 and run 43925767369. Both
runtime libraries, headers and test reports are present; all 17 checksum entries
match the ZIP contents. Other native artifacts were not downloaded in this check.
