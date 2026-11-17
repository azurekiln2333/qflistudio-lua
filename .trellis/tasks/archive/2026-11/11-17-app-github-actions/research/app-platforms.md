# Full application platform audit

## Dependency identity

The app uses `../qfli_studio_core`, including a path override to its retained `vendor/re_editor`. GitHub main of `azurekiln2333/qflistudio-core` is commit `573d1b6eecf1c2b392ad753264a5a09f62f8335e`, matching local committed HEAD. The sibling has extensive uncommitted user work. CI should check out the public committed revision beside the app and should not publish or incorporate that working tree implicitly.

Both pubspecs require Dart `^3.11.5`. The local SDK is a modified `D:/ProgramFiles/flutter_ohos`: Git HEAD `12587c79e88aacf3172a84e536f226457d037594`, tag `3.27.5-ohos-1.0.1`, but cached engine `42d3d75a56efe1a2e9902f52dc8006099c45d937` and Dart `3.11.5`. Its source has broad uncommitted modifications. Do not treat the old framework tag as a reproducible SDK pin.

`lib/main.dart:71` and eight committed core locations reference `TargetPlatform.ohos`. An upstream Flutter SDK without this enum cannot compile this source unchanged. Use a verified current Flutter-OH release compatible with Dart 3.11.5, or implement genuine platform compatibility in source. Do not merely swap in upstream stable and claim support.

## Commands and deliverables

All application builds should target the actual `lib/main.dart`.

| Target | Build command | Main deliverable |
| --- | --- | --- |
| Android | `flutter build apk --release --target lib/main.dart --split-per-abi` | `build/app/outputs/flutter-apk/app-<abi>-release.apk` |
| Android store archive | `flutter build appbundle --release --target lib/main.dart` | `build/app/outputs/bundle/release/app-release.aab` |
| Linux | `flutter build linux --release --target lib/main.dart` | whole `build/linux/x64/release/bundle/` |
| Windows | `flutter build windows --release --target lib/main.dart` | whole `build/windows/x64/runner/Release/` |
| macOS | `flutter build macos --release --target lib/main.dart` | `build/macos/Build/Products/Release/QFLIScript.app` |
| iOS | `flutter build ios --release --no-codesign --target lib/main.dart` | `build/ios/iphoneos/Runner.app` unsigned |

Bundle directories must retain Flutter engine, data and plugin files. Uploading only an exe is not a complete application. iOS unsigned app/archive is not installable on ordinary devices until signed. Android Release currently explicitly uses the debug signing key (`android/app/build.gradle.kts`); it can produce an installable test APK, not a distribution-signed store release.

## Platform prerequisites and gaps

### Android

- AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14, Java17, NDK27.0.12077973.
- Native CMake builds both Lua and Script. Existing ABI filtering follows Flutter target-platform.
- Actual minSdk from the current Flutter Kotlin extension and generated app manifests is API24. Preserve 16 KiB alignment options and inspect final package library alignment.

### Linux

- CMake, Ninja, Clang, pkg-config and GTK3 development libraries are required.
- `linux/CMakeLists.txt` already installs both libraries under bundle/lib, alongside libflutter and libapp.
- Use the whole install-generated bundle. Runner output under intermediates_do_not_run is deliberately incomplete.

### Windows

- Flutter app uses Visual Studio/MSVC. Script CMake deliberately skips MSVC.
- Before app build, use modern MinGW to build `libqfli_script.dll` at `native/build/script-windows/script/libqfli_script.dll`, the default `QFLI_SCRIPT_PREBUILT` path in `windows/CMakeLists.txt`.
- MSVC builds Lua; app installation copies both Lua and the imported Script DLL beside the executable.
- Preserve static compiler-runtime/winpthread linkage for the prebuilt Script DLL; the previous native CI proves this path.

### Apple

- Both Xcode projects compile the shared Lua bridge and Lua C sources directly.
- Neither Xcode project currently contains the Script bridge or QuickJS source. A Flutter build can therefore pass while Script functions are missing at runtime.
- iOS Script loader uses `DynamicLibrary.process()`. macOS Script loader currently searches for a dylib near the executable and does not inspect process symbols.
- Minimal integration follows the existing Lua pattern: add `qfli_script.c`, `quickjs.c`, `cutils.c`, `libregexp.c`, `libunicode.c`, `dtoa.c` to both Runner source phases, with QuickJS includes, `_GNU_SOURCE`, `CONFIG_VERSION="2026-06-04"`, `-fno-strict-aliasing` and `-fwrapv`.
- Then let macOS Script prefer process symbols, matching Lua. Existing `QFLI_SCRIPT_API` already marks Apple bridge functions `used` and default visibility. Keep `STRIP_STYLE=non-global` to retain symbols for FFI.
- CMake run-script alternative is larger: build iOS static Script and force-load it at link time; build macOS dylib, copy it to a loader-visible location, and sign it as needed. Source-phase integration avoids new CMake/runtime-embedding requirements inside Xcode.
- Project deployment targets are iOS13 and macOS10.15. Preserve existing Lua iOS subprocess adaptation.
- No Podfile or Swift package references are currently checked in. The official Flutter tool may initialize plugin management during the first build; actual cloud compilation must verify it. Do not assume source inspection proves plugin integration.

