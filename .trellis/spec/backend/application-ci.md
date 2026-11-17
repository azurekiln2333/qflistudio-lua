# Application cloud build contract

## Scope and commands

Read when changing .github/workflows/apps.yml, tools/ci_app_build.py, application
packaging or the pinned Flutter/core inputs. Native library CI remains separate.

The helper accepts init, setup-flutter, setup-ohos, build and finalize commands.
QFLI_PLATFORM and QFLI_ARCH identify the job. Every build uses lib/main.dart.
Eight matrix entries cover Windows/Linux x64, macOS ARM64/x64, Android three ABIs,
iOS device ARM64, OHOS ARM64 and Web.

## CLI and environment signatures

`python tools/ci_app_build.py {init,setup-flutter,setup-ohos,build}` and
`python tools/ci_app_build.py finalize --job-status <success|failure|cancelled>`
operate on `build/app-artifacts/app-$QFLI_PLATFORM-$QFLI_ARCH`.
The workflow provides QFLI_PLATFORM, QFLI_ARCH, GITHUB_SHA, GITHUB_RUN_ID and
RUNNER_TEMP. Finalize receives the job result, including setup/test failures.

## Source and toolchain identity

Checkout the app and qfli_studio_core as sibling directories. Pin core to
573d1b6eecf1c2b392ad753264a5a09f62f8335e. Do not use unrelated local core changes.
Use Flutter-OH tag 3.41.9+ohos-1.0.2 at
62357a93d653bf844f730bb1f4b7cc9e2139d14e, Dart 3.11.5. Verify framework/engine
identity and retain tool/app lockfiles. Pin the tool's two Git overrides to
9d2eaf45940e5042637b3387b18292ed39223a4a.

Fetch the release with an explicit refs/tags/TAG:refs/tags/TAG refspec. Fetching
only FETCH_HEAD loses Flutter's version discovery even at the correct commit.
Verify both the peeled commit and the reported full OHOS framework version.
Explicitly disable enable-ohos for every non-OHOS job before pub get. The fork
otherwise regenerates OHOS tooling for any app with an ohos directory and fails
without a Harmony SDK, even after ordinary Dart dependencies resolve.

Normal engine storage uses storage.googleapis.com. Dart, Web and OHOS engine
artifacts use the distinct FLUTTER_OHOS_STORAGE_BASE_URL. Do not point ordinary
FLUTTER_STORAGE_BASE_URL at the OHOS bucket. Precache only the selected target.

Full OHOS HAP builds require API26 command-line tools for the pinned HAR's public
autofill APIs. The native-only public API18 SDK cannot build this app. API24 tools
also lack those API26 declarations. Mirror release 26.0.0.821 has
fixed part and combined hashes in the helper. Record its third-party provenance.
Sanitize signing only inside a clean GitHub Actions checkout. Preserve target24
and compatible18. Omit compileSdkVersion so the verified API26 bundle supplies
the compilation SDK: Hvigor rejects an explicit 26.0.0(26) value in this setup.
Never change local user signing configuration or upload it.

## Package and failure contracts

Windows first builds Script with modern MinGW, then builds Flutter with MSVC.
The forced Windows UTF-8 Lua header must include io.h before remove/rename macro
aliases. Otherwise later MSVC CRT declarations are rewritten to wrapper names
and fail with C2375 linkage errors. Do not edit vendored Lua for this defect.
Apple app targets compile Script directly and retain FFI process exports.
For ad-hoc macOS builds, keep code signing required with identity '-'. Disabling
that requirement makes Flutter skip embedded framework signatures and can fail
the outer app signature on Intel. Verify the completed bundle with codesign.
Validate runtime exports, architecture, Flutter engine/app payload and assets
before publishing a complete package. Android also checks ELF/ZIP alignment.
Tar desktop/Web directories before uploading to preserve modes and symlinks.

Stage all outputs outside packages/, then publish them together after success.
Failed finalization removes this attempt's packages and clears success markers.
Retain logs, manifest, licenses and SHA256SUMS. Manifests bind source, run and
toolchain identities and keep device/browser execution separate from compilation.
Apply the same failure invalidation when license copying or checksum generation
fails after a successful package build. Source Chrome tests do not establish
release-bundle browser acceptance; record those outcomes in separate fields.
Uploads expire after 14 days. A workflow does not automatically create a Release.

Android artifacts use existing testing keys. iOS and OHOS are unsigned. macOS
uses ad-hoc signing without notarization. Do not call these store-ready releases.

The Windows checkout can convert LICENSE to CRLF. Checksums must match the actual
packaged bytes; compare normalized text when confirming license equivalence to
the Git blob. Do not claim cross-platform license hashes are identical.

## Validation and error matrix

| Condition | Required result |
| --- | --- |
| Existing packages at init | Refuse reuse without changing files or manifest |
| SDK or framework identity mismatch | Stop before compilation |
| Build, architecture, bridge or resource check fails | Failed manifest; no packages |
| License copy or checksum finalization fails | Remove current packages and revoke success flags |
| Source Chrome test passes | Set browser_tests; leave release-bundle acceptance separate |
| Build and package checks pass | Passed status; keep unrun GUI/device checks explicit |

## Good, base and bad cases

- Base: every platform artifact contains complete packages, logs, licenses and hashes.
- Good: manifest source and toolchain pins match the run; signatures and runtime
  acceptance are reported at their actual verification levels.
- Bad: a failed finalize retains an old success flag or a package from another run.

## Validation

Run actionlint, Python syntax and tools/test_ci_app_build.py for helper changes.
Run scoped Chinese lint for documentation. Every new toolchain/matrix change
requires an actual Actions run; static checks alone cannot establish a pass.
Web additionally requires model/widget tests and actual Chrome storage tests.
The helper regression suite must assert refusal preserves existing bytes, failure
invalidates current packages and metadata, and source-browser evidence does not
set release_bundle_browser_tests. Cloud checks assert real architecture/exports.

## Wrong versus correct

Wrong: poll one stale jobs response indefinitely and report a runner outage.
Correct: compare a fresh jobs query with recent runs, individual check runs and
completed logs when timestamps/status disagree. Record the source commit with
every artifact result. Do not change runner labels without a concrete failure.