## Evidence limits

This audit read sources and committed core files. It did not build full applications. Existing nine-platform native CI proves the libraries can compile, but does not establish application packaging, signing or startup. Mobile device execution remains distinct from packaging.

## Apple cloud findings (2026-11-17)

Application run `43950009629`, source `3348b1b`, established these results:

- iOS ARM64 built the real `lib/main.dart` into unsigned `Runner.app` (45.3 MB).
  Runner, App.framework and Flutter.framework were ARM64. All required Lua
  debugger/cancellation symbols and six Script bridge exports survived Release
  stripping. Artifact `14269320646` is 14,534,391 bytes, with uploaded ZIP SHA256
  `81c04ede7c6dedf9b46e2669f32a2beeb45496e6586b46f2e2cb93dcf4bb902f`.
- macOS ARM64 built `QFLIScript.app` (50.4 MB). Runner, App.framework and
  FlutterMacOS.framework were ARM64; both runtime export checks passed. Artifact
  `14267619207` is 16,401,842 bytes, with uploaded ZIP SHA256
  `ea3fe1cb868713357903edaa833d9ccbbb0ae7f8c543e078491a0aa9da5d2d28`.
- macOS x64 compiled the application C sources, then failed in Xcode CodeSign:
  `Contents/Frameworks/App.framework` was not signed. No successful x64 package
  was published. The ARM64 job did not yet run a deep signature verification.

The x64 failure came from CI's `FLUTTER_XCODE_CODE_SIGNING_REQUIRED=NO` combined
with outer-app ad-hoc signing. In the fixed Flutter SDK's
`packages/flutter_tools/bin/xcode_backend.dart`, lines 293-297 require
`CODE_SIGNING_REQUIRED != 'NO'` before signing embedded macOS frameworks. Lines
311-316 sign App.framework and FlutterMacOS.framework only when that condition
holds. The fix is to use `CODE_SIGNING_REQUIRED=YES`, keep identity `-` and
Manual style, and verify the finished bundle with
`codesign --verify --deep --strict --verbose=2` before staging. This needs a fresh
cloud run for both macOS architectures. Ad-hoc signing is not notarization.

These successful package checks do not establish application startup or physical
device execution. Local downloaded logs are under `build/app-ci/apple-*-third.log`.

## Final Apple cloud and downloaded-artifact verification

Run `43954515357`, source `6cb5aa99ddef523678d7bd996a237347e40295ca`, completed
all three Apple application jobs successfully. Both macOS architectures now pass
`codesign --verify --deep --strict --verbose=2`, including the embedded App,
FlutterMacOS and plugin frameworks. Identity reports show `Signature=adhoc` and
`TeamIdentifier=not set`. No notarization or distribution identity is claimed.
iOS remains an unsigned device application.

| Artifact | ID | Downloaded ZIP bytes | SHA256 |
| --- | --- | ---: | --- |
| app-macos-x86_64 | 14271333403 | 17219312 | aba38fe007090ff7bd0a43a15a9f62aeda3a1da1f8a435894330f739b2749b57 |
| app-macos-arm64 | 14274457499 | 16268558 | eb113c2abece04f363680e0c5803f6c34528d9ac82e51e95f29c41a591c8e9fa |
| app-ios-arm64 | 14272474877 | 14537457 | b6b5042cf7dea56979384f4dee14510f7af153c0256c7ee217c543b9c75a1e91 |

All three ZIPs were downloaded locally. Their digests and sizes match GitHub API
metadata and upload logs. Every SHA256SUMS entry was recomputed (32 per macOS
artifact, 29 for iOS), and the checksum manifest covers every ZIP file except
itself. Source/core/run identities, passed status, real entrypoint and release
mode match the expected build. Each artifact contains the exact 35,149-byte GPL
text and retained third-party notices.

The nested application tarballs match their manifest sizes and hashes. Each
macOS tarball retains 12 framework symlinks; every target resolves inside its
bundle. All three main binaries and six framework binaries retain executable
modes. Direct Mach-O header inspection confirms the requested architecture for
Runner, App and Flutter in each package, including single-slice fat headers.
Packaged binary hashes match the cloud inspection reports. Each package's nine
asset receipts match the tar payload, and all 27 required Lua/Script bridge
symbols are present in the hash-bound export report.

Local evidence: `build/app-ci/apple-fourth-artifact-verification.json`.
Cloud logs: `build/app-ci/apple-*-fourth.log`.
Signature commands were executed on the cloud Macs; local Windows verification
checked those reports and their package binding. Application startup and device
execution remain untested, as declared in every manifest.
